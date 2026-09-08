local compose = require("lib.compose.init")
local progress = require("lib.components.progress")

local barChart = {}

local function resolveRow(row, index)
  if type(row) == "number" then
    return tostring(index), row, nil
  end

  assert(
    type(row) == "table",
    "BarChart rows must be numbers or tables"
  )

  return
      tostring(row.label or index),
      row.value,
      row.color
end

function barChart.BarChart(options)
  assert(
    type(options) == "table",
    "BarChart requires an options table"
  )

  assert(
    type(options.rows) == "table"
      and #options.rows > 0,
    "BarChart requires non-empty rows"
  )

  local labelWidth =
      options.labelWidth or 10

  local showLabels =
      options.showLabels ~= false

  local children = {}

  for index, row in ipairs(options.rows) do
    local label,
    value,
    color =
        resolveRow(row, index)

    children[#children + 1] =
        compose.Row({
            compose.Text(
              label,
              compose.Modifier:width(labelWidth)
            ),

            compose.Spacer(
              compose.Modifier:width(1)
            ),

            progress.Progress({
              value = value,
              label = showLabels,
              labelContrast = options.labelContrast,
              labelColor = options.labelColor,
              fillColor = color or options.fillColor,
              emptyColor = options.emptyColor,
              height = options.barHeight,
              modifier = compose.Modifier:weight(1),
            }),
          },
          compose.Modifier:fillMaxWidth()
        )
  end

  return compose.Column(
    children,
    options.modifier
    or compose.Modifier
  )
end

return barChart
