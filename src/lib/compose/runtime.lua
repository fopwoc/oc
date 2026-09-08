local input = require("lib.compose.input")
local inputTarget = require("lib.compose.input_target")
local coroutineScheduler = require("lib.coroutines")

local runtime = {}

local composition = nil
local currentScope = nil
local defaultPlatform = nil
local activePlatform = nil

local function getPlatform()
  if activePlatform then
    return activePlatform
  end

  if not defaultPlatform then
    defaultPlatform = require("lib.compose.host").create()
  end

  return defaultPlatform
end

local function now()
  return getPlatform().now()
end

local function recordWork(startedAt, finishedAt)
  if not composition or not composition.metrics then
    return
  end

  local metrics = composition.metrics
  local elapsed = math.max(0, finishedAt - startedAt)

  metrics.busySeconds =
      metrics.busySeconds + elapsed

  metrics.iterations =
      metrics.iterations + 1

  local window =
      math.max(0, finishedAt - metrics.windowStarted)

  if window < 1 then
    return
  end

  metrics.cpuPercent = math.floor(
    math.max(0, math.min(100,
      metrics.busySeconds / window * 100
    )) + 0.5
  )

  metrics.windowSeconds = window
  metrics.busySeconds = 0
  metrics.windowStarted = finishedAt
end


local function createScope(key, parent)
  return {
    key = key,
    parent = parent,

    slots = {},
    slot = 0,

    scopes = {},
    dependencies = {},
    seenScopes = nil,

    dirty = true,
    hasDirtyDescendant = false,
    generation = 0,
    active = true,

    node = nil,
  }
end


local function markScopeDirty(scope)
  if scope.dirty then
    return
  end

  scope.dirty = true

  local parent =
      scope.parent

  while parent do
    parent.hasDirtyDescendant = true
    parent = parent.parent
  end

  if composition then
    composition.dirty = true
  end
end


local function removeDependencies(scope)
  for state in pairs(scope.dependencies) do
    state.observers[scope] = nil
  end

  scope.dependencies = {}
end


local function observeState(state)
  if not currentScope then
    return
  end

  state.observers[currentScope] = true
  currentScope.dependencies[state] = true
end


local function isScopeActive(scope)
  while scope do
    if scope.active == false then
      return false
    end

    scope = scope.parent
  end

  return true
end


local function cancelEffect(effect)
  if
      effect
      and effect.kind == "effect"
  then
    effect.cancelled = true
  end
end

local function disposeSlot(value)
  if not value then
    return nil
  end

  if value.kind == "effect" then
    cancelEffect(value)
    return nil
  end

  if value.kind == "disposable" and value.cleanup then
    local cleanup = value.cleanup
    value.cleanup = nil

    local ok, err = pcall(cleanup)
    if not ok then
      return err
    end
  end

  return nil
end


local function disposeScope(scope)
  local firstError = nil

  removeDependencies(scope)

  for _, value in pairs(scope.slots) do
    local err = disposeSlot(value)
    if err and not firstError then
      firstError = err
    end
  end

  for _, childScope in pairs(scope.scopes) do
    local err = disposeScope(childScope)
    if err and not firstError then
      firstError = err
    end
  end

  scope.slots = {}
  scope.scopes = {}
  scope.node = nil

  return firstError
end


local function finishScope(scope)
  for index, value in pairs(scope.slots) do
    if
      type(index) == "number"
        and index > scope.slot
    then
      local err = disposeSlot(value)
      if err then
        error(err, 0)
      end

      scope.slots[index] = nil
    end
  end

  for key, childScope in pairs(scope.scopes) do
    if not scope.seenScopes[key] then
      disposeScope(childScope)
      scope.scopes[key] = nil
    end
  end

  scope.seenScopes = nil
end


local function createState(initial)
  local state = {
    value = initial,
    observers = {},
  }

  return setmetatable({}, {
    __index = function(_, key)
      if key == "value" then
        observeState(state)
        return state.value
      end
    end,

    __newindex = function(self, key, value)
      if key ~= "value" then
        rawset(self, key, value)
        return
      end

      if state.value == value then
        return
      end

      state.value = value

      for scope in pairs(state.observers) do
        markScopeDirty(scope)
      end
    end,
  })
