local timeline = require("lib.timeline")

local analytics = {}

local function clamp(value, minimum, maximum)
  return math.max(
    minimum,
    math.min(maximum, value)
  )
end

local function positiveNumber(value, fallback)
  value = tonumber(value)

  if value and value > 0 then
    return value
  end

  return fallback
end

local function flowBalance(arrivalRate, processingRate, epsilon)
  local largest = math.max(arrivalRate, processingRate)

  if largest <= epsilon then
    return nil
  end

  return clamp(
    math.min(arrivalRate, processingRate) / largest,
    0,
    1
  )
end

local function resourceKey(resource, index)
  if resource.key then
    return tostring(resource.key)
  end

  return tostring(resource.name or resource.id or index)
    .. ":"
    .. tostring(resource.type or "item")
    .. ":"
    .. tostring(resource.damage or 0)
    .. ":"
    .. tostring(resource.nbt or "")
    .. ":"
    .. tostring(resource.fluidLabel or "")
end

local function validateResource(resource, index, group)
  assert(
    type(resource) == "table",
    "Production line " .. group .. " resource must be a table"
  )

  assert(
    resource.name ~= nil
      or resource.id ~= nil,
    "Production line " .. group .. " resource requires name or id"
  )

  local resourceType = resource.type or "item"

  assert(
    resourceType == "item"
      or resourceType == "fluid",
    "Production line resource type must be item or fluid"
  )

  local capacityPolicy =
      resource.capacityPolicy
      or (
        group == "input"
        and "pressure"
        or "expected"
      )

  assert(
    capacityPolicy == "pressure"
      or capacityPolicy == "expected",
    "Production line capacityPolicy must be pressure or expected"
  )

  local capacity = resource.capacity

  assert(
    capacity == nil
      or (
        type(capacity) == "number"
        and capacity > 0
      ),
    "Production line resource capacity must be positive"
  )

  return {
    key = resourceKey(resource, index),
    label = resource.label
      or resource.name
      or tostring(resource.id),
    labelConfigured = type(resource.label) == "string",
    available = nil,
    type = resourceType,
    group = group,
    name = resource.name,
    id = resource.id,
    damage = resource.damage or 0,
    nbt = resource.nbt,
    fluidLabel = resource.fluidLabel,
    capacity = capacity,
    capacityPolicy = capacityPolicy,
    history = nil,
  }
end

