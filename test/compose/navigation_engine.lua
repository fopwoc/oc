package.path = "src/?.lua;" .. package.path

local navigation = require("lib.compose.navigation")
local nodes = require("lib.compose.nodes")
local runtime = require("lib.compose.runtime")

local changes = 0
local backStack = navigation.create("home", {title = "Home"}, function()
  changes = changes + 1
end)

assert(backStack:size() == 1)
assert(backStack:current().key == "home")
assert(backStack:current().id == 1)

local details = backStack:push("details", {id = 42})
assert(backStack:size() == 2)
assert(backStack:current() == details)
assert(backStack:current().args.id == 42)
assert(backStack:canPop())

backStack:push("settings")
assert(backStack:popTo("details"))
assert(backStack:current() == details)
assert(backStack:size() == 2)

local replacement = backStack:replace("profile")
assert(backStack:current() == replacement)
assert(backStack:current().id ~= details.id)
assert(backStack:pop() == replacement)
assert(backStack:current().key == "home")
assert(not backStack:canPop())
assert(backStack:pop() == nil)
assert(changes == 5)

local providerCalls = {home = 0, details = 0}
local pullCount = 0
local renderCount = 0
local maxRenderedDestinations = 0

local platform = {
  now = function()
    return 0
  end,

  pull = function()
    pullCount = pullCount + 1

    if pullCount == 2 then
      return {"navigation_continue"}
    end

    if pullCount >= 3 then
      return {"key_down", "test-keyboard", string.byte("q"), 0}
    end

    return {}
  end,

  isLocalInput = function()
    return true
  end,
}

runtime.App(
  function()
    local stackHolder = runtime.remember(function()
      return navigation.create("home", nil, runtime.invalidate)
    end)

    local stack = stackHolder.value

    runtime.LaunchedEffect("navigation-lifecycle", function()
      stack:push("details")
      runtime.awaitEvent("navigation_continue")
      stack:pop()
    end)

    return navigation.display(stack, {
      home = function()
        providerCalls.home = providerCalls.home + 1
        return nodes.Text("home")
      end,

      details = function()
        providerCalls.details = providerCalls.details + 1
        return nodes.Text("details")
      end,
    })
  end,
  function(tree)
    renderCount = renderCount + 1
    maxRenderedDestinations = math.max(
      maxRenderedDestinations,
      #(tree.props.children or {})
    )
  end,
  {platform = platform}
)

assert(renderCount == 3)
assert(providerCalls.home == 1)
assert(providerCalls.details == 1)
assert(
  maxRenderedDestinations == 1,
  "inactive destinations should retain state without entering layout"
)

print("navigation engine: OK")
