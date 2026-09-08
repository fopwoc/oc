local compose = require("lib.compose.init")
local components = require("lib.components.init")
local configLoader = require("lib.config.loader")
local format = require("lib.utils.format")
local series = require("lib.utils.series")
local telemetry = require("lib.telemetry.sender")

local powerAdapter = require("lib.gt.lapotronic")
local powerAnalytics = require("lib.power_monitor.analytics")
local powerHistory = require("app.power_monitor.history")
local settings = require("app.power_monitor.settings")

local colors = components.ColorStyle()
local cells = components.GridCells(colors)

local function stateColor(metric)
  if metric.offline then
    return colors.bad
  end

  if metric.state == "NORMAL" then
    return colors.good
  end

  if metric.state == "DRAINING" then
    return colors.warning
  end

  return colors.bad
end

local function percent(value)
  if value == nil then
    return "--"
  end

  return tostring(math.floor(value * 100 + 0.5)) .. "%"
end

local function stateLabel(metric)
  if metric.offline then
    return "OFFLINE"
  end

  return metric.state
end

local function detail(context, model)
  local window = compose.remember(15 * 60)
  local metric = model:snapshot(os.time())
  local color = stateColor(metric)
  local values = model:chart(window.value, os.time())

  if #values == 0 then
    values = {metric.fill or 0}
  end

  local rows = {
    {"VALUE", "CURRENT", "24H"},
    {"Fill", percent(metric.fill), percent(metric.averageFill24h)},
    {"Input", format.powerRate(metric.input), format.powerRate(metric.averageInput24h)},
    {"Output", format.powerRate(metric.output), format.powerRate(metric.averageOutput24h)},
    {"Net", format.powerRate(metric.net), format.powerRate(metric.averageNet24h)},
    {"30s net", format.powerRate(metric.net30s), "--"},
    {"5m net", format.powerRate(metric.net5m), "--"},
    {"Minimum fill", "--", percent(metric.minimumFill24h)},
    {"ETA empty", metric.etaSeconds and format.duration(metric.etaSeconds) or "--", "--"},
    {"Stored", format.energy(metric.stored), format.energy(metric.capacity)},
  }

  local chartWindowLabels = {
    {label = "15m", value = 15 * 60},
    {label = "1h", value = 60 * 60},
    {label = "6h", value = 6 * 60 * 60},
    {label = "24h", value = 24 * 60 * 60},
  }
  local windowButtons = {}

  for _, option in ipairs(chartWindowLabels) do
    windowButtons[#windowButtons + 1] =
        components.Button(
          option.label,
          function()
            window.value = option.value
          end,
          compose.Modifier:foreground(
            window.value == option.value
              and colors.primary
              or colors.muted
          )
        )
  end

  return compose.Column({
    components.Section("STATUS", {
      compose.Row({
        compose.Text(
          stateLabel(metric),
          compose.Modifier:foreground(color)
        ),
        compose.Spacer(compose.Modifier:weight(1)),
        compose.Text(
          percent(metric.fill),
          compose.Modifier:foreground(color)
        ),
      }),
      compose.Text(
        metric.error or "sustainable power flow",
        compose.Modifier:foreground(colors.muted)
      ),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("POWER FLOW", {
      components.Grid({
        rows = rows,
        columns = {
          {weight = 2, align = "left"},
          {weight = 2, align = "right"},
          {weight = 2, align = "right"},
        },
        appearance = "alternating",
        cellPadding = 0,
        cell = cells.render,
        modifier = compose.Modifier:fillMaxWidth(),
      }),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("HISTORY", {
      compose.Row(windowButtons),
      components.AreaChart({
        values = series.downsample(values, 56),
        height = 5,
        fillColor = color,
        emptyColor = colors.surfaceVariant,
        modifier = compose.Modifier:fillMaxWidth(),
      }),
      compose.Text(
        "draining "
          .. format.duration(metric.drainingSeconds)
          .. " · depleting "
          .. format.duration(metric.depletingSeconds),
        compose.Modifier:foreground(colors.muted)
      ),
    }),
  })
end

local config = configLoader.load({
  directory = "app/power_monitor",
  displayName = "Power Monitor",
  validate = function(value)
    assert(
      type(value.id) == "string"
        and value.id ~= "",
      "Power Monitor configuration requires id"
    )

    assert(
      type(value.name) == "string"
        and value.name ~= "",
      "Power Monitor configuration requires name"
    )
  end,
})

local address = powerAdapter.firstAddress()

assert(
  address,
  "Power Monitor requires one compatible gt_machine Lapotronic component"
)

local target = {
  id = config.id,
  name = config.name,
  address = address,
}

local historyStore = powerHistory.create()
local historyState = historyStore:load()
local model = powerAnalytics.create(
  config,
  {
    settings = settings,
    history = historyState,
    persist = function(state)
      return historyStore:save(state)
    end,
  }
)
local adapter = powerAdapter.create()
local sender = telemetry.create({
  source = "power_monitor",
  id = config.id,
})

compose.App(function()
  local revision = compose.remember(0)

  compose.LaunchedEffect(
    "power-monitor-sampling",
    function()
      while true do
        local sampledAt = os.time()

        local reading, errorMessage =
            adapter:sample(target)

        if reading then
          model:sample(reading, sampledAt)
        else
          model:fail(errorMessage)
        end

        pcall(
          sender.send,
          sender,
          model:telemetry(sampledAt)
        )

        revision.value = revision.value + 1
        compose.delay(settings.sampleSeconds)
      end
    end
  )

  local _ = revision.value

  return components.Entrypoint({
    title = config.name,
    service = "GTNH POWER",
    bottomBarActions = function(context)
      return components.TelemetryStatus(sender, context)
    end,
    content = function(context)
      return detail(context, model)
    end,
  })
end)
