local compose = require("lib.compose.init")

local button = {}

function button.Button(
    text,
    onClick,
    modifier
)
  modifier =
      modifier
      or compose.Modifier

  return compose.Text(
    "[ " .. tostring(text) .. " ]",

    modifier
    :clickable(onClick)
  )
end

return button
