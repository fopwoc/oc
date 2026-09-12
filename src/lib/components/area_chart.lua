local compose = require("lib.compose.init")
local progress = require("lib.components.progress")
local series = require("lib.utils.series")

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

  local gap =
      options.gap or 0

  local values =
      series.resample(
        options.values,
        options.columns or 56
      )

  local children = {}

  for _, value in ipairs(values) do
    local modifier = compose.Modifier

    if not options.barWidth then
      modifier = modifier:weight(1)
    end

    children[#children + 1] =
        progress.Progress({
          value = value,
          orientation = "vertical",
          width = options.barWidth,
          height = height,
          fillColor = options.fillColor,
          emptyColor = options.emptyColor,
          modifier = modifier,
        })

    if gap > 0 then
      children[#children + 1] =
          compose.Spacer(
            compose.Modifier:width(gap)
          )
    end
  end

  local chart = compose.Row(
    children,
    options.chartModifier
    or compose.Modifier:fillMaxWidth()
  )

  if not options.title
      and not options.footer
  then
    return compose.Row(
      children,
      options.modifier
      or options.chartModifier
      or compose.Modifier:fillMaxWidth()
    )
  end

  local content = {}

  if options.title then
    content[#content + 1] = options.title
  end

  content[#content + 1] = chart

  if options.footer then
    content[#content + 1] = options.footer
  end

  return compose.Column(
    content,
    options.modifier
    or compose.Modifier:fillMaxWidth()
  )
end

return areaChart
