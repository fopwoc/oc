local runtime = require("../lib/compose/runtime")
local nodes = require("../lib/compose/nodes")
local renderer = require("../lib/compose/renderer")
local modifier = require("../lib/compose/modifier")
local scroll = require("../lib/compose/scroll")

local compose = {}

-- Runtime

compose.remember = runtime.remember
compose.LaunchedEffect = runtime.LaunchedEffect
compose.RecomposeScope = runtime.RecomposeScope
compose.delay = runtime.delay
compose.awaitEvent = runtime.awaitEvent

-- Nodes

compose.Text = nodes.Text
compose.Column = nodes.Column
compose.Row = nodes.Row
compose.Spacer = nodes.Spacer
compose.Box = nodes.Box
compose.Progress = nodes.Progress

-- Modifiers

compose.Modifier = modifier.Modifier

-- Scroll

function compose.rememberScrollState()
  local holder =
      runtime.remember(nil)

  if not holder.value then
    holder.value =
        scroll.createState(
          runtime.invalidateLayout
        )
  end

  return holder.value
end

-- Application

function compose.App(content, options)
  renderer.reset()

  runtime.App(
    content,
    renderer.render,
    options
  )
end

return compose
