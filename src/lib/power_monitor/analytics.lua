local ringBuffer = require("lib.collections.ring_buffer")
local decimal = require("lib.utils.decimal")
local clock = require("lib.utils.clock")
local timeline = require("lib.timeline")

local analytics = {}

local TICKS_PER_SECOND = 20
local MINUTE = 60
local DAY = 24 * 60 * MINUTE
local DEFAULT_RAW_CAPACITY = 180
local DEFAULT_HISTORY_CAPACITY = 1440

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

local FILL_PRECISION = 4
local RATE_PRECISION = 1

local function roundTo(value, precision)
  local factor = 10 ^ precision

  return math.floor(value * factor + 0.5) / factor
end

local function validBucket(bucket)
  return type(bucket) == "table"
    and type(bucket.time) == "number"
    and type(bucket.fill) == "number"
    and type(bucket.fillMin) == "number"
    and type(bucket.input) == "number"
    and type(bucket.output) == "number"
end

-- Persisted minute buckets are positional and rounded: a day of named,
-- full-precision buckets did not fit next to the code on a 1 MB OC disk.
local function packBucket(bucket)
  return {
    math.floor(bucket.time),
    roundTo(bucket.fill, FILL_PRECISION),
    roundTo(bucket.fillMin, FILL_PRECISION),
    roundTo(bucket.input, RATE_PRECISION),
    roundTo(bucket.output, RATE_PRECISION),
    math.floor(bucket.drainingSeconds + 0.5),
    math.floor(bucket.depletingSeconds + 0.5),
  }
end

local function packBuckets(buckets)
  local result = {}

  for index, bucket in ipairs(buckets) do
    result[index] = packBucket(bucket)
  end

  return result
end

local function unpackBucket(bucket)
  if type(bucket) ~= "table" or bucket.time ~= nil then
    return bucket
  end

  return {
    time = bucket[1],
    fill = bucket[2],
    fillMin = bucket[3],
    input = bucket[4],
    output = bucket[5],
    drainingSeconds = bucket[6],
    depletingSeconds = bucket[7],
  }
end

local function normalizeBuckets(value, capacity, cutoff)
  local result = {}

  if type(value) ~= "table" then
    return result
  end

  for _, bucket in ipairs(value) do
    bucket = unpackBucket(bucket)

    if validBucket(bucket)
        and bucket.time >= cutoff
    then
      result[#result + 1] = {
        time = bucket.time,
        fill = clamp(bucket.fill, 0, 1),
        fillMin = clamp(bucket.fillMin, 0, 1),
        input = bucket.input,
        output = bucket.output,
        drainingSeconds =
            math.max(0, bucket.drainingSeconds or 0),
        depletingSeconds =
            math.max(0, bucket.depletingSeconds or 0),
      }
    end
  end

  while #result > capacity do
    table.remove(result, 1)
  end

  return result
end

local function newBucket(time)
  return {
    time = math.floor(time / MINUTE) * MINUTE,
    count = 0,
    fillSum = 0,
    fillMin = 1,
    inputSum = 0,
    outputSum = 0,
    drainingSeconds = 0,
    depletingSeconds = 0,
  }
end

local function finalizeBucket(bucket)
  if not bucket or bucket.count == 0 then
    return nil
  end

  return {
    time = bucket.time,
    fill = bucket.fillSum / bucket.count,
    fillMin = bucket.fillMin,
    input = bucket.inputSum / bucket.count,
    output = bucket.outputSum / bucket.count,
    drainingSeconds = bucket.drainingSeconds,
    depletingSeconds = bucket.depletingSeconds,
  }
end

local function addDuration(metric, time)
  if not metric.lastTime
      or not metric.bucket
      or time <= metric.lastTime
  then
    return
  end

  local elapsed = math.min(time - metric.lastTime, MINUTE)

  if metric.state == "DRAINING" then
    metric.bucket.drainingSeconds =
        metric.bucket.drainingSeconds + elapsed
  elseif metric.state == "DEPLETING" then
    metric.bucket.depletingSeconds =
        metric.bucket.depletingSeconds + elapsed
  end
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

