package.path = "src/?.lua;" .. package.path

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

  runtime.App(content, function()
  end, {platform = platform})
end

local workerRuns = 0

runWithSignals({
  {},
  {"hide"},
  {"ping"},
  {"show"},
  {"ping"},
  {"key_down", "test-keyboard", string.byte("q"), 0},
}, function()
  local visible = runtime.remember(true)

  runtime.LaunchedEffect("driver", function()
    runtime.awaitEvent("hide")
    visible.value = false
    runtime.awaitEvent("show")
    visible.value = true
  end)

  return runtime.RecomposeScope("screen", function()
    runtime.LaunchedEffect("worker", function()
      while true do
        runtime.awaitEvent("ping")
        workerRuns = workerRuns + 1
      end
    end)

    return nodes.Text("screen")
  end, {active = visible.value})
end)

assert(workerRuns == 1)

local cleanupCount = 0

runWithSignals({
  {"remove"},
  {"key_down", "test-keyboard", string.byte("q"), 0},
}, function()
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
end)

assert(cleanupCount == 1)

local removedOk, removedError = pcall(function()
  runWithSignals({
    {"remove"},
  }, function()
    local mounted = runtime.remember(true)

    runtime.LaunchedEffect("driver", function()
      runtime.awaitEvent("remove")
      mounted.value = false
    end)

    if mounted.value then
      runtime.RecomposeScope("failing-resource", function()
        runtime.DisposableEffect("resource", function()
          return function()
            error("removed cleanup failed")
          end
        end)

        return nodes.Text("resource")
      end)
    end

    return nodes.Text("root")
  end)
end)

assert(
  not removedOk
    and tostring(removedError):find("removed cleanup failed", 1, true),
  "removed scope cleanup failures must reach the application boundary"
)

local finalOk, finalError = pcall(function()
  runWithSignals({}, function()
    runtime.DisposableEffect("failing-resource", function()
      return function()
        error("final cleanup failed")
      end
    end)

    return nodes.Text("root")
  end)
end)

assert(
  not finalOk
    and tostring(finalError):find("final cleanup failed", 1, true),
  "application shutdown cleanup failures must not be swallowed"
)

print("lifecycle: OK")
