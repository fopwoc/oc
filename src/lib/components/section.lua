local compose = require("lib.compose.init")
local card = require("lib.components.card")
local colorStyle = require("lib.components.color_style")

local section = {}

function section.Section(title, children, modifier)
  local colors = colorStyle.current()
  local content = {
    compose.Text(
      tostring(title),
      compose.Modifier:foreground(colors.primary)
    ),
    compose.Spacer(compose.Modifier:height(1)),
  }

  for _, child in ipairs(children or {}) do
    content[#content + 1] = child
  end

  return card.Card(
    content,
    (modifier or compose.Modifier):fillMaxWidth()
  )
end

return section
