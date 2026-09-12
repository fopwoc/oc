local compose = require("lib.compose.init")
local components = require("lib.components.init")
local configLoader = require("lib.config.loader")
local storage = require("lib.storage.store")
local clock = require("lib.utils.clock")
local format = require("lib.utils.format")
local telemetry = require("lib.telemetry.sender")

local powerAdapter = require("lib.gt.lapotronic")
local powerAnalytics = require("lib.power_monitor.analytics")
local settings = require("app.power_monitor.settings")

local colors = components.ColorStyle()
local cells = components.GridCells(colors)

-- Opened after configuration is validated; read by detail() for status.
local historyStore

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

local function energyPairs(metric)
  if not metric.stored
      or not metric.capacity
  then
    return "--/--", "--/-- (--)"
  end

  local exact = format.energyExact(metric.stored)
    .. "/"
    .. format.energyExact(metric.capacity)

  local scaled = format.energy(metric.stored)
    .. "/"
    .. format.energy(metric.capacity)
    .. " ("
    .. percent(metric.fill)
    .. ")"

  return exact, scaled
end

local function detail(context, model)
  local window = compose.remember(15 * 60)
  local metric = model:snapshot(clock.now())
  local color = stateColor(metric)
  local exactEnergy, scaledEnergy =
      energyPairs(metric)
  local values = model:chart(window.value, clock.now())

  if #values == 0 then
    values = {metric.fill or 0}
  end

  local rows = {
    {"SIGNAL", "NOW", "5M", "24H"},
    {"Input", format.powerRate(metric.input), "--", format.powerRate(metric.averageInput24h)},
    {"Output", format.powerRate(metric.output), "--", format.powerRate(metric.averageOutput24h)},
    {"Net", format.powerRate(metric.net), format.powerRate(metric.net5m), format.powerRate(metric.averageNet24h)},
    {"Minimum fill", "--", "--", percent(metric.minimumFill24h)},
    {"Empty ETA", metric.etaSeconds and format.duration(metric.etaSeconds) or "--", "--", "--"},
  }

  local chartWindowLabels = {
    {label = "15m", value = 15 * 60},
    {label = "1h", value = 60 * 60},
    {label = "6h", value = 6 * 60 * 60},
    {label = "24h", value = 24 * 60 * 60},
  }
  local windowButtons = {}

  for _, option in ipairs(chartWindowLabels) do
    local label = option.label
    local value = option.value

    windowButtons[#windowButtons + 1] =
        components.Button(
          label,
          function()
            window.value = value
          end,
          compose.Modifier:foreground(
            window.value == value
              and colors.primary
              or colors.muted
          )
        )
  end

  return compose.Column({
    components.Section("POWER STATUS", {
      compose.Row({
        compose.Text(
          stateLabel(metric),
          compose.Modifier:foreground(color)
        ),
        compose.Spacer(compose.Modifier:weight(1)),
        compose.Text(
          "FILL " .. percent(metric.fill),
          compose.Modifier:foreground(color)
        ),
      }),
      compose.Row({
        compose.Text(
          scaledEnergy,
          compose.Modifier:foreground(colors.text)
        ),
        compose.Spacer(compose.Modifier:weight(1)),
        compose.Text(
          exactEnergy,
          compose.Modifier:foreground(colors.muted)
        ),
      }),
      compose.Text(
        metric.error or "sustainable power flow",
        compose.Modifier:foreground(colors.muted)
      ),
      historyStore.lastError
        and compose.Text(
          "HISTORY " .. tostring(historyStore.lastError),
          compose.Modifier:foreground(colors.warning)
        )
        or nil,
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("POWER FLOW", {
      components.Grid({
        rows = rows,
        columns = {
          {weight = 2, align = "left"},
          {weight = 2, align = "right"},
          {weight = 2, align = "right"},
          {weight = 2, align = "right"},
        },
        appearance = "alternating",
        horizontalCellPadding = 1,
        cell = cells.render,
        modifier = compose.Modifier:fillMaxWidth(),
      }),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("HISTORY", {
      components.AreaChart({
        values = values,
        title = compose.Row(windowButtons),
        height = 5,
        fillColor = color,
        emptyColor = colors.surfaceVariant,
        modifier = compose.Modifier:fillMaxWidth(),
        footer = compose.Text(
          "draining "
            .. format.duration(metric.drainingSeconds)
            .. " · depleting "
            .. format.duration(metric.depletingSeconds),
          compose.Modifier:foreground(colors.muted)
        ),
      }),
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

historyStore = storage.open(
  "power-monitor",
  "history",
  {
    version = 4,
    default = function()
      return {
        buckets = {},
        timeline = {
          version = 1,
          tiers = {},
        },
      }
    end,
  }
)
local historyState = historyStore:load()
local model = powerAnalytics.create(
  config,
  {
    settings = settings,
    history = historyState,
    persist = function(state)
      return historyStore:trySave(state)
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
        local sampledAt = clock.now()

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

  return components.Entrypoint({
    title = config.name,
    service = "GTNH POWER",
    bottomBarActions = function(context)
      return components.TelemetryStatus(sender, context)
    end,
    content = function(context)
      local _ = revision.value
      return detail(context, model)
    end,
  })
end)
