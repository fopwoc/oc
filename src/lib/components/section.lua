local compose = require("lib.compose.init")
local card = require("lib.components.card")
local colorStyle = require("lib.components.color_style")

local section = {}

function section.Section(title, children, modifier)
  local colors = colorStyle.current()
  local body = {}

  for _, child in ipairs(children or {}) do
    body[#body + 1] = child
  end

  return card.Card(
    {
      compose.Row(
        {
          compose.Text(
            " " .. tostring(title),
            compose.Modifier:foreground(colors.primary)
          ),
          compose.Spacer(compose.Modifier:weight(1)),
        },
        compose.Modifier
        :fillMaxWidth()
        :background(colors.surfaceVariant)
      ),
      compose.Column(
        body,
        compose.Modifier:padding(1)
      ),
    },
    (modifier or compose.Modifier)
    :fillMaxWidth()
    :background(colors.surface),
    {
      padding = 0,
    }
  )
end

return section
