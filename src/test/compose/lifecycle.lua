local runtime = require("lib.compose.runtime")
local navigation = require("lib.compose.navigation")
local nodes = require("lib.compose.nodes")

local function runWithSignals(signals, content)
  local index = 0
  local platform = {
    now = function()
      return 0
    end,

    pull = function()
      index = index + 1
      return signals[index] or {
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
    content,
    function()
    end,
    {
      platform = platform,
    }
  )
end

local workerRuns = 0

runWithSignals(
  {
    {},
    {"hide"},
    {"ping"},
    {"show"},
    {"ping"},
    {"key_down", "test-keyboard", string.byte("q"), 0},
  },
  function()
    local visible = runtime.remember(true)

    runtime.LaunchedEffect("driver", function()
      runtime.awaitEvent("hide")
      visible.value = false

      runtime.awaitEvent("show")
      visible.value = true
    end)

    return runtime.RecomposeScope(
      "screen",
      function()
        runtime.LaunchedEffect("worker", function()
          while true do
            runtime.awaitEvent("ping")
            workerRuns = workerRuns + 1
          end
        end)

        return nodes.Text("screen")
      end,
      {
        active = visible.value,
      }
    )
  end
)

assert(
  workerRuns == 1,
  "inactive navigation scope must not consume events"
)

local cleanupCount = 0

runWithSignals(
  {
    {"remove"},
    {"key_down", "test-keyboard", string.byte("q"), 0},
  },
  function()
    local mounted = runtime.remember(true)

    runtime.LaunchedEffect("driver", function()
      runtime.awaitEvent("remove")
      mounted.value = false
    end)

    if mounted.value then
      runtime.RecomposeScope("resource-owner", function()
        runtime.DisposableEffect("resource", function()
          return function()
            cleanupCount = cleanupCount + 1
          end
        end)

        return nodes.Text("resource")
      end)
    end

    return nodes.Text("root")
  end
)

assert(
  cleanupCount == 1,
  "disposing a scope must run its cleanup exactly once"
)

local stack = navigation.create("home")
local setupCount = 0
local finalCleanupCount = 0

runWithSignals(
  {
    {"key_down", "test-keyboard", string.byte("q"), 0},
  },
  function()
    runtime.DisposableEffect("resource", function()
      setupCount = setupCount + 1

      return function()
        finalCleanupCount = finalCleanupCount + 1
      end
    end)

    return navigation.display(
      stack,
      {
        home = function()
          return nodes.Text("home")
        end,
      }
    )
  end
)

assert(setupCount == 1)
assert(finalCleanupCount == 1)

local slotMismatchOk, slotMismatchError = pcall(runWithSignals, {
  {},
  {"flip"},
  {"key_down", "test-keyboard", string.byte("q"), 0},
}, function()
  local flipped = runtime.remember(false)

  runtime.LaunchedEffect("flip", function()
    runtime.awaitEvent("flip")
    flipped.value = true
  end)

  -- A conditional remember() shifts the LaunchedEffect into its slot.
  if flipped.value then
    runtime.remember(0)
  end

  runtime.LaunchedEffect("worker", function()
  end)

  return nodes.Text("slots")
end)

assert(
  not slotMismatchOk
    and tostring(slotMismatchError):find("slot", 1, true),
  "a slot that changes kind between compositions must fail loudly"
)

print("lifecycle: OK")