local function createResourceList(resources, group, sampleSeconds)
  local result = {}

  for index, resource in ipairs(resources or {}) do
    local item =
        validateResource(resource, index, group)

    item.history = timeline.create({
      sampleSeconds = sampleSeconds,
    })
    result[#result + 1] = item
  end

  return result
end

local function windowPoints(resource, now, window)
  return resource.history:points(window, now)
end

local function rateStats(resource, now, window)
  local points =
      windowPoints(resource, now, window)

  if #points < 2 then
    return {
      valid = false,
      samples = #points,
      arrivalRate = 0,
      processingRate = 0,
      netRate = 0,
    }
  end

  local first = points[1]
  local last = points[#points]
  local elapsed = last.time - first.time

  if elapsed <= 0 then
    return {
      valid = false,
      samples = #points,
      arrivalRate = 0,
      processingRate = 0,
      netRate = 0,
    }
  end

  local arrivals = 0
  local processing = 0

  for index = 2, #points do
    local delta =
        points[index].value
        - points[index - 1].value

    if delta > 0 then
      arrivals = arrivals + delta
    elseif delta < 0 then
      processing = processing - delta
    end
  end

  return {
    valid = true,
    samples = #points,
    elapsed = elapsed,
    arrivalRate = arrivals / elapsed,
    processingRate = processing / elapsed,
    netRate = (last.value - first.value) / elapsed,
  }
end

local function chartValues(resource, now, window)
  local points =
      windowPoints(resource, now, window)

  if #points == 0 then
    return {}
  end

  local scale = resource.capacity

  if not scale then
    scale = 0

    for _, point in ipairs(points) do
      scale = math.max(scale, point.value)
    end
  end

  if scale <= 0 then
    scale = 1
  end

  local values = resource.history:values(window, now)

  for index, value in ipairs(values) do
    values[index] = clamp(value / scale, 0, 1)
  end

  return values
end

local function resourceResult(
    resource,
    now,
    shortWindow,
    mediumWindow
)
  local amount = resource.amount or 0
  local short =
      rateStats(resource, now, shortWindow)
  local medium =
      rateStats(resource, now, mediumWindow)

  local utilization
  local fullInSeconds
  local emptyInSeconds

  if resource.capacity then
    utilization =
        clamp(amount / resource.capacity, 0, 1)

    if short.valid
        and short.netRate > 0
        and amount < resource.capacity
    then
      fullInSeconds =
          (resource.capacity - amount)
          / short.netRate
    elseif short.valid
        and short.netRate < 0
        and amount > 0
    then
      emptyInSeconds =
          amount / -short.netRate
    end
  end

  return {
    key = resource.key,
    label = resource.label,
    technicalName = resource.name
      or resource.id
      or resource.label,
    type = resource.type,
    amount = amount,
    capacity = resource.capacity,
    capacityPolicy = resource.capacityPolicy,
    available = resource.available,
    utilization = utilization,
    fullInSeconds = fullInSeconds,
    emptyInSeconds = emptyInSeconds,
    short = short,
    medium = medium,
    arrivalRate = short.arrivalRate,
    processingRate = short.processingRate,
    backlogRate = short.netRate,
    netRate = short.netRate,
    productionRate = short.arrivalRate,
    consumptionRate = short.processingRate,
    chart = chartValues(resource, now, mediumWindow),
  }
end

local function reasonFor(state, values)
  if state == "OFFLINE" then
    return values.error or "AE2 network unavailable"
  end

  if state == "WARMING" then
    return "insufficient history"
  end

  if state == "STALLED" then
    return "input accumulation with no output activity"
  end

  if state == "OVERLOADED" then
    if values.storagePressure then
      return "configured storage capacity under pressure"
    end

    return "input backlog growing"
  end

  if state == "DRAINING" then
    return "input supply below consumption"
  end

  if state == "IDLE" then
    return "no recent input activity"
  end

  return "steady operation"
end

local function diagnose(inputs, outputs, options, offline, errorMessage)
  if offline then
    return {
      efficiency = nil,
      health = 0,
      state = "OFFLINE",
      reason = errorMessage,
    }
  end

  local valid = false
  local arrivals = 0
  local processing = 0
  local minimumKeepUp = 1
  local hasKeepUp = false
  local backlogGrowing = false
  local backlogDraining = false
  local storagePressure = false
  local hasStoredInput = false
  local maxUtilization = 0

  local function inspectCapacity(resource, values)
    if not values.utilization
        or resource.capacityPolicy ~= "pressure"
    then
      return
    end

    maxUtilization = math.max(
      maxUtilization,
      values.utilization
    )

    if values.utilization >= 0.9 then
      storagePressure = true
    end
  end

  for _, input in ipairs(inputs) do
    if input.available ~= false then
      valid = valid or input.short.valid
      arrivals = arrivals + input.arrivalRate
      processing = processing + input.processingRate

      if input.amount > 0 then
        hasStoredInput = true
      end

      inspectCapacity(input, input)

      if input.backlogRate > options.rateEpsilon then
        backlogGrowing = true
      elseif input.backlogRate < -options.rateEpsilon then
        backlogDraining = true
      end

      local balance = flowBalance(
        input.arrivalRate,
        input.processingRate,
        options.rateEpsilon
      )

      if balance then
        hasKeepUp = true
        minimumKeepUp = math.min(
          minimumKeepUp,
          balance
        )
      end
    end
  end

  local outputActivity = false

  for _, output in ipairs(outputs) do
    if output.available ~= false then
      valid = valid or output.short.valid

      inspectCapacity(output, output)

      if output.productionRate > options.rateEpsilon then
        outputActivity = true
      end
    end
  end

  if not valid then
    return {
      efficiency = nil,
      health = 50,
      state = "WARMING",
      reason = reasonFor("WARMING", {}),
    }
  end

  local keepUp

  if hasKeepUp then
    keepUp = minimumKeepUp
  end

  local health = 100

  health = health
      - math.floor(maxUtilization * 25)

  if backlogGrowing then
    health = health - 25
  end

  if keepUp then
    health = health
        - math.floor((1 - keepUp) * 30)
  end

  health = clamp(health, 0, 100)

  local state

  if hasStoredInput
      and backlogGrowing
      and not outputActivity
      and processing <= options.rateEpsilon
  then
    state = "STALLED"
    health = math.min(health, 20)
  elseif storagePressure then
    state = "OVERLOADED"
    health = math.min(health, 45)
  elseif not hasKeepUp
      and processing <= options.rateEpsilon
      and not outputActivity
  then
    state = "IDLE"
  elseif backlogGrowing then
    state = "OVERLOADED"
  elseif backlogDraining then
    state = "DRAINING"
  else
    state = "HEALTHY"
  end

  local values = {
    storagePressure = storagePressure,
  }

  return {
    efficiency = keepUp
        and math.floor(keepUp * 100 + 0.5)
        or nil,
    health = health,
    state = state,
    reason = reasonFor(state, values),
  }
end

function analytics.resourceKey(resource, index)
  return resourceKey(resource, index)
end

function analytics.create(config)
  assert(
    type(config) == "table",
    "Production line analytics requires a config table"
  )

  local shortWindow =
      positiveNumber(config.shortWindow, 60)

  local mediumWindow =
      positiveNumber(config.mediumWindow, 300)

  local options = {
    shortWindow = shortWindow,
    mediumWindow = mediumWindow,
    sampleSeconds = positiveNumber(
      config.sampleSeconds,
      5
    ),
    rateEpsilon =
        positiveNumber(config.rateEpsilon, 0.001),
  }

  local instance = {
    config = config,
    options = options,
    inputs = createResourceList(
      config.inputs,
      "input",
      options.sampleSeconds
    ),
    outputs = createResourceList(
      config.outputs,
      "output",
      options.sampleSeconds
    ),
    offline = false,
    error = nil,
    lastSample = nil,
  }

  function instance:sample(time, values, records)
    assert(
      type(time) == "number",
      "Production line sample time must be a number"
    )

    assert(
      type(values) == "table",
      "Production line sample values must be a table"
    )

    for _, group in ipairs({
      {
        resources = self.inputs,
        values = values.inputs,
        records = records and records.inputs,
      },
      {
        resources = self.outputs,
        values = values.outputs,
        records = records and records.outputs,
      },
    }) do
      for _, resource in ipairs(group.resources) do
        local record =
            group.records
            and group.records[resource.key]
        local available =
            not group.records
            or record ~= nil
        local amount =
            group.values
            and group.values[resource.key]
            or 0

        resource.amount =
            math.max(0, tonumber(amount) or 0)

        if group.records then
          resource.available = available
        else
          resource.available = nil
        end

        if not resource.labelConfigured
            and type(record) == "table"
        then
          resource.label =
              record.label
              or record.displayName
              or resource.label
        end

        if available then
          resource.history:commit(
            time,
            resource.amount
          )
        end
      end
    end

    self.offline = false
    self.error = nil
    self.lastSample = time
  end

  -- Normalized 0..1 history for one configured resource over `window`
  -- seconds, scaled to its capacity when known.
  function instance:chart(resourceKey, window, time)
    for _, group in ipairs({self.inputs, self.outputs}) do
      for _, resource in ipairs(group) do
        if resource.key == resourceKey then
          return chartValues(resource, time, window)
        end
      end
    end

    return {}
  end

  function instance:setOffline(message)
    self.offline = true
    self.error = tostring(
      message or "AE2 network unavailable"
    )
  end

  function instance:snapshot(time)
    local inputs = {}
    local outputs = {}

    for _, resource in ipairs(self.inputs) do
      inputs[#inputs + 1] =
          resourceResult(
            resource,
            time,
            self.options.shortWindow,
            self.options.mediumWindow
          )
    end

    for _, resource in ipairs(self.outputs) do
      outputs[#outputs + 1] =
          resourceResult(
            resource,
            time,
            self.options.shortWindow,
            self.options.mediumWindow
          )
    end

    local diagnosis =
        diagnose(
          inputs,
          outputs,
          self.options,
          self.offline,
          self.error
        )

    return {
      id = self.config.id,
      name = self.config.name,
      type = "production_line",
      inputs = inputs,
      outputs = outputs,
      efficiency = diagnosis.efficiency,
      health = diagnosis.health,
      state = diagnosis.state,
      reason = diagnosis.reason,
      sampledAt = self.lastSample,
      offline = self.offline,
      error = self.error,
    }
  end

  function instance:telemetry(time)
    local current = self:snapshot(time)

    return {
      type = current.type,
      name = current.name,
      efficiency = current.efficiency,
      health = current.health,
      state = current.state,
      reason = current.reason,
    }
  end

  return instance
end

return analytics