end


function runtime.remember(initial)
  assert(
    currentScope,
    "remember() outside composition"
  )

  currentScope.slot =
      currentScope.slot + 1

  local index =
      currentScope.slot

  local value =
      currentScope.slots[index]

  if value == nil then
    if type(initial) == "function" then
      value =
          createState(
            initial()
          )
    else
      value =
          createState(initial)
    end

    currentScope.slots[index] =
        value
  end

  return value
end

function runtime.delay(seconds)
  return coroutineScheduler.delay(seconds)
end

function runtime.awaitEvent(name)
  return coroutineScheduler.awaitEvent(name)
end

function runtime.LaunchedEffect(key, block)
  assert(
    currentScope,
    "LaunchedEffect() outside composition"
  )

  currentScope.slot =
      currentScope.slot + 1

  local index =
      currentScope.slot

  local old =
      currentScope.slots[index]

  if
      old
      and old.kind == "effect"
      and old.key == key
  then
    return
  end

  if old and old.kind == "effect" then
    old.cancelled = true
  end

  local scope = currentScope
  local effect = composition.scheduler:launch(
    block,
    {
      isActive = function()
        return isScopeActive(scope)
      end,
    }
  )

  effect.kind = "effect"
  effect.key = key
  effect.scope = scope

  currentScope.slots[index] =
      effect
end

function runtime.DisposableEffect(key, setup)
  assert(
    currentScope,
    "DisposableEffect() outside composition"
  )

  assert(
    type(setup) == "function",
    "DisposableEffect() requires a setup function"
  )

  currentScope.slot = currentScope.slot + 1

  local index = currentScope.slot
  local old = currentScope.slots[index]

  if
      old
      and old.kind == "disposable"
      and old.key == key
  then
    return
  end

  if old then
    local err = disposeSlot(old)
    if err then
      error(err, 0)
    end
  end

  local cleanup = setup()

  if cleanup ~= nil then
    assert(
      type(cleanup) == "function",
      "DisposableEffect setup must return a cleanup function or nil"
    )
  end

  currentScope.slots[index] = {
    kind = "disposable",
    key = key,
    cleanup = cleanup,
  }
end

function runtime.RecomposeScope(key, content, options)
  assert(
    currentScope,
    "RecomposeScope() outside composition"
  )

  assert(
    key ~= nil,
    "RecomposeScope() requires a key"
  )

  local parent =
      currentScope

  if parent.seenScopes then
    parent.seenScopes[key] = true
  end

  local scope =
      parent.scopes[key]

  if not scope then
    scope =
        createScope(
          key,
          parent
        )

    parent.scopes[key] =
        scope
  end

  scope.active = not options or options.active ~= false

  local recomposing =
      scope.dirty
      or not scope.node

  local traversing =
      scope.hasDirtyDescendant

  if
      not recomposing
      and not traversing
  then
    return scope.node
  end

  if recomposing then
    removeDependencies(scope)
  end

  scope.slot = 0
  scope.dirty = false
  scope.hasDirtyDescendant = false

  if recomposing then
    scope.generation =
        scope.generation + 1
  end

  scope.seenScopes = {}

  local previousScope =
      currentScope

  currentScope =
      scope

  local ok, node =
      pcall(content)

  currentScope =
      previousScope

  if not ok then
    error(node, 0)
  end

  finishScope(scope)

  if node then
    node.__compose = {
      key = key,
      generation =
          scope.generation,
    }
  end

  scope.node =
      node

  return node
end

local function composeRoot(content)
  local root =
      composition.root

  local recomposing =
      root.dirty
      or not root.node

  if recomposing then
    removeDependencies(root)
  end

  root.slot = 0
  root.dirty = false
  root.hasDirtyDescendant = false

  if recomposing then
    root.generation =
        root.generation + 1
  end

  root.seenScopes = {}

  currentScope =
      root

  local ok, tree =
      pcall(content)

  currentScope =
      nil

  if not ok then
    error(tree, 0)
  end

  finishScope(root)

  root.node =
      tree

  return tree
