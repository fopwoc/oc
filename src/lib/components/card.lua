local compose = require("lib.compose.init")

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

  local content =
      compose.Column(
        children or {}
      )

  return compose.Box(
    {content},
    modifier
    :border(
      border.color,
      border.characters
    )
    :padding(1)
  )
end

return card
