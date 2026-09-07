local compose = require("lib.compose.init")

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
