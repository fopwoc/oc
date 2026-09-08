local compose = require("lib.compose.init")
local progress = require("lib.components.progress")

local areaChart = {}

function areaChart.AreaChart(options)
  assert(
    type(options) == "table",
    "AreaChart requires an options table"
  )

  assert(
    type(options.values) == "table"
      and #options.values > 0,
    "AreaChart requires non-empty values"
  )

  local height =
      options.height or 6

  local barWidth =
      options.barWidth or 1

  local gap =
      options.gap or 0

  local children = {}

  for _, value in ipairs(options.values) do
    children[#children + 1] =
        progress.Progress({
          value = value,
          orientation = "vertical",
          width = barWidth,
          height = height,
          fillColor = options.fillColor,
          emptyColor = options.emptyColor,
        })

    if gap > 0 then
      children[#children + 1] =
          compose.Spacer(
            compose.Modifier:width(gap)
          )
    end
  end

  return compose.Row(
    children,
    options.modifier
    or compose.Modifier
  )
end

return areaChart
