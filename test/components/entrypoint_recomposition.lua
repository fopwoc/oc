package.path = "src/?.lua;" .. package.path

local runtime = require("lib.compose.runtime")
local nodes = require("lib.compose.nodes")
local modifier = require("lib.compose.modifier")

local moduleNames = {
  "lib.compose.init",
  "lib.components.scaffold",
  "lib.components.top_app_bar",
  "lib.components.command_bar",
  "lib.components.entrypoint",
}
local previous = {}

for _, name in ipairs(moduleNames) do
  previous[name] = package.loaded[name]
end

local topRenders = 0
local contentRenders = 0
local bottomRenders = 0

package.loaded["lib.compose.init"] = {
  Modifier = modifier.Modifier,
  Box = nodes.Box,
  remember = runtime.remember,
  LaunchedEffect = runtime.LaunchedEffect,
  RecomposeScope = runtime.RecomposeScope,
  delay = runtime.delay,
  uptime = runtime.uptime,
  hardware = function()
    return {memoryPercent = 42}
  end,
  metrics = function()
    return {}
  end,
  rendererMetrics = function()
    return {}
  end,
}

package.loaded["lib.components.scaffold"] = {
  Scaffold = function(options)
    local scaffoldContext = {
      requestQuit = function()
      end,
    }

    options.topBar(scaffoldContext)
    options.bottomBar(scaffoldContext)

    return {
      type = "scaffold",
      content = options.content,
    }
  end,
}

package.loaded["lib.components.top_app_bar"] = {
  TopAppBar = function()
    topRenders = topRenders + 1
    return nodes.Text("top")
  end,
}

package.loaded["lib.components.command_bar"] = {
  CommandBar = function()
    bottomRenders = bottomRenders + 1
    return nodes.Text("bottom")
  end,
}

package.loaded["lib.components.entrypoint"] = nil

local entrypoint = require("lib.components.entrypoint")
local elapsed = 0
local platform = {
  now = function()
    return elapsed
  end,
  pull = function(timeout)
    elapsed = elapsed + math.max(timeout or 0, 0.01)
    return {}
  end,
  isLocalInput = function()
    return true
  end,
}

runtime.App(
  function()
    runtime.LaunchedEffect("stop-test", function()
      runtime.delay(2.1)
      runtime.quit()
    end)

    return entrypoint.Entrypoint({
      title = "Monitor",
      navigation = {
        push = function()
        end,
        pop = function()
        end,
      },
      content = function()
        contentRenders = contentRenders + 1
        return nodes.Text("content")
      end,
    })
  end,
  function()
    return {}
  end,
  {platform = platform}
)

assert(
  topRenders >= 3,
  "uptime should independently recompose the top bar"
)

assert(
  contentRenders == 1,
  "uptime should not recompose Entrypoint content"
)

assert(
  bottomRenders == 1,
  "uptime should not recompose the bottom bar"
)

for _, name in ipairs(moduleNames) do
  package.loaded[name] = previous[name]
end

print("entrypoint recomposition: OK")
