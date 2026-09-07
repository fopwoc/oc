local compose = require("lib.compose.init")
local components = require("lib.components.init")
local navigation = require("lib.compose.navigation")
local runtime = require("lib.compose.runtime")

local stack = nil
local finished = false
local pullCount = 0

local platform = {
  now = function()
    return 0
  end,

  pull = function()
    pullCount = pullCount + 1

    if pullCount == 1 then
      return {}
    end

    if pullCount <= 4 then
      return {
        "key_down",
        "test-keyboard",
        string.byte("q"),
        0,
      }
    end

    return {"finish"}
  end,

  isLocalInput = function()
    return true
  end,
}

runtime.App(
  function()
    local holder = runtime.remember(function()
      return navigation.create("root")
    end)

    stack = holder.value

    runtime.LaunchedEffect("driver", function()
      stack:push("details")
      runtime.awaitEvent("finish")
      finished = true
      compose.quit()
    end)

    return components.Scaffold({
      navigation = stack,
      topBar = compose.Text("top"),
      content = compose.Text("content"),
      bottomBar = compose.Text("bottom"),
    })
  end,
  function()
  end,
  {platform = platform}
)

assert(stack:size() == 1)
assert(finished)

print("scaffold key handling: OK")
