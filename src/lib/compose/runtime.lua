local component = require("component")
local computer = require("computer")
local event = require("event")

local input = require("../lib/compose/input")
local hitTest = require("../lib/compose/hit_test")

local runtime = {}

local composition = nil
local currentScope = nil


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


local function cancelEffect(effect)
  if
    effect
    and effect.kind == "effect"
  then
    effect.cancelled = true
  end
end


local function disposeScope(scope)
  removeDependencies(scope)

  for _, value in pairs(scope.slots) do
    cancelEffect(value)
  end

  for _, childScope in pairs(scope.scopes) do
    disposeScope(childScope)
  end

  scope.slots = {}
  scope.scopes = {}
  scope.node = nil
end


local function finishScope(scope)
  for index, value in pairs(scope.slots) do
    if
      type(index) == "number"
      and index > scope.slot
    then
      cancelEffect(value)
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
  coroutine.yield({
    kind = "delay",
    wakeAt =
      computer.uptime()
        + seconds,
  })
end


function runtime.awaitEvent(name)
  assert(
    type(name) == "string",
    "awaitEvent() requires an event name"
  )

  return coroutine.yield({
    kind = "event",
    name = name,
  })
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

  local effect = {
    kind = "effect",
    key = key,
    thread =
      coroutine.create(block),

    wakeAt = 0,
    waitingEvent = nil,

    cancelled = false,
  }

  currentScope.slots[index] =
    effect

  table.insert(
    composition.effects,
    effect
  )
end


function runtime.RecomposeScope(key, content)
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


local function resumeEffect(
  effect,
  ...
)
  effect.waitingEvent =
    nil

  local ok, yielded =
    coroutine.resume(
      effect.thread,
      ...
    )

  if not ok then
    error(yielded, 0)
  end

  if
    coroutine.status(effect.thread)
      == "dead"
  then
    return
  end

  if
    type(yielded) == "table"
    and yielded.kind == "delay"
  then
    effect.wakeAt =
      yielded.wakeAt
    effect.waitingEvent =
      nil

  elseif
    type(yielded) == "table"
    and yielded.kind == "event"
  then
    effect.waitingEvent =
      yielded.name

  else
    effect.wakeAt =
      computer.uptime()
    effect.waitingEvent =
      nil
  end
end


local function runEffects()
  local now =
    computer.uptime()

  local index = 1

  while
    index <= #composition.effects
  do
    local effect =
      composition.effects[index]

    if
      effect.cancelled
      or coroutine.status(
        effect.thread
      ) == "dead"
    then
      table.remove(
        composition.effects,
        index
      )

    elseif
      not effect.waitingEvent
      and effect.wakeAt <= now
    then
      resumeEffect(
        effect
      )

      if
        coroutine.status(
          effect.thread
        ) == "dead"
      then
        table.remove(
          composition.effects,
          index
        )
      else
        index =
          index + 1
      end

    else
      index =
        index + 1
    end
  end
end


local function dispatchEvent(signal)
  local name =
    signal[1]

  if not name then
    return
  end

  for _, effect in ipairs(
    composition.effects
  ) do
    if
      not effect.cancelled
      and effect.waitingEvent
        == name
      and coroutine.status(
        effect.thread
      ) ~= "dead"
    then
      resumeEffect(
        effect,
        table.unpack(signal)
      )
    end
  end
end


local function nextWake()
  local wakeAt = nil

  for _, effect in ipairs(
    composition.effects
  ) do
    if
      not effect.cancelled
      and not effect.waitingEvent
      and coroutine.status(
        effect.thread
      ) ~= "dead"
    then
      if
        wakeAt == nil
        or effect.wakeAt < wakeAt
      then
        wakeAt =
          effect.wakeAt
      end
    end
  end

  if not wakeAt then
    return 1
  end

  return math.max(
    0,
    wakeAt
      - computer.uptime()
  )
end

local function isLocalInput(item)
  local gpu =
    component.gpu

  local screen =
    gpu.getScreen()

  if not screen then
    return false
  end

  if
    item.type == "touch"
    or item.type == "scroll"
    or item.type == "drag"
    or item.type == "drop"
  then
    return item.screen == screen
  end

  if
    item.type == "keyDown"
    or item.type == "keyUp"
  then
    local keyboards =
      component.invoke(
        screen,
        "getKeyboards"
      )

    for _, address in ipairs(
      keyboards
    ) do
      if item.keyboard == address then
        return true
      end
    end

    return false
  end

  return true
end

local function processInput()
  for _, item in ipairs(
    input.drain()
    ) do
  if isLocalInput(item) then
    -- Global quit shortcut.
    if item.type == "keyDown" then
      if
        item.char
          == string.byte("q")
        or item.char
          == string.byte("Q")
      then
        composition.running =
          false
      end

    elseif item.type == "touch" then
      local hit =
        hitTest.find(
          composition.layout,
          item.x,
          item.y,
          "touch"
        )

      if
        hit
        and hit.modifier
        and hit.modifier.onClick
      then
        hit.modifier.onClick({
          x = hit.localX,
          y = hit.localY,

          screenX = item.x,
          screenY = item.y,

          button = item.button,
          player = item.player,
          screen = item.screen,
        })
      end

    elseif item.type == "scroll" then
      local hit =
        hitTest.find(
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
  local signal = {
    event.pull(timeout)
  }

  if not signal[1] then
    return
  end

  dispatchEvent(
    signal
  )

  input.pushRaw(
    table.unpack(signal)
  )
end


function runtime.invalidateLayout()
  if composition then
    composition.layoutDirty =
      true
  end
end


function runtime.App(content, render)
  composition = {
    effects = {},
    dirty = true,
    layoutDirty = true,
    running = true,
    layout = nil,
    tree = nil,
  }

  composition.root =
    createScope(
      "__root",
      nil
    )

  input.clear()

  while composition.running do
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

    pullInput(
      math.min(
        nextWake(),
        0.1
      )
    )
  end

  currentScope =
    nil

  composition =
    nil
end


return runtime
