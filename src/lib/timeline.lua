local ringBuffer = require("lib.collections.ring_buffer")

-- Tiered time series. An application commits one record per sample at its
-- own cadence; the timeline downsamples it into fixed-step buckets for each
-- configured window and persists the result compactly.
--
-- A record is a number (field "value") or a table of named numbers. Every
-- field keeps the aggregates listed for it: last, sum, min, max.
local timeline = {}

local DEFAULT_RESOLUTIONS = {
  {window = 15 * 60, step = 5},
  {window = 60 * 60, step = 60},
  {window = 6 * 60 * 60, step = 5 * 60},
  {window = 12 * 60 * 60, step = 10 * 60},
  {window = 24 * 60 * 60, step = 15 * 60},
}

local DEFAULT_AGGREGATES = {"last", "sum", "min", "max"}
local EXPORT_VERSION = 2

local function positive(value, fallback)
  value = tonumber(value)

  if value and value > 0 then
    return value
  end

  return fallback
end

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

-- Field specifications

local function lookup(value, name, fallback)
  if type(value) == "table" then
    local specific = value[name]

    if specific ~= nil then
      return specific
    end

    return fallback
  end

  if value ~= nil then
    return value
  end

  return fallback
end

local function fieldSpec(name, options, declared)
  declared = type(declared) == "table" and declared or {}

  local aggregates =
      declared.aggregates
      or lookup(options.aggregates, name, DEFAULT_AGGREGATES)

  local keeps = {}

  for _, aggregate in ipairs(aggregates) do
    assert(
      aggregate == "last"
        or aggregate == "sum"
        or aggregate == "min"
        or aggregate == "max",
      "Timeline aggregate must be last, sum, min, or max: " .. tostring(aggregate)
    )

    keeps[aggregate] = true
  end

  local reducer =
      declared.reducer
      or lookup(options.reducers, name, nil)
      or options.reducer

  if reducer == nil then
    reducer = keeps.last and "last" or "average"
  end

  return {
    name = name,
    aggregates = aggregates,
    keeps = keeps,
    reducer = reducer,
    precision =
        declared.precision
        or lookup(options.precision, name, nil),
  }
end

