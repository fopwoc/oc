local compose = require("lib.compose.init")
local components = require("lib.components.init")
local navigation = require("lib.compose.navigation")
local runtime = require("lib.compose.runtime")

local stack = nil
local finished = false
local pullCount = 0
local slotContexts = {}

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
      topBar = function(context)
        slotContexts.top = context
        return compose.Text("top")
      end,
      content = function(context)
        slotContexts.content = context
        return compose.Text("content")
      end,
      bottomBar = function(context)
        slotContexts.bottom = context
        return compose.Text("bottom")
      end,
    })
  end,
  function()
  end,
  {platform = platform}
)

assert(stack:size() == 1)
assert(finished)
assert(
  slotContexts.top
    and slotContexts.top == slotContexts.content
    and slotContexts.content == slotContexts.bottom
    and type(slotContexts.top.requestQuit) == "function",
  "all Scaffold slots should receive the shared slot context"
)

print("scaffold key handling: OK")
