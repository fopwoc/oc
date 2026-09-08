local compose = require("lib.compose.init")
local eventConsumer = require("lib.components.event_consumer")
local colorStyle = require("lib.components.color_style")

local button = {}

button.styles = {}

local function hasForeground(modifier)
  for _, element in ipairs(modifier.elements or {}) do
    if element.type == "foreground" then
      return true
    end
  end

  return false
end

button.styles.compact = function(text, modifier, pressed, colors)
  colors = colors or colorStyle.current()

  if pressed then
    modifier =
        modifier:background(colors.surfaceVariant)
  end

  if not hasForeground(modifier) then
    modifier = modifier:foreground(colors.foreground)
  end

  return compose.Text(
    "[ " .. tostring(text) .. " ]",
    modifier
  )
end

button.styles.cell = function(text, modifier, pressed, colors)
  colors = colors or colorStyle.current()

  local background =
      pressed
      and colors.primary
      or colors.primaryContainer

  local foreground =
      pressed
      and colors.onPrimary
      or colors.onPrimaryContainer

  return compose.Box({
      compose.Text(
        tostring(text),
        compose.Modifier:foreground(foreground)
      ),
    },
    modifier
    :padding(1)
    :foreground(foreground)
    :background(background)
  )
end

function button.Button(
    text,
    onClick,
    modifier,
    style
)
  modifier =
      modifier
      or compose.Modifier

  style =
      style
      or button.styles.compact

  return eventConsumer.EventConsumer({
    modifier = modifier,
    onClick = onClick,
    content = function(state)
      return style(
        text,
        state.modifier,
        state.pressed,
        colorStyle.current()
      )
    end,
  })
end

return button
