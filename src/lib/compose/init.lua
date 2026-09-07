local runtime = require("../lib/compose/runtime")
local nodes = require("../lib/compose/nodes")
local renderer = require("../lib/compose/renderer")
local modifier = require("../lib/compose/modifier")
local color = require("../lib/compose/color")
local scroll = require("../lib/compose/scroll")
local navigation = require("../lib/compose/navigation")

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

compose.Color = color.create

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

function compose.rememberNavBackStack(
    startKey,
    startArgs
)
  local holder =
      runtime.remember(function()
        return navigation.create(
          startKey,
          startArgs,
          runtime.invalidate
        )
      end)

  return holder.value
end

compose.NavDisplay = navigation.display

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
