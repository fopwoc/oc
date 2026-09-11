package.path = "src/?.lua;" .. package.path

local nodes = require("lib.compose.nodes")
local modifier = require("lib.compose.modifier")

local previousCompose = package.loaded["lib.compose.init"]
local previousScaffold = package.loaded["lib.components.scaffold"]
local previousTopAppBar = package.loaded["lib.components.top_app_bar"]
local previousCommandBar = package.loaded["lib.components.command_bar"]
local previousEntrypoint = package.loaded["lib.components.entrypoint"]
local captured = {}
local scopes = {}

package.loaded["lib.compose.init"] = {
  Modifier = modifier.Modifier,
  Box = nodes.Box,
  remember = function(value)
    return {
      value = type(value) == "function"
        and value()
        or value,
    }
  end,
  LaunchedEffect = function()
  end,
  RecomposeScope = function(key, content)
    scopes[#scopes + 1] = key
    return content()
  end,
  hardware = function()
    return {memoryPercent = 42}
  end,
  metrics = function()
    return {}
  end,
  rendererMetrics = function()
    return {}
  end,
  uptime = function()
    return 3661
  end,
}

package.loaded["lib.components.scaffold"] = {
  Scaffold = function(options)
    captured.scaffold = options
    return nodes.Text("scaffold")
  end,
}

package.loaded["lib.components.top_app_bar"] = {
  TopAppBar = function(options)
    captured.top = options
    return nodes.Text("top")
  end,
}

package.loaded["lib.components.command_bar"] = {
  CommandBar = function(options)
    captured.bottom = options
    return nodes.Text("bottom")
  end,
}

package.loaded["lib.components.entrypoint"] = nil

local entrypoint = require("lib.components.entrypoint")
local navigation = {
  push = function()
  end,
  pop = function()
  end,
}

entrypoint.Entrypoint({
  title = "Monitor",
  service = "POWER",
  navigation = navigation,
  content = nodes.Text("content"),
})

local contentPadding

for _, element in ipairs(captured.scaffold.content.modifier.elements) do
  if element.type == "padding" then
    contentPadding = element
  end
end

assert(
  contentPadding
    and contentPadding.left == 1
    and contentPadding.top == 1
    and contentPadding.right == 1
    and contentPadding.bottom == 1,
  "Entrypoint should own the centered one-cell content inset"
)

captured.scaffold.topBar({requestQuit = function()
end})
captured.scaffold.bottomBar({})

assert(
  scopes[1] == "entrypoint-content"
    and scopes[2] == "entrypoint-top-bar"
    and scopes[3] == "entrypoint-bottom-bar",
  "Entrypoint should isolate content and shell bar recomposition"
)

assert(
  captured.top.trailing == "UP 1h 01m"
    and captured.top.background == captured.top.colorStyle.surfaceVariant,
  "the top bar should use compact uptime and the raised surface"
)

assert(
  captured.bottom.service.label == "POWER"
    and captured.bottom.service.color == captured.bottom.colorStyle.muted
    and captured.bottom.trailing.label == "RAM 42%",
  "the bottom bar should keep service and memory metadata quiet"
)

package.loaded["lib.compose.init"] = previousCompose
package.loaded["lib.components.scaffold"] = previousScaffold
package.loaded["lib.components.top_app_bar"] = previousTopAppBar
package.loaded["lib.components.command_bar"] = previousCommandBar
package.loaded["lib.components.entrypoint"] = previousEntrypoint

print("entrypoint shell: OK")
