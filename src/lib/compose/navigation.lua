local runtime = require("lib.compose.runtime")
local nodes = require("lib.compose.nodes")
local modifier = require("lib.compose.modifier")

local navigation = {}

local function assertKey(key)
  assert(
    type(key) == "string"
      and key ~= "",
    "navigation key must be a non-empty string"
  )
end

local function notify(backStack)
  if backStack.onChange then
    backStack.onChange()
  end
end

function navigation.create(
    startKey,
    startArgs,
    onChange
)
  assertKey(startKey)

  local backStack = {
    entries = {},
    nextId = 0,
    onChange = onChange,
  }

  local function createEntry(key, args)
    assertKey(key)

    backStack.nextId =
        backStack.nextId + 1

    return {
      id = backStack.nextId,
      key = key,
      args = args,
    }
  end

  local function append(key, args)
    local entry =
        createEntry(key, args)

    backStack.entries[#backStack.entries + 1] =
        entry

    notify(backStack)

    return entry
  end

  backStack.entries[1] =
      createEntry(startKey, startArgs)

  function backStack:current()
    return self.entries[#self.entries]
  end

  function backStack:size()
    return #self.entries
  end

  function backStack:canPop()
    return #self.entries > 1
  end

  function backStack:push(key, args)
    return append(key, args)
  end

  backStack.navigate =
      backStack.push

  function backStack:replace(key, args)
    local entry =
        createEntry(key, args)

    self.entries[#self.entries] =
        entry

    notify(self)

    return entry
  end

  function backStack:pop()
    if not self:canPop() then
      return nil
    end

    local entry =
        table.remove(
          self.entries
        )

    notify(self)

    return entry
  end

  function backStack:popTo(key, inclusive)
    assertKey(key)

    local index = nil

    for i = #self.entries, 1, -1 do
      if self.entries[i].key == key then
        index = i
        break
      end
    end

    if not index then
      return false
    end

    local targetIndex =
        inclusive
        and index - 1
        or index

    -- The root entry always remains in the stack.
    targetIndex =
        math.max(1, targetIndex)

    if targetIndex >= #self.entries then
      return false
    end

    while #self.entries > targetIndex do
      table.remove(self.entries)
    end

    notify(self)

    return true
  end

  function backStack:popToRoot()
    if #self.entries <= 1 then
      return false
    end

    while #self.entries > 1 do
      table.remove(self.entries)
    end

    notify(self)

    return true
  end

  function backStack:entriesSnapshot()
    local result = {}

    for i, entry in ipairs(self.entries) do
      result[i] = entry
    end

    return result
  end

  return backStack
end

local function resolveProvider(provider, entry)
  if type(provider) == "function" then
    return provider(entry)
  end

  assert(
    type(provider) == "table",
    "NavDisplay provider must be a function or table"
  )

  local content =
      provider[entry.key]

  assert(
    type(content) == "function",
    "NavDisplay has no destination for: "
      .. entry.key
  )

  return content(entry)
end

function navigation.display(
    backStack,
    provider,
    modifierValue
)
  assert(
    type(backStack) == "table"
      and type(backStack.current) == "function",
    "NavDisplay requires a navigation back stack"
  )

  local current =
      backStack:current()

  assert(
    current,
    "NavDisplay requires a non-empty back stack"
  )

  local children = {}

  for _, entry in ipairs(
    backStack:entriesSnapshot()
  ) do
    local content =
        runtime.RecomposeScope(
          "navigation:" .. tostring(entry.id),
          function()
            return resolveProvider(
              provider,
              entry
            )
          end,
          {
            active = entry == current,
          }
        )

    assert(
      type(content) == "table",
      "NavDisplay destination must return a node"
    )

    children[#children + 1] =
        nodes.Box(
          { content },
          modifier.Modifier
          :visible(entry == current)
        )
  end

  return nodes.Box(children, modifierValue)
end

return navigation