local function historyValues(metric, includeCurrent)
  local result = {}

  for _, bucket in ipairs(metric.buckets) do
    result[#result + 1] = bucket
  end

  if includeCurrent then
    local finalized = finalizeBucket(metric.bucket)

    if finalized then
      result[#result + 1] = finalized
    end
  end

  return result
end

local function historyStats(metric)
  local buckets = historyValues(metric, true)

  if #buckets == 0 then
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

  local fill = 0
  local input = 0
  local output = 0
  local minimum = 1
  local draining = 0
  local depleting = 0

  for _, bucket in ipairs(buckets) do
    fill = fill + bucket.fill
    input = input + bucket.input
    output = output + bucket.output
    minimum = math.min(minimum, bucket.fillMin)
    draining = draining + bucket.drainingSeconds
    depleting = depleting + bucket.depletingSeconds
  end

  return {
    count = #buckets,
    averageFill = fill / #buckets,
    averageInput = input / #buckets,
    averageOutput = output / #buckets,
    averageNet = (input - output) / #buckets,
    minimumFill = minimum,
    drainingSeconds = draining,
    depletingSeconds = depleting,
  }
end

local function chartValues(metric, now, window)
  return metric.timeline:values(window, now)
end

local function snapshot(metric, now)
  local current = metric.current
  local stats = historyStats(metric)
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
  local historyCapacity = positive(
    settings.historyCapacity,
    DEFAULT_HISTORY_CAPACITY
  )
  local now = options.now or clock.now
  local persisted = options.history or {}
  local metric = {
    id = config.id,
    name = config.name,
    live = ringBuffer.create(rawCapacity),
    buckets = normalizeBuckets(
      persisted.buckets,
      historyCapacity,
      now() - DAY
    ),
    bucket = nil,
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
      reducer = "last",
      precision = FILL_PRECISION,
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
    buckets = packBuckets(metric.buckets),
    timeline = metric.timeline:export(),
  }

  local function persist()
    historyState.buckets = packBuckets(metric.buckets)
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

    addDuration(metric, time)

    local shouldPersist = false

    if not metric.bucket
        or time >= metric.bucket.time + MINUTE
    then
      local finalized = finalizeBucket(metric.bucket)

      if finalized then
        metric.buckets[#metric.buckets + 1] = finalized
      end

      metric.bucket = newBucket(time)

      local cutoff = metric.bucket.time - DAY

      while #metric.buckets > 0
          and metric.buckets[1].time < cutoff
      do
        table.remove(metric.buckets, 1)
      end

      -- Disk writes are slow and block the event loop on OC, so finished
      -- minutes are flushed in batches instead of one at a time.
      if not metric.lastPersist
          or time - metric.lastPersist
            >= metric.options.persistIntervalSeconds
      then
        shouldPersist = true
      end
    end

    local powerSample = {
      time = time,
      fill = clamp(fill, 0, 1),
      stored = reading.stored,
      capacity = reading.capacity,
      input = input,
      output = output,
      net = input - output,
    }

    metric.timeline:commit(
      time,
      powerSample.fill
    )

    metric.current = powerSample
    metric.live:push(powerSample)
    metric.offline = false
    metric.error = nil
    metric.bucket.count = metric.bucket.count + 1
    metric.bucket.fillSum = metric.bucket.fillSum + powerSample.fill
    metric.bucket.fillMin = math.min(
      metric.bucket.fillMin,
      powerSample.fill
    )
    metric.bucket.inputSum = metric.bucket.inputSum + input
    metric.bucket.outputSum = metric.bucket.outputSum + output
    metric.lastTime = time

    if shouldPersist then
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

  function instance:historyStats()
    return historyStats(metric)
  end

  return instance
end

return analytics
