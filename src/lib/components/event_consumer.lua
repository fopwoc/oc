local compose = require("lib.compose.init")

local eventConsumer = {}

function eventConsumer.EventConsumer(options)
  assert(
    type(options) == "table",
    "EventConsumer requires an options table"
  )

  assert(
    type(options.content) == "function",
    "EventConsumer requires a content function"
  )

  local modifier =
      options.modifier
      or compose.Modifier

  local pressed =
      compose.remember(false)

  if
      options.onClick
      or options.onPress
      or options.onRelease
  then
    modifier =
        modifier:clickable(
          options.onClick
          or function()
          end,
          {
            onPress = function(event)
              pressed.value = true

              if options.onPress then
                options.onPress(event)
              end
            end,

            onRelease = function(event)
              local wasPressed =
                  pressed.value

              pressed.value = false

              if options.onRelease then
                options.onRelease(event)
              end

              if
                  options.onClick
                  and wasPressed
                  and event.inside
              then
                options.onClick(event)
              end
            end,
          }
        )
  end

  if options.onDrag or options.onDrop then
    modifier =
        modifier:draggable(
          options.onDrag
          or function()
          end,
          options.onDrop
        )
  end

  return options.content({
    modifier = modifier,
    pressed = pressed.value,
  })
end

return eventConsumer
