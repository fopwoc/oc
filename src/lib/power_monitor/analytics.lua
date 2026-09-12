local ringBuffer = require("lib.collections.ring_buffer")
local decimal = require("lib.utils.decimal")
local clock = require("lib.utils.clock")
local timeline = require("lib.timeline")

local analytics = {}

local TICKS_PER_SECOND = 20
local MINUTE = 60
local DAY = 24 * 60 * MINUTE
local DEFAULT_RAW_CAPACITY = 180

-- Every sample is committed to one shared timeline as a record; the
-- timeline downsamples it into the chart tiers and the 24h aggregates.
local HISTORY_FIELDS = {
  fill = {aggregates = {"last", "sum", "min", "max"}, precision = 4},
  -- Minute-average EU/t is displayed with three significant digits, so
  -- whole numbers are plenty.
  input = {aggregates = {"sum"}, precision = 0},
  output = {aggregates = {"sum"}, precision = 0},
  draining = {aggregates = {"sum"}, precision = 0},
  depleting = {aggregates = {"sum"}, precision = 0},
}

local function clamp(value, minimum, maximum)
  return math.max(
    minimum,
    math.min(maximum, value)
  )
end

local function positive(value, fallback)
  if type(value) == "number" and value > 0 then
    return value
  end

  return fallback
end

local function average(metric, now, window, field)
  local cutoff = now - window
  local total = 0
  local count = 0

  for _, sample in metric.live:iter() do
    if sample.time >= cutoff then
      total = total + sample[field]
      count = count + 1
    end
  end

  if count == 0 then
    return nil
  end

  return total / count
end

local function estimateState(metric, now, options)
  if not metric.current then
    return "NORMAL", nil
  end

  local fill = metric.current.fill

  if fill ~= nil
      and fill <= options.emptyThreshold
  then
    return "EMPTY", nil
  end

  if metric.live:size() < 2 then
    return metric.state or "NORMAL", nil
  end

  local netShort = average(
    metric,
    now,
    options.shortWindow,
    "net"
  )

  if netShort == nil
      or netShort >= -options.drainEpsilon
  then
    return "NORMAL", nil
  end

  local stored = decimal.approx(metric.current.stored)
  local etaSeconds

  if stored
      and stored > 0
  then
    etaSeconds = stored
        / (-netShort * TICKS_PER_SECOND)
  end

  local danger = options.depletingEtaSeconds
  local recovery = options.depletingRecoveryEtaSeconds

  if metric.state == "DEPLETING"
      and etaSeconds
      and etaSeconds <= recovery
  then
    return "DEPLETING", etaSeconds
  end

  if etaSeconds
      and etaSeconds <= danger
  then
    return "DEPLETING", etaSeconds
  end

  return "DRAINING", etaSeconds
end

-- Seconds spent in DRAINING / DEPLETING since the previous sample; the
-- gap is capped so a long pause does not count as a long outage.
local function stateDurations(metric, time)
  if not metric.lastTime or time <= metric.lastTime then
    return 0, 0
  end

  local elapsed = math.min(time - metric.lastTime, MINUTE)

  if metric.state == "DRAINING" then
    return elapsed, 0
  elseif metric.state == "DEPLETING" then
    return 0, elapsed
  end

  return 0, 0
end

local function historyStats(metric, now)
  local fill = metric.timeline:aggregate(DAY, now, "fill")

  if not fill then
    return {
      count = 0,
      averageFill = nil,
      averageInput = nil,
      averageOutput = nil,
      averageNet = nil,
      minimumFill = nil,
      drainingSeconds = 0,
      depletingSeconds = 0,
    }
  end

  local input = metric.timeline:aggregate(DAY, now, "input")
  local output = metric.timeline:aggregate(DAY, now, "output")
  local draining = metric.timeline:aggregate(DAY, now, "draining")
  local depleting = metric.timeline:aggregate(DAY, now, "depleting")

  return {
    count = fill.buckets,
    averageFill = fill.average,
    averageInput = input.average,
    averageOutput = output.average,
    averageNet = input.average - output.average,
    minimumFill = fill.minimum,
    drainingSeconds = draining.sum,
    depletingSeconds = depleting.sum,
  }
end

local function chartValues(metric, now, window)
  return metric.timeline:values(window, now, "fill")
end

local function snapshot(metric, now)
  local current = metric.current
  local stats = historyStats(metric, now)
  local netShort = current
      and average(metric, now, metric.options.shortWindow, "net")
  local netMedium = current
      and average(metric, now, metric.options.mediumWindow, "net")
  local state, etaSeconds =
      estimateState(metric, now, metric.options)

  metric.state = state

  return {
    type = "power_monitor",
    id = metric.id,
    name = metric.name,
    state = state,
    offline = metric.offline,
    error = metric.error,
    stored = current and current.stored,
    capacity = current and current.capacity,
    fill = current and current.fill,
    input = current and current.input,
    output = current and current.output,
    net = current and current.net,
    net30s = netShort,
    net5m = netMedium,
    etaSeconds = etaSeconds,
    averageFill24h = stats.averageFill,
    averageInput24h = stats.averageInput,
    averageOutput24h = stats.averageOutput,
    averageNet24h = stats.averageNet,
    minimumFill24h = stats.minimumFill,
    drainingSeconds = stats.drainingSeconds,
    depletingSeconds = stats.depletingSeconds,
    historyBuckets = stats.count,
  }
