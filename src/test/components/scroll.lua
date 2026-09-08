local compose = require("lib.compose.init")

compose.App(function()
  local scrollState =
      compose.rememberScrollState()

  local stressTick =
      compose.remember(0)

  compose.LaunchedEffect(
    "scroll-recompose-stress",
    function()
      local direction = 1

      while true do
        local offset =
            scrollState:getValue()

        if
            direction > 0
            and offset >= scrollState.maxValue
        then
          direction = -1
        elseif
            direction < 0
            and offset <= 0
        then
          direction = 1
        end

        scrollState:scrollBy(direction)

        stressTick.value =
            stressTick.value + 1

        compose.delay(0.35)
      end
    end
  )

  local tick = stressTick.value
  local rendererMetrics =
      compose.rendererMetrics()

  local mode =
      rendererMetrics.scrollBlit
      and "GPU COPY"
      or "CELL DIFF"

  local rows = {}

  for index = 1, 100 do
    local value =
        (tick * 17 + index * 13) % 1000

    local background =
        (tick + index) % 2 == 0
        and 0x102B36
        or 0x183A45

    rows[#rows + 1] =
        compose.Text(
          string.format(
            "item %03d | value %03d | frame %04d",
            index,
            value,
            tick
          ),
          compose.Modifier
          :fillMaxWidth()
          :background(background)
        )
  end

  return compose.Column({
      compose.Text("SCROLL + RECOMPOSE STRESS"),

      compose.Text(
        "frame "
        .. tick
        .. " | offset "
        .. scrollState:getValue()
        .. "/"
        .. scrollState.maxValue
        .. " | "
        .. mode
      ),

      compose.Column(
        rows,
        compose.Modifier
        :fillMaxWidth()
        :weight(1)
        :verticalScroll(scrollState)
        :border()
      ),

      compose.Text(
        "Wheel to scroll | Q to exit"
      ),
    },
    compose.Modifier
    :fillMaxWidth()
    :fillMaxHeight()
  )
end)
