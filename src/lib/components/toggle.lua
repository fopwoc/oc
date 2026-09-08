local compose = require("lib.compose.init")
local colorStyle = require("lib.components.color_style")

local toggle = {}

toggle.styles = {
  checkbox = {
    on = "[x]",
    off = "[ ]",
  },

  radio = {
    on = "(*)",
    off = "( )",
  },

  status = {
    on = "+",
    off = "-",
  },

  switch = {
    on = "[ON]",
    off = "[--]",
  },
}

function toggle.Toggle(
    label,
    checked,
    onChange,
    style,
    modifier
)
  style =
      style
      or toggle.styles.checkbox

  modifier =
      modifier
      or compose.Modifier

  local hasForeground = false

  for _, element in ipairs(modifier.elements or {}) do
    if element.type == "foreground" then
      hasForeground = true
      break
    end
  end

  if not hasForeground then
    modifier =
        modifier:foreground(
          colorStyle.current().foreground
        )
  end

  local indicator =
      checked
      and style.on
      or style.off

  if onChange then
    modifier =
        modifier:clickable(function()
          onChange(not checked)
        end)
  end

  return compose.Text(
    indicator
    .. " "
    .. tostring(label),

    modifier
  )
end

return toggle
