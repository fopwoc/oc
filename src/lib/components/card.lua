local compose = require("lib.compose.init")
local colorStyle = require("lib.components.color_style")

local card = {}

function card.Card(
    children,
    modifier,
    border
)
  modifier =
      modifier
      or compose.Modifier

  border =
      border
      or {}

  local padding = border.padding

  if padding == nil then
    padding = 1
  end

  assert(
    type(padding) == "number"
      and padding >= 0,
    "Card padding must be non-negative"
  )

  local colors = colorStyle.current()

  local content =
      compose.Column(
        children or {}
      )

  return compose.Box(
    {content},
    modifier
    :border(
      border.color or colors.border,
      border.characters
    )
    :padding(padding)
  )
end

return card
