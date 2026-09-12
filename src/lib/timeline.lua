local ringBuffer = require("lib.collections.ring_buffer")

local timeline = {}

local DEFAULT_RESOLUTIONS = {
  {window = 15 * 60, step = 5},
  {window = 60 * 60, step = 60},
  {window = 6 * 60 * 60, step = 5 * 60},
  {window = 12 * 60 * 60, step = 10 * 60},
  {window = 24 * 60 * 60, step = 15 * 60},
}

local function positive(value, fallback)
  value = tonumber(value)

  if value and value > 0 then
    return value
  end

  return fallback
end

local function copyResolution(resolution)
  local window = positive(resolution.window, nil)
  local step = positive(resolution.step, nil)

  assert(
    window and step,
    "Timeline resolution requires positive window and step"
  )

  assert(
    window >= step,
    "Timeline resolution window must contain its step"
  )

  return {
    window = window,
    step = step,
  }
end

local function resolutions(options)
  local source =
      options.resolutions
      or DEFAULT_RESOLUTIONS
  local result = {}

  for index, resolution in ipairs(source) do
    if not options.resolutions
        and index == 1
    then
      resolution = {
        window = resolution.window,
        step = positive(
          options.sampleSeconds,
          resolution.step
        ),
      }
    end

    result[#result + 1] =
        copyResolution(resolution)
  end

  assert(
    #result > 0,
    "Timeline requires at least one resolution"
  )

  table.sort(
    result,
    function(left, right)
      return left.window < right.window
    end
  )

  for index = 2, #result do
    assert(
      result[index - 1].window
        < result[index].window,
      "Timeline resolution windows must be unique"
    )
  end

  return result
end

local function newBucket(time, value)
  return {
    time = time,
    value = value,
    sum = value,
    count = 1,
    minimum = value,
    maximum = value,
  }
end

-- Persisted buckets use a positional layout because OpenComputers disks are
-- small and field names dominate the serialized size.
local function roundTo(value, precision)
  if not precision then
    return value
  end

  if precision == 0 then
    -- Keep the integer subtype: "1234" serializes shorter than "1234.0".
    return math.floor(value + 0.5)
  end

  local factor = 10 ^ precision

  return math.floor(value * factor + 0.5) / factor
end

local function packBucket(bucket, precision)
  return {
    math.floor(bucket.time),
    roundTo(bucket.value, precision),
    roundTo(bucket.sum, precision),
    bucket.count,
    roundTo(bucket.minimum, precision),
    roundTo(bucket.maximum, precision),
  }
end

local function normalizeBucket(bucket)
  if type(bucket) ~= "table" then
    return nil
  end

  if bucket.time == nil and type(bucket[1]) == "number" then
    bucket = {
      time = bucket[1],
      value = bucket[2],
      sum = bucket[3],
      count = bucket[4],
      minimum = bucket[5],
      maximum = bucket[6],
    }
  end

  if type(bucket.time) ~= "number"
      or type(bucket.value) ~= "number"
  then
    return nil
  end

  local count = tonumber(bucket.count) or 1
  local sum = tonumber(bucket.sum) or bucket.value

  if count <= 0 then
    return nil
  end

  return {
    time = bucket.time,
    value = bucket.value,
    sum = sum,
    count = count,
    minimum = tonumber(bucket.minimum) or bucket.value,
    maximum = tonumber(bucket.maximum) or bucket.value,
  }
end

local function bucketValue(bucket, reducer)
  if type(reducer) == "function" then
    return reducer(bucket)
  end

  if reducer == "average" then
    return bucket.sum / bucket.count
  end

  if reducer == "minimum" then
    return bucket.minimum
  end

  if reducer == "maximum" then
    return bucket.maximum
  end

  return bucket.value
end

local function addValue(bucket, value)
  bucket.value = value
  bucket.sum = bucket.sum + value
  bucket.count = bucket.count + 1
  bucket.minimum = math.min(bucket.minimum, value)
  bucket.maximum = math.max(bucket.maximum, value)
end

local function tierFor(instance, window)
  for _, tier in ipairs(instance.tiers) do
    if tier.window >= window then
      return tier
    end
  end

  return instance.tiers[#instance.tiers]
end

local function bucketTime(time, step)
  return math.floor(time / step) * step
end

local function tierPoints(tier, cutoff)
  local result = {}

  for _, bucket in tier.buffer:iter() do
    if bucket.time >= cutoff then
      result[#result + 1] = bucket
    end
  end

  if tier.current
      and tier.current.time >= cutoff
  then
    result[#result + 1] = tier.current
  end

  return result
end

local function exportTier(tier, precision)
  local buckets = {}

  for _, bucket in tier.buffer:iter() do
    buckets[#buckets + 1] = packBucket(bucket, precision)
  end

  return {
    window = tier.window,
    step = tier.step,
    buckets = buckets,
    current = tier.current
      and packBucket(tier.current, precision)
      or nil,
  }
end

function timeline.create(options)
  options = options or {}

  local reducer =
      options.reducer
      or "last"
  local configured = resolutions(options)
  local instance = {
    reducer = reducer,
    precision = options.precision,
    tiers = {},
  }

  for _, resolution in ipairs(configured) do
    instance.tiers[#instance.tiers + 1] = {
      window = resolution.window,
      step = resolution.step,
      buffer = ringBuffer.create(
        math.ceil(resolution.window / resolution.step)
          + 2
      ),
      current = nil,
    }
  end

  function instance:commit(time, value)
    assert(
      type(time) == "number",
      "Timeline timestamp must be a number"
    )

    value = tonumber(value)

    assert(
      value ~= nil,
      "Timeline value must be numeric"
    )

    for _, tier in ipairs(self.tiers) do
      local start = bucketTime(time, tier.step)
      local current = tier.current

      if current
          and start < current.time
      then
        -- Samples are expected to arrive in chronological order.
        -- A late sample must not rewrite already finalized history.
      elseif not current
          or start > current.time
      then
        if current then
          tier.buffer:push(current)
        end

        tier.current = newBucket(start, value)
      else
        addValue(current, value)
      end
    end
  end

  function instance:points(window, now)
    assert(
      type(now) == "number",
      "Timeline time must be a number"
    )

    window = positive(window, 1)
    local tier = tierFor(self, window)
    local cutoff = now - window
    local result = {}

    for _, bucket in ipairs(tierPoints(tier, cutoff)) do
      result[#result + 1] = {
        time = bucket.time,
        value = bucketValue(bucket, self.reducer),
      }
    end

    return result
  end

  function instance:values(window, now)
    assert(
      type(now) == "number",
      "Timeline time must be a number"
    )

    window = positive(window, 1)
    local tier = tierFor(self, window)
    local cutoff = now - window
    local count = math.ceil(window / tier.step)
    local result = {}
    local observed = {}
    local points = tierPoints(tier, cutoff)

    if #points == 0 then
      return result
    end

    for index = 1, count do
      result[index] = 0
    end

    for _, bucket in ipairs(points) do
      local age = now - bucket.time
      local index = count - math.floor(age / tier.step)

      index = math.min(count, index)

      if index >= 1
          and index <= count
      then
        result[index] = bucketValue(
          bucket,
          self.reducer
        )
        observed[index] = true
      end
    end

    local lastValue = 0
    local hasValue = false

    for index = 1, count do
      if observed[index] then
        lastValue = result[index]
        hasValue = true
      elseif hasValue then
        result[index] = lastValue
      end
    end

    return result
  end

  function instance:export()
    local result = {
      version = 1,
      tiers = {},
    }

    for _, tier in ipairs(self.tiers) do
      result.tiers[#result.tiers + 1] =
          exportTier(tier, self.precision)
    end

    return result
  end

  function instance:restore(state)
    if type(state) ~= "table"
        or type(state.tiers) ~= "table"
    then
      return false
    end

    local byResolution = {}

    for _, tier in ipairs(self.tiers) do
      byResolution[
        tostring(tier.window)
          .. ":"
          .. tostring(tier.step)
      ] = tier
    end

    for _, saved in ipairs(state.tiers) do
      local tier = byResolution[
        tostring(saved.window)
          .. ":"
          .. tostring(saved.step)
      ]

      if tier then
        tier.buffer:clear()
        tier.current = nil

        for _, bucket in ipairs(saved.buckets or {}) do
          local normalized = normalizeBucket(bucket)

          if normalized then
            tier.buffer:push(normalized)
          end
        end

        tier.current = normalizeBucket(saved.current)
      end
    end

    return true
  end

  if options.state then
    instance:restore(options.state)
  end

  return instance
end

return timeline
