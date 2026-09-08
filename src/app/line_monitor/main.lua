local compose = require("lib.compose.init")
local components = require("lib.components.init")
local configLoader = require("lib.config.loader")
local incidentManager = require("lib.telemetry.incidents.manager")
local format = require("lib.utils.format")
local telemetry = require("lib.telemetry.sender")

local analytics = require("lib.production_line.analytics")
local ae2 = require("lib.ae2.network")

local colors = components.ColorStyle()

local function statusColor(state)
  if state == "HEALTHY"
      or state == "DRAINING"
      or state == "IDLE"
  then
    return colors.good
  end

  if state == "WARMING" then
    return colors.warning
  end

  return colors.bad
end

local function text(value, color, modifier)
  modifier = modifier or compose.Modifier

  return compose.Text(
    tostring(value),
    modifier:foreground(color or colors.text)
  )
end

local cells = components.GridCells(colors)

local function inputGrid(snapshot)
  local rows = {
    {
      "INPUT",
      "ARRIVAL",
      "PROCESS",
      "BACKLOG",
      "STORED",
      "FULL IN",
    },
  }

  for _, input in ipairs(snapshot.inputs) do
    rows[#rows + 1] = {
      input.label,
      cells:colored(format.rate(input.arrivalRate), colors.primary),
      cells:colored(format.rate(input.processingRate), colors.good),
      cells:colored(
        format.rate(input.backlogRate),
        input.backlogRate > 0
          and colors.bad
          or colors.good
      ),
      format.amount(input.amount, input.capacity),
      format.duration(input.fullInSeconds),
    }
  end

  return components.Grid({
    rows = rows,
    columns = {
      {weight = 2, align = "left"},
      {weight = 1, align = "right"},
      {weight = 1, align = "right"},
      {weight = 1, align = "right"},
      {weight = 1, align = "right"},
      {weight = 1, align = "right"},
    },
    appearance = "none",
    cellPadding = 0,
    cell = cells.render,
    modifier = compose.Modifier:fillMaxWidth(),
  })
end

local function outputGrid(snapshot)
  local rows = {
    {
      "OUTPUT",
      "PRODUCED",
      "NET",
      "STORED",
    },
  }

  for _, output in ipairs(snapshot.outputs) do
    local trendColor =
        output.netRate >= 0
        and colors.good
        or colors.warning

    rows[#rows + 1] = {
      output.label,
        cells:colored(
        format.rate(output.productionRate),
        colors.good
      ),
      cells:colored(
        format.rate(output.netRate),
        trendColor
      ),
      format.amount(output.amount, output.capacity),
    }
  end

  return components.Grid({
    rows = rows,
    columns = {
      {weight = 2, align = "left"},
      {weight = 1, align = "right"},
      {weight = 1, align = "right"},
      {weight = 1, align = "right"},
    },
    appearance = "none",
    cellPadding = 0,
    cell = cells.render,
    modifier = compose.Modifier:fillMaxWidth(),
  })
end

local config = configLoader.load({
  directory = "app/line_monitor",
  displayName = "Production line",
  validate = function(value)
    assert(
      type(value.id) == "string"
        and value.id ~= "",
      "Production line configuration requires id"
    )

    assert(
      type(value.name) == "string"
        and value.name ~= "",
      "Production line configuration requires name"
    )
  end,
})
local model = analytics.create(config)
local adapter = ae2.create({address = config.meAddress})
local sender = telemetry.create({
  source = "production_line",
  id = config.id,
})

local incidents = incidentManager.create({
  sender = sender,
})

compose.App(function()
  local revision = compose.remember(0)

  compose.LaunchedEffect(
    "production-line-sampling",
    function()
      local consecutiveFailures = 0
      local lastSync = compose.uptime()

      while true do
        local sampledAt = compose.uptime()
        local inputs, inputError =
            adapter:sample(
              config.inputs,
              analytics.resourceKey
            )

        local outputs, outputError

        if inputs then
          outputs, outputError =
              adapter:sample(
                config.outputs,
                analytics.resourceKey
              )
        end

        local values
        local errorMessage

        if inputs and outputs then
          values = {
            inputs = inputs,
            outputs = outputs,
          }
        else
          errorMessage =
              inputError
              or outputError
        end

        if values then
          model:sample(sampledAt, values)
          consecutiveFailures = 0
          incidents:resolve(
            "ae2-unavailable",
            sampledAt
          )
        else
          model:setOffline(errorMessage)
          consecutiveFailures =
              consecutiveFailures + 1

          if consecutiveFailures
              >= (config.incidentFailureSamples or 3)
          then
            incidents:raise({
              id = "ae2-unavailable",
              title = "AE2 connection lost",
              message = config.name
                .. " cannot read its configured ME network.",
              raisedAt = sampledAt,
            })
          end
        end

        sender:send(
          model:telemetry(sampledAt)
        )

        if sampledAt - lastSync
            >= (config.incidentSyncSeconds or 30)
        then
          incidents:sync()
          lastSync = sampledAt
        end

        revision.value = revision.value + 1

        compose.delay(config.sampleSeconds or 5)
      end
    end
  )

  local _ = revision.value
  local snapshot = model:snapshot(compose.uptime())
  local stateColor = statusColor(snapshot.state)
  local input = snapshot.inputs[1]
  local chartValues =
      input
      and input.chart

  if not chartValues or #chartValues == 0 then
    chartValues = {0}
  end

  local scrollState = compose.rememberScrollState()

  local content = {
    components.Section("STATUS", {
      compose.Row({
        text(snapshot.state, stateColor),
        compose.Spacer(compose.Modifier:weight(1)),
        text(
          "HEALTH " .. format.percent(snapshot.health),
          stateColor
        ),
      }),
      text(snapshot.reason, colors.muted),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("EFFICIENCY", {
      components.Progress({
        value = (snapshot.efficiency or 0) / 100,
        label = format.percent(snapshot.efficiency),
        labelContrast = true,
        fillColor = stateColor,
        emptyColor = colors.surfaceVariant,
        modifier = compose.Modifier:fillMaxWidth(),
      }),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("INPUTS", {
      inputGrid(snapshot),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("OUTPUTS", {
      outputGrid(snapshot),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("HISTORY", {
      components.AreaChart({
        values = chartValues,
        height = 5,
        fillColor = colors.primary,
        emptyColor = colors.surfaceVariant,
        modifier = compose.Modifier:fillMaxWidth(),
      }),
    }),

    compose.Spacer(compose.Modifier:height(1)),

    components.Section("DIAGNOSIS", {
      text(snapshot.state, stateColor),
      text(snapshot.reason, colors.muted),
    }),
  }

  return components.Entrypoint({
    title = config.name,
    service = "AE2 " .. adapter.kind,
    bottomBarActions = function(context)
      return components.TelemetryStatus(sender, context)
    end,
    topBarActions = function()
      return text(
        snapshot.offline
          and "OFFLINE"
          or "MONITORING",
        stateColor
      )
    end,
    content = compose.Column(
      content,
      compose.Modifier
      :fillMaxWidth()
      :fillMaxHeight()
      :verticalScroll(scrollState)
    ),
  })
end)
