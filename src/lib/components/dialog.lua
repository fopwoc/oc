local compose = require("../lib/compose/init")
local card = require("../lib/components/card")

local dialog = {}

function dialog.Dialog(
  title,
  children,
  modifier
)
  modifier =
    modifier
    or compose.Modifier

  local content = {}

  if title then
    content[#content + 1] =
      compose.Text(tostring(title))

    content[#content + 1] =
      compose.Spacer(
        compose.Modifier:height(1)
      )
  end

  for _, child in ipairs(
    children or {}
  ) do
    content[#content + 1] =
      child
  end

  return compose.Box({
    card.Card(
      {
        compose.Column(content)
      },
      modifier
        :align("center", "center")
    )
  },
    compose.Modifier
      :fillMaxWidth()
      :fillMaxHeight()
      :clickable(function()
        -- Modal input barrier.
      end)
      :scrollable(function()
        -- Modal input barrier.
      end)
  )
end

return dialog
