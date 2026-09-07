package.path = "src/?.lua;" .. package.path

local nativeRequire = require

require = function(name)
  if name:sub(1, 3) == "../" then
    name = name:sub(4)
  end

  return nativeRequire(name:gsub("/", "."))
end

local runtime = require("lib.compose.runtime")

local pullCount = 0
local renderCount = 0
local renderedValue = nil
local clock = 0

local platform = {
  now = function()
    clock = clock + 1
    return clock
  end,

  pull = function()
    pullCount = pullCount + 1

    if pullCount == 1 then
      return {}
    end

    return {
      "key_down",
      "test-keyboard",
      string.byte("q"),
      0,
    }
  end,

  isLocalInput = function()
    return true
  end,
}

runtime.App(
  function()
    local state = runtime.remember(0)

    runtime.LaunchedEffect("update", function()
      state.value = 1
    end)

    return {
      value = state.value,
    }
  end,
  function(tree)
    renderCount = renderCount + 1
    renderedValue = tree.value
  end,
  {
    platform = platform,
  }
)

assert(
  renderCount == 2,
  "state update should trigger exactly one recomposition"
)

assert(
  renderedValue == 1,
  "recomposition should observe the updated state"
)

print("compose engine: OK")