end


local function runEffects()
  composition.scheduler:run()
end


local function dispatchEvent(signal)
  if signal[1] then
    composition.scheduler:dispatch(
      table.unpack(signal)
    )
  end
end


local function nextWake()
  return composition.scheduler:nextWake()
end

local function isLocalInput(item)
  return getPlatform().isLocalInput(item)
end

local function pointerEvent(item, hit, inside)
  return {
    x = hit
      and item.x - hit.x + 1
      or item.x,
    y = hit
      and item.y - hit.y + 1
      or item.y,

    screenX = item.x,
    screenY = item.y,

    button = item.button,
    player = item.player,
    screen = item.screen,
    inside = inside,
  }
end

local function containsHit(hit, x, y)
  return
      x >= hit.x
      and y >= hit.y
      and x < hit.x + hit.width
      and y < hit.y + hit.height
end

local function processTouch(item)
  local hit =
      inputTarget.find(
        composition.layout,
        item.x,
        item.y,
        "touch"
      )

  if
      not hit
      or not hit.modifier
  then
    return
  end

  if
      hit.modifier.onPress
      or hit.modifier.onRelease
  then
    composition.pointer = {
      hit = hit,
      button = item.button,
      player = item.player,
      screen = item.screen,
    }

    if hit.modifier.onPress then
      hit.modifier.onPress(
        pointerEvent(item, hit, true)
      )
    end
  elseif hit.modifier.onClick then
    hit.modifier.onClick(
      pointerEvent(item, hit, true)
    )
  end
end

local function processDropSignal(item)
  local pointer = composition.pointer

  if pointer
      and pointer.screen == item.screen
      and pointer.button == item.button
      and (
        pointer.player == nil
        or pointer.player == item.player
      )
  then
    local inside =
        containsHit(
          pointer.hit,
          item.x,
          item.y
        )

    if pointer.hit.modifier.onRelease then
      pointer.hit.modifier.onRelease(
        pointerEvent(item, pointer.hit, inside)
      )
    elseif inside
        and pointer.hit.modifier.onClick
    then
      pointer.hit.modifier.onClick(
        pointerEvent(item, pointer.hit, true)
      )
    end

    composition.pointer = nil
  end

  local hit =
      inputTarget.find(
        composition.layout,
        item.x,
        item.y,
        "drop"
      )

  if
      hit
      and hit.modifier
      and hit.modifier.onDrop
  then
    hit.modifier.onDrop(
      pointerEvent(item, hit, true)
    )
  end
end

local function processDragSignal(item)
  local hit =
      inputTarget.find(
        composition.layout,
        item.x,
        item.y,
        "drag"
      )

  if
      hit
      and hit.modifier
      and hit.modifier.onDrag
  then
    hit.modifier.onDrag(
      pointerEvent(item, hit, true)
    )
  end
end

local function processInput()
  for _, item in ipairs(
    input.drain()
  ) do
    if isLocalInput(item) then
      -- Global quit shortcut.
      if item.type == "keyDown" then
        local handled = false

        if composition.keyHandler then
          handled =
              composition.keyHandler(item)
              == true
        end

        if not handled
            and (
              item.char
              == string.byte("q")
              or item.char
              == string.byte("Q")
            )
        then
          composition.running =
              false
        end
      elseif item.type == "touch" then
        processTouch(item)
      elseif item.type == "scroll" then
        local hit =
            inputTarget.find(
              composition.layout,
              item.x,
              item.y,
              "scroll"
            )

        if
            hit
            and hit.modifier
            and hit.modifier.onScroll
        then
          hit.modifier.onScroll(
            item.direction,
            {
              x = hit.localX,
              y = hit.localY,

              screenX = item.x,
              screenY = item.y,

              player = item.player,
              screen = item.screen,
            }
          )
        end
      end
    end
  end
end

