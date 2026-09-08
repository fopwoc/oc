local runtime = require("lib.compose.runtime")
local nodes = require("lib.compose.nodes")
local renderer = require("lib.compose.renderer")
local modifier = require("lib.compose.modifier")
local color = require("lib.compose.color")
local scroll = require("lib.compose.scroll")
local navigation = require("lib.compose.navigation")
local hardware = require("lib.compose.hardware")
local ringBuffer = require("lib.compose.ring_buffer")

local compose = {}

-- Runtime

compose.remember = runtime.remember
compose.LaunchedEffect = runtime.LaunchedEffect
compose.DisposableEffect = runtime.DisposableEffect
compose.RecomposeScope = runtime.RecomposeScope
compose.delay = runtime.delay
compose.awaitEvent = runtime.awaitEvent
compose.uptime = runtime.uptime
compose.metrics = runtime.metrics
compose.hardware = hardware.snapshot
compose.rendererMetrics = renderer.metrics
compose.setKeyHandler = runtime.setKeyHandler
compose.quit = runtime.quit
compose.RingBuffer = ringBuffer.create

-- Nodes

compose.Text = nodes.Text
compose.Column = nodes.Column
compose.Row = nodes.Row
compose.Spacer = nodes.Spacer
compose.Box = nodes.Box

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

function compose.rememberRingBuffer(capacity)
  local holder =
      runtime.remember(function()
        return ringBuffer.create(capacity)
      end)

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
  local rendererOptions =
      options and options.renderer

  renderer.reset(rendererOptions)

  local ok, err =
      pcall(
        runtime.App,
        content,
        function(tree)
          return renderer.render(
            tree,
            rendererOptions
          )
        end,
        options
      )

  local clearOk, clearError =
      pcall(
        renderer.reset,
        rendererOptions
      )

  if not ok then
    error(err, 0)
  end

  if not clearOk then
    error(clearError, 0)
  end
end

return compose
