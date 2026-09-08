local compose = require("lib.compose.init")

local colors = {
  background = 0x111418,
  primary = 0x66CCFF,
  text = 0xD8DEE9,
}

local function screen(
    title,
    body,
    action
)
  return compose.Column({
      compose.Text(
        title,
        compose.Modifier
        :foreground(colors.primary)
      ),

      compose.Spacer(
        compose.Modifier:height(1)
      ),

      compose.Text(body),

      compose.Spacer(
        compose.Modifier:height(1)
      ),

      compose.Text(
        action.label,
        compose.Modifier
        :clickable(action.onClick)
      ),
    },
    compose.Modifier
    :fillMaxWidth()
    :fillMaxHeight()
    :background(colors.background)
    :foreground(colors.text)
    :padding(1)
  )
end

compose.App(function()
  local backStack =
      compose.rememberNavBackStack(
        "home"
      )

  return compose.NavDisplay(
    backStack,
    {
      home = function()
        return screen(
          "HOME",
          "Navigation is rendered by the compose engine.",
          {
            label = "[ Open details ]",
            onClick = function()
              backStack:push(
                "details",
                {
                  message = "This entry has its own identity."
                }
              )
            end,
          }
        )
      end,

      details = function(entry)
        return screen(
          "DETAILS #" .. tostring(entry.id),
          entry.args.message,
          {
            label = "[ Back ]",
            onClick = function()
              backStack:pop()
            end,
          }
        )
      end,
    }
  )
end)
