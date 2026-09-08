local compose = require("lib.compose.init")
local colorStyle = require("lib.components.color_style")

local telemetryStatus = {}

function telemetryStatus.TelemetryStatus(sender, context)
  assert(
    type(sender) == "table"
      and type(sender.status) == "function",
    "TelemetryStatus requires a telemetry sender"
  )

  local colors =
      context
      and (context.colorStyle or context.colors)
      or colorStyle.current()
  local status = sender:status()
  local label = "TEL --"
  local color = colors.muted

  if status.state == "sent" then
    label = "TEL OK"
    color = colors.good
  elseif status.state == "failed" then
    label = "TEL ERR"
    color = colors.bad
  end

  return compose.Row({
    compose.Text(
      label,
      compose.Modifier:foreground(color)
    ),
    compose.Spacer(compose.Modifier:width(1)),
  })
end

return telemetryStatus
