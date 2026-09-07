local compose = require("lib.compose.init")

local function square(rgb, x, y)
  return compose.Box(
    {},
    compose.Modifier
      :width(8)
      :height(4)
      :offset(x, y)
      :background(
        compose.Color(rgb, 0.55)
      )
  )
end

compose.App(function()
  return compose.Column({
    compose.Text("COLOR COMPOSITING"),
    compose.Text("Semi-transparent RGB layers"),

    compose.Box({
      square(0xFF0000, 2, 1),
      square(0x00FF00, 0, 3),
      square(0x0000FF, 4, 3),
    },
      compose.Modifier
        :width(18)
        :height(9)
        :border()
    ),
  },
    compose.Modifier:padding(1)
  )
end)