local function declareFields(instance, names)
  local fields = {}
  local byName = {}

  for _, entry in ipairs(names) do
    local name = entry
    local declared = nil

    if type(entry) == "table" then
      name = entry.name
      declared = entry
    end

    assert(
      type(name) == "string" and name ~= "",
      "Timeline field name must be a non-empty string"
    )

    local spec = fieldSpec(name, instance.options, declared)

    fields[#fields + 1] = spec
    byName[name] = spec
  end

  assert(#fields > 0, "Timeline requires at least one field")

  instance.fields = fields
  instance.fieldsByName = byName
end

local function fieldsFromOptions(instance, options)
  local declared = options.fields

  if type(declared) ~= "table" then
    return false
  end

  local names = {}

  if #declared > 0 then
    for _, entry in ipairs(declared) do
      names[#names + 1] = entry
    end
  else
    for name, spec in pairs(declared) do
      local entry = {name = name}

      if type(spec) == "table" then
        entry.aggregates = spec.aggregates
        entry.reducer = spec.reducer
        entry.precision = spec.precision
      end

      names[#names + 1] = entry
    end

    table.sort(names, function(left, right)
      return left.name < right.name
    end)
  end

  declareFields(instance, names)

  return true
end

local function fieldsFromRecord(instance, record)
  local names = {}

  for name in pairs(record) do
    names[#names + 1] = name
  end

  table.sort(names)
  declareFields(instance, names)
end

-- Records and buckets

local function normalizeRecord(instance, value)
  if type(value) == "number" then
    value = {value = value}
  end

  assert(
    type(value) == "table",
    "Timeline value must be a number or a table of numbers"
  )

  if not instance.fields then
    fieldsFromRecord(instance, value)
  end

  local record = {}

  for _, field in ipairs(instance.fields) do
    local number = tonumber(value[field.name])

    assert(
      number ~= nil,
      "Timeline record requires numeric field: " .. field.name
    )

    record[field.name] = number
  end

  return record
end

local function newBucket(instance, time, record)
  local bucket = {
    time = time,
    count = 1,
    values = {},
  }

  for _, field in ipairs(instance.fields) do
    local value = record[field.name]

    bucket.values[field.name] = {
      last = field.keeps.last and value or nil,
      sum = field.keeps.sum and value or nil,
      min = field.keeps.min and value or nil,
      max = field.keeps.max and value or nil,
    }
  end

  return bucket
end

local function addRecord(instance, bucket, record)
  bucket.count = bucket.count + 1

  for _, field in ipairs(instance.fields) do
    local value = record[field.name]
    local slot = bucket.values[field.name]

    if field.keeps.last then
      slot.last = value
    end

    if field.keeps.sum then
      slot.sum = slot.sum + value
    end

    if field.keeps.min then
      slot.min = math.min(slot.min, value)
    end

    if field.keeps.max then
      slot.max = math.max(slot.max, value)
    end
  end
end

local function bucketValue(bucket, field, reducer)
  local slot = bucket.values[field.name]

  reducer = reducer or field.reducer

  if type(reducer) == "function" then
    return reducer(slot, bucket)
  end

  if reducer == "average" then
    assert(slot.sum ~= nil, "Timeline field does not keep sum: " .. field.name)
    return slot.sum / bucket.count
  end

  if reducer == "sum" then
    assert(slot.sum ~= nil, "Timeline field does not keep sum: " .. field.name)
    return slot.sum
  end

  if reducer == "minimum" then
    assert(slot.min ~= nil, "Timeline field does not keep min: " .. field.name)
    return slot.min
  end

  if reducer == "maximum" then
    assert(slot.max ~= nil, "Timeline field does not keep max: " .. field.name)
    return slot.max
  end

  assert(slot.last ~= nil, "Timeline field does not keep last: " .. field.name)
  return slot.last
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

local function resolveField(instance, name)
  assert(instance.fields, "Timeline has no data yet")

  if name == nil then
    return instance.fields[1]
  end

  local field = instance.fieldsByName[name]

  assert(field, "Timeline has no field: " .. tostring(name))

  return field
end

-- Persistence: positional buckets, one row per bucket, field aggregates in
-- declaration order. Field names dominate serialized size otherwise.

local function packBucket(instance, bucket)
  local row = {
    math.floor(bucket.time),
    bucket.count,
  }

  for _, field in ipairs(instance.fields) do
    local slot = bucket.values[field.name]

    for _, aggregate in ipairs(field.aggregates) do
      row[#row + 1] = roundTo(slot[aggregate], field.precision)
    end
  end

  return row
end

local function unpackBucket(instance, row, layout)
  if type(row) ~= "table"
      or type(row[1]) ~= "number"
      or type(row[2]) ~= "number"
      or row[2] <= 0
  then
    return nil
  end

  local bucket = {
    time = row[1],
    count = row[2],
    values = {},
  }

  local index = 3
  local decoded = {}

  for _, saved in ipairs(layout) do
    local slot = {}

    for _, aggregate in ipairs(saved.aggregates) do
      slot[aggregate] = tonumber(row[index])
      index = index + 1
    end

    decoded[saved.name] = slot
  end

  for _, field in ipairs(instance.fields) do
    local saved = decoded[field.name]

    if not saved then
      return nil
    end

    local slot = {}

    for aggregate in pairs(field.keeps) do
      local value = saved[aggregate]

      -- A missing aggregate is rebuilt from the best available one.
      if value == nil then
        value = saved.last or saved.max or saved.min

        if value == nil and saved.sum ~= nil then
          value = saved.sum / bucket.count
        end
      end

      if value == nil then
        return nil
      end

      slot[aggregate] = value
    end

    bucket.values[field.name] = slot
  end

  return bucket
end

local function exportLayout(instance)
  local layout = {}

  for _, field in ipairs(instance.fields) do
    layout[#layout + 1] = {
      name = field.name,
      aggregates = field.aggregates,
    }
  end

  return layout
end

local function exportTier(instance, tier)
  local buckets = {}

  for _, bucket in tier.buffer:iter() do
    buckets[#buckets + 1] = packBucket(instance, bucket)
  end

  return {
    window = tier.window,
    step = tier.step,
    buckets = buckets,
    current = tier.current
      and packBucket(instance, tier.current)
      or nil,
  }
end

function timeline.create(options)
  options = options or {}

  local configured = resolutions(options)
  local instance = {
    options = options,
    fields = nil,
    fieldsByName = nil,
    tiers = {},
  }

  fieldsFromOptions(instance, options)

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

  function instance:fieldNames()
    local names = {}

    for index, field in ipairs(self.fields or {}) do
      names[index] = field.name
    end

    return names
  end

  function instance:commit(time, value)
    assert(
      type(time) == "number",
      "Timeline timestamp must be a number"
    )

    local record = normalizeRecord(self, value)

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

        tier.current = newBucket(self, start, record)
      else
        addRecord(self, current, record)
      end
    end
  end

  function instance:points(window, now, fieldName)
    assert(
      type(now) == "number",
      "Timeline time must be a number"
    )

    if not self.fields then
      return {}
    end

    local field = resolveField(self, fieldName)

    window = positive(window, 1)
    local tier = tierFor(self, window)
    local cutoff = now - window
    local result = {}

    for _, bucket in ipairs(tierPoints(tier, cutoff)) do
      result[#result + 1] = {
        time = bucket.time,
        value = bucketValue(bucket, field),
      }
    end

    return result
  end

  function instance:values(window, now, fieldName)
    assert(
      type(now) == "number",
      "Timeline time must be a number"
    )

    if not self.fields then
      return {}
    end

    local field = resolveField(self, fieldName)

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
        result[index] = bucketValue(bucket, field)
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

  -- Rolls one field up over a window: sample count, sum, minimum, maximum,
  -- sample-weighted average, and the newest value. Nil when nothing was
  -- committed inside the window.
  function instance:aggregate(window, now, fieldName)
    assert(
      type(now) == "number",
      "Timeline time must be a number"
    )

    if not self.fields then
      return nil
    end

    local field = resolveField(self, fieldName)

    window = positive(window, 1)
    local tier = tierFor(self, window)
    local points = tierPoints(tier, now - window)

    if #points == 0 then
      return nil
    end

    local result = {
      buckets = #points,
      count = 0,
    }

    for _, bucket in ipairs(points) do
      local slot = bucket.values[field.name]

      result.count = result.count + bucket.count

      if slot.sum ~= nil then
        result.sum = (result.sum or 0) + slot.sum
      end

      if slot.min ~= nil then
        result.minimum = math.min(result.minimum or slot.min, slot.min)
      end

      if slot.max ~= nil then
        result.maximum = math.max(result.maximum or slot.max, slot.max)
      end

      if slot.last ~= nil then
        result.last = slot.last
      end
    end

    if result.sum ~= nil and result.count > 0 then
      result.average = result.sum / result.count
    end

    return result
  end

  function instance:export()
    if not self.fields then
      return {
        version = EXPORT_VERSION,
        fields = {},
        tiers = {},
      }
    end

    local result = {
      version = EXPORT_VERSION,
      fields = exportLayout(self),
      tiers = {},
    }

    for _, tier in ipairs(self.tiers) do
      result.tiers[#result.tiers + 1] =
          exportTier(self, tier)
    end

    return result
  end

  function instance:restore(state)
    if type(state) ~= "table"
        or state.version ~= EXPORT_VERSION
        or type(state.fields) ~= "table"
        or type(state.tiers) ~= "table"
        or #state.fields == 0
    then
      return false
    end

    local layout = {}

    for _, saved in ipairs(state.fields) do
      if type(saved) ~= "table"
          or type(saved.name) ~= "string"
          or type(saved.aggregates) ~= "table"
      then
        return false
      end

      layout[#layout + 1] = saved
    end

    if not self.fields then
      local names = {}

      for _, saved in ipairs(layout) do
        names[#names + 1] = saved.name
      end

      declareFields(self, names)
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

        for _, row in ipairs(saved.buckets or {}) do
          local bucket = unpackBucket(self, row, layout)

          if bucket then
            tier.buffer:push(bucket)
          end
        end

        tier.current = unpackBucket(self, saved.current, layout)
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
