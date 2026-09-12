local compose = require("lib.compose.init")
local areaChart = require("lib.components.area_chart")
local button = require("lib.components.button")
local colorStyle = require("lib.components.color_style")

local historyChart = {}

-- Windows match the tiers lib/timeline.lua keeps, so every selection maps
-- onto a downsampled series instead of a resample of the finest one.
historyChart.DEFAULT_WINDOWS = {
  {label = "15m", seconds = 15 * 60},
  {label = "1h", seconds = 60 * 60},
  {label = "6h", seconds = 6 * 60 * 60},
  {label = "24h", seconds = 24 * 60 * 60},
}

-- An area chart with a window selector. `values(seconds)` returns the 0..1
-- series for the chosen window; the selection is remembered per call site.
function historyChart.HistoryChart(options)
  assert(
    type(options) == "table",
    "HistoryChart requires an options table"
  )

  assert(
    type(options.values) == "function",
    "HistoryChart requires a values(windowSeconds) function"
  )

  local windows = options.windows or historyChart.DEFAULT_WINDOWS

  assert(
    type(windows) == "table" and #windows > 0,
    "HistoryChart requires at least one window"
  )

  local colors = colorStyle.current()
  local selected = compose.remember(
    options.initialWindow or windows[1].seconds
  )

  local buttons = {}

  for _, window in ipairs(windows) do
    local seconds = window.seconds

    buttons[#buttons + 1] = button.Button(
      window.label,
      function()
        selected.value = seconds
      end,
      compose.Modifier:foreground(
        selected.value == seconds
          and colors.primary
          or colors.muted
      )
    )
  end

  local values = options.values(selected.value)

  if type(values) ~= "table" or #values == 0 then
    values = {options.emptyValue or 0}
  end

  return areaChart.AreaChart({
    values = values,
    title = compose.Row(buttons),
    footer = options.footer,
    height = options.height,
    columns = options.columns,
    fillColor = options.fillColor or colors.primary,
    emptyColor = options.emptyColor or colors.surfaceVariant,
    modifier = options.modifier or compose.Modifier:fillMaxWidth(),
  })
end

return historyChart