end

function analytics.create(config, options)
  config = config or {}
  options = options or {}

  assert(
    type(config.id) == "string"
      and config.id ~= "",
    "Power Monitor requires an id"
  )

  assert(
    type(config.name) == "string"
      and config.name ~= "",
    "Power Monitor requires a name"
  )

  local settings = options.settings or {}
  local rawCapacity = positive(
    settings.liveHistoryCapacity,
    DEFAULT_RAW_CAPACITY
  )
  local now = options.now or clock.now
  local persisted = options.history or {}
  local metric = {
    id = config.id,
    name = config.name,
    live = ringBuffer.create(rawCapacity),
    current = nil,
    state = "NORMAL",
    offline = true,
    error = "waiting for first sample",
    lastTime = nil,
    timeline = timeline.create({
      sampleSeconds = positive(
        settings.sampleSeconds,
        5
      ),
      fields = HISTORY_FIELDS,
      state = persisted.timeline,
    }),
    options = {
      shortWindow = positive(settings.shortWindow, 30),
      mediumWindow = positive(settings.mediumWindow, 300),
      sampleSeconds = positive(settings.sampleSeconds, 5),
      drainEpsilon = positive(settings.drainEpsilon, 1),
      depletingEtaSeconds = positive(
        settings.depletingEtaSeconds,
        15 * MINUTE
      ),
      depletingRecoveryEtaSeconds = positive(
        settings.depletingRecoveryEtaSeconds,
        20 * MINUTE
      ),
      persistIntervalSeconds = positive(
        settings.persistIntervalSeconds,
        5 * MINUTE
      ),
      emptyThreshold = clamp(
        settings.emptyThreshold or 0,
        0,
        1
      ),
    },
  }
  local historyState = {
    timeline = metric.timeline:export(),
  }

  local function persist()
    historyState.timeline = metric.timeline:export()

    if options.persist then
      local called, saved, errorMessage =
          pcall(options.persist, historyState)

      if not called then
        return false, saved
      end

      if saved == false then
        return false, errorMessage
      end
    end

    return true
  end

  local function sample(reading, time)
    assert(
      type(reading) == "table",
      "Power sample must be a table"
    )

    time = time or now()

    local fill = decimal.ratio(
      reading.stored,
      reading.capacity
    )

    assert(
      fill ~= nil,
      "Power sample requires valid stored and capacity strings"
    )

    local input = tonumber(reading.input)
    local output = tonumber(reading.output)

    assert(
      input ~= nil and output ~= nil,
      "Power sample requires numeric input and output"
    )

    local drainingSeconds, depletingSeconds =
        stateDurations(metric, time)

    local powerSample = {
      time = time,
      fill = clamp(fill, 0, 1),
      stored = reading.stored,
      capacity = reading.capacity,
      input = input,
      output = output,
      net = input - output,
    }

    metric.timeline:commit(time, {
      fill = powerSample.fill,
      input = input,
      output = output,
      draining = drainingSeconds,
      depleting = depletingSeconds,
    })

    metric.current = powerSample
    metric.live:push(powerSample)
    metric.offline = false
    metric.error = nil
    metric.lastTime = time

    -- Disk writes are slow and block the event loop on OC, so history is
    -- flushed in batches instead of on every sample.
    if not metric.lastPersist
        or time - metric.lastPersist
          >= metric.options.persistIntervalSeconds
    then
      metric.lastPersist = time
      persist()
    end

    local currentState = metric.state
    local nextState = estimateState(
      metric,
      time,
      metric.options
    )

    metric.state = nextState

    return currentState ~= nextState
  end

  local instance = {}

  function instance:sample(reading, time)
    return sample(reading, time)
  end

  -- Writes the current history immediately, bypassing the batching interval.
  function instance:flush()
    return persist()
  end

  function instance:fail(errorMessage)
    metric.offline = true
    metric.error = tostring(errorMessage or "storage unavailable")
  end

  function instance:snapshot(time)
    return snapshot(metric, time or now())
  end

  function instance:telemetry(time)
    local result = self:snapshot(time)

    result.historyBuckets = nil
    result.drainingSeconds = nil
    result.depletingSeconds = nil

    return result
  end

  function instance:chart(window, time)
    return chartValues(
      metric,
      time or now(),
      window
    )
  end

  function instance:historyStats(time)
    return historyStats(metric, time or now())
  end

  return instance
end

return analytics
