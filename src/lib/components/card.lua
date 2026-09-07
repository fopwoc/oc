local compose = require("../lib/compose/init")

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

  return compose.Box(
    children or {},
    modifier
    :border(
      border.color,
      border.characters
    )
    :padding(1)
  )
end

return card