local function pullInput(timeout)
  local signal = getPlatform().pull(timeout)

  if not signal[1] then
    return
  end

  dispatchEvent(
    signal
  )

  local name = signal[1]

  if name == "drag" or name == "drop" then
    local item = {
      type = name,
      screen = signal[2],
      x = signal[3],
      y = signal[4],
      button = signal[5],
      player = signal[6],
    }

    if isLocalInput(item) then
      if name == "drag" then
        processDragSignal(item)
      else
        processDropSignal(item)
      end
    end
  else
    input.pushRaw(
      table.unpack(signal)
    )
  end
end


function runtime.invalidateLayout()
  if composition then
    composition.layoutDirty =
        true
  end
end

function runtime.invalidate()
  if composition then
    composition.dirty = true
  end
end

function runtime.setKeyHandler(handler)
  assert(
    type(handler) == "function",
    "setKeyHandler() requires a function"
  )

  assert(
    composition,
    "setKeyHandler() outside Compose App"
  )

  composition.keyHandler = handler
end

function runtime.quit()
  if composition then
    composition.running = false
  end
end

function runtime.uptime()
  assert(
    composition,
    "uptime() outside Compose App"
  )

  return math.max(
    0,
    now() - composition.startedAt
  )
end

function runtime.metrics()
  assert(
    composition,
    "metrics() outside Compose App"
  )

  local metrics = composition.metrics

  return {
    cpuPercent = metrics.cpuPercent,
    cpuEstimated = true,
    busySeconds = metrics.busySeconds,
    windowSeconds = metrics.windowSeconds,
    iterations = metrics.iterations,
  }
end

local function validatePlatform(platform)
  assert(
    type(platform) == "table",
    "Compose platform must be a table"
  )

  assert(
    type(platform.now) == "function",
    "Compose platform requires now()"
  )

  assert(
    type(platform.pull) == "function",
    "Compose platform requires pull()"
  )

  assert(
    type(platform.isLocalInput) == "function",
    "Compose platform requires isLocalInput()"
  )
end

local function cleanupComposition()
  local firstError = nil

  if composition then
    firstError = disposeScope(composition.root)
    composition.scheduler:dispose()
  end

  input.clear()
  currentScope = nil
  composition = nil

  return firstError
end

function runtime.App(content, render, options)
  assert(
    type(content) == "function",
    "Compose content must be a function"
  )

  assert(
    type(render) == "function",
    "Compose render must be a function"
  )

  local previousPlatform = activePlatform
  local platform = options and options.platform

  if not platform then
    if not defaultPlatform then
      defaultPlatform = require("lib.compose.host").create()
    end

    platform = defaultPlatform
  end

  validatePlatform(platform)
  activePlatform = platform

  local startedAt =
      platform.now()

  composition = {
    scheduler = coroutineScheduler.create({
      now = now,
    }),
    dirty = true,
    layoutDirty = true,
    running = true,
    pointer = nil,
    startedAt = startedAt,
    metrics = {
      windowStarted = startedAt,
      windowSeconds = 0,
      busySeconds = 0,
      cpuPercent = 0,
      iterations = 0,
    },
    keyHandler = nil,
    layout = nil,
    tree = nil,
  }

  composition.root =
      createScope(
        "__root",
        nil
      )

  input.clear()

  local ok, err = pcall(function()
    while composition.running do
      local workStartedAt = now()

      runEffects()
      processInput()

      if composition.dirty then
        composition.dirty =
            false

        composition.tree =
            composeRoot(
              content
            )

        composition.layoutDirty =
            true
      end

      if composition.layoutDirty then
        composition.layoutDirty =
            false

        composition.layout =
            render(
              composition.tree
            )
      end

      if not composition.running then
        break
      end

      recordWork(
        workStartedAt,
        now()
      )

      pullInput(
        math.min(
          nextWake(),
          0.1
        )
      )
    end
  end)

  local cleanupOk, cleanupError = pcall(cleanupComposition)
  activePlatform = previousPlatform

  if not ok then
    error(err, 0)
  end

  if not cleanupOk then
    error(cleanupError, 0)
  end
end

return runtime
