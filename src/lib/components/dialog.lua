local compose = require("lib.compose.init")
local card = require("lib.components.card")
local colorStyle = require("lib.components.color_style")

local dialog = {}

function dialog.Dialog(
    title,
    children,
    modifier
)
  modifier =
      modifier
      or compose.Modifier

  local colors = colorStyle.current()

  local content = {}

  if title then
    content[#content + 1] =
        compose.Text(
          tostring(title),
          compose.Modifier:foreground(colors.onSurface)
        )

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
      :scrim(colors.scrim, colors.scrimAlpha)
      :clickable(function()
      -- Modal input barrier.
    end)
    :scrollable(function()
      -- Modal input barrier.
    end)
  )
end

return dialog
