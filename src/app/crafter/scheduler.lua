local computer =
    require("computer")

local scheduler = {}

local rollingCounter =
    require("lib.collections.rolling_counter")

local craftableResolver =
    require("lib.ae2.craftable")

local ae2 =
    require("lib.ae2.network")

local me =
    assert(
      ae2.resolveProxy(),
      "No ME controller or interface component found"
    )

local adapter =
    ae2.create()

local POLL_INTERVAL = 0.25

local function positiveInteger(value, fallback)
  value = tonumber(value)

  if value
      and value > 0
      and value == math.floor(value)
  then
    return value
  end

  return fallback
end

local function resolve(
    value,
    default,
    fallback
)
  if value ~= nil then
    return value
  end

  if default ~= nil then
    return default
  end

  return fallback
end

local function createTarget(
    config,
    defaults,
    schedulerConfig
)
  assert(
    type(config) == "table",
    "Target must be a table"
  )

  local targetType =
      config.type
      or "item"

  assert(
    targetType == "item"
      or targetType == "fluid",
    "Target type must be item or fluid"
  )

  local name =
      config.name
      or config.id

  if targetType == "fluid" then
    name =
        config.fluid
        or name

    assert(
      type(name) == "string"
        and name ~= "",
      "Fluid target requires fluid or name"
    )
  end

  local label =
      config.label
      or name

  assert(
    targetType == "fluid"
      or type(name) == "string"
      or type(config.label) == "string",
    "Item target requires name, id, or label"
  )

  assert(
    type(label) == "string"
      and label ~= "",
    "Target label is required"
  )

  local amount =
      resolve(
        config.amount,
        defaults.amount,
        1
      )

  local cooldown =
      resolve(
        config.cooldown,
        defaults.cooldown,
        0
      )

  local retrySeconds =
      resolve(
        config.retrySeconds,
        defaults.retrySeconds,
        1
      )

  assert(
    type(amount) == "number"
    and amount > 0,
    "Target amount must be greater than 0: "
    .. label
  )

  assert(
      type(cooldown) == "number"
    and cooldown >= 0,
    "Target cooldown must be >= 0: "
      .. label
  )

  assert(
    type(retrySeconds) == "number"
      and retrySeconds >= 0,
    "Target retrySeconds must be >= 0: "
      .. label
  )

  return {
    type = targetType,
    label = label,
    labelConfigured = type(config.label) == "string",
    name = name,
    damage = config.damage or 0,
    nbt = config.nbt,
    fluidLabel = config.fluidLabel,

    amount = amount,
    currentAmount = 0,
    amountError = nil,
    cooldown = cooldown,
    retrySeconds = retrySeconds,

    craftable = nil,
    resolveError = nil,

    job = nil,

    status = "waiting",

    nextRequestAt = 0,

    completions = rollingCounter.create({
      windowSeconds = schedulerConfig.completionWindowSeconds,
      capacity = schedulerConfig.completionHistoryCapacity,
    }),
  }
end

local function refreshTarget(target, now)
  local amount, errorMessage, stack =
      adapter:getAmountInNetwork(target)

  if amount == nil then
    target.amountError = errorMessage

    if not target.job then
      target.resolveError = errorMessage
      target.status = "waiting"
      target.nextRequestAt =
          now + target.retrySeconds
    end

    return false
  end

  target.currentAmount = math.max(
    0,
    tonumber(amount) or 0
  )
  target.amountError = nil

  if not target.labelConfigured
      and target.type == "item"
      and type(stack) == "table"
  then
    target.label =
        stack.label
        or stack.displayName
        or target.label
  end

  if not target.job
      and target.currentAmount >= target.amount
  then
    target.resolveError = nil
    target.status = "ready"
  elseif not target.job
      and target.status == "ready"
  then
    target.status = "waiting"
  end

  return true
end

local function updateTarget(
    target,
    now
)
  if not target.job then
    if
        target.status == "cooldown"
        and now >= target.nextRequestAt
    then
      target.status = "waiting"
    end

    return
  end

  local function jobStatus(method, optional)
    local memberOk, member =
        pcall(function()
          return target.job[method]
        end)

    if not memberOk then
      if optional then
        return nil, nil, nil, false
      end

      return nil, nil, tostring(member), true
    end

    local ok, value, detail =
        pcall(function()
          return member()
        end)

    if not ok then
      local wrappedOk, wrappedValue, wrappedDetail =
          pcall(function()
            return member(target.job)
          end)

      if wrappedOk then
        return wrappedValue, wrappedDetail, nil, true
      end

      if optional then
        return nil, nil, nil, false
      end

      return nil, nil, tostring(value), true
    end

    return value, detail, nil, true
  end

  local canceled, _, canceledError =
      jobStatus("isCanceled")

  if canceledError then
    target.job = nil
    target.craftable = nil
    target.resolveError = canceledError
    target.status = "waiting"
    target.nextRequestAt =
        now + target.retrySeconds

    return
  end

  if canceled == true then
    target.job = nil

    target.status = "cooldown"
    target.nextRequestAt =
        now + target.cooldown

    return
  end

  local failed, failureReason, failedError, failedSupported =
      jobStatus("hasFailed", true)

  if failedError and failedSupported then
    target.job = nil
    target.craftable = nil
    target.resolveError = failedError
    target.status = "waiting"
    target.nextRequestAt =
        now + target.retrySeconds

    return
  end

  if failed == true then
    target.job = nil
    target.craftable = nil
    target.resolveError =
        failureReason
        or "crafting request failed"
    target.status = "waiting"
    target.nextRequestAt =
        now + target.retrySeconds

    return
  end

  local computing, _, computingError, computingSupported =
      jobStatus("isComputing", true)

  if computingError and computingSupported then
    target.job = nil
    target.craftable = nil
    target.resolveError = computingError
    target.status = "waiting"
    target.nextRequestAt =
        now + target.retrySeconds

    return
  end

  if computing == true then
    target.status = "requesting"
    return
  end

  target.status = "crafting"

  local done, _, doneError =
      jobStatus("isDone")

  if doneError then
    target.job = nil
    target.craftable = nil
    target.resolveError = doneError
    target.status = "waiting"
    target.nextRequestAt =
        now + target.retrySeconds

    return
  end

  if done == true then
    target.job = nil
    target.resolveError = nil
    target.completions:record(now)

    target.status = "cooldown"
    target.nextRequestAt =
        now + target.cooldown
  end
end

local function requestTarget(
    target,
    now
)
  if target.job then
    return false
  end

  if now < target.nextRequestAt then
    return false
  end

  local deficit =
      target.amount - target.currentAmount

  if deficit <= 0 then
    target.status = "ready"
    target.resolveError = nil
    return false
  end

  if not target.craftable then
    local resolved, errorMessage =
        craftableResolver.resolve(
          me,
          target
        )

    if not resolved then
      target.resolveError = errorMessage
      target.status = "waiting"
      target.nextRequestAt =
          now + target.retrySeconds

      return false
    end

    target.craftable = resolved
    target.resolveError = nil
  end

  local requested, job =
      pcall(function()
        return target.craftable.request(
          deficit
        )
      end)

  if not requested then
    local wrappedRequested, wrappedJob =
        pcall(function()
            return target.craftable.request(
              target.craftable,
              deficit
            )
        end)

    if wrappedRequested then
      requested = true
      job = wrappedJob
    end
  end

  if not requested or not job then
    -- A missing dependency is a normal scheduling state. It is
    -- deliberately not recorded as a failed craft attempt.
    target.craftable = nil
    target.resolveError =
        requested
        and "craftable request was not accepted"
        or tostring(job)
    target.status = "waiting"
    target.nextRequestAt =
        now + target.retrySeconds

    return false
  end

  target.job = job
  target.status = "crafting"

  return true
end

function scheduler.create(config)
  assert(
    type(config) == "table",
    "Scheduler config must be a table"
  )

  local defaults =
      config.defaults
      or {}

  local targetConfigs =
      config.targets
      or {}

  local maxConcurrent =
      positiveInteger(config.maxConcurrent, 1)

  assert(
    #targetConfigs > 0,
    "At least one target is required"
  )

  local instance = {
    targets = {},

    maxConcurrent = maxConcurrent,

    running = true,

    -- First target that gets the first
    -- scheduling opportunity.
    cursor = 1,
  }

  for _, targetConfig in ipairs(
    targetConfigs
  ) do
    instance.targets[
    #instance.targets + 1
    ] =
        createTarget(
          targetConfig,
          defaults,
          config
        )
  end

  function instance:stop()
    self.running = false
  end

  function instance:snapshot(playing)
    local crafting = 0
    local requesting = 0
    local waiting = 0
    local cooldown = 0

    local completedPerHour = 0
    local now = computer.uptime()
    local targetMetrics = {}

    for _, target in ipairs(self.targets) do
      if target.status == "crafting" then
        crafting = crafting + 1
      elseif target.status == "requesting" then
        requesting = requesting + 1
      elseif target.status == "cooldown" then
        cooldown = cooldown + 1
      else
        waiting = waiting + 1
      end

      completedPerHour = completedPerHour
          + target.completions:perHour(now)

      targetMetrics[#targetMetrics + 1] = {
        label = target.label,
        currentAmount = target.currentAmount,
        targetAmount = target.amount,
        status = target.status,
        completedPerHour = target.completions:perHour(now),
      }
    end

    return {
      playing = playing,
      targets = #self.targets,
      crafting = crafting,
      requesting = requesting,
      waiting = waiting,
      cooldown = cooldown,
      completedPerHour = completedPerHour,
      targetMetrics = targetMetrics,
    }
  end

  function instance:step(allowScheduling)
    local now =
        computer.uptime()

    --
    -- Phase 1:
    -- update every existing job.
    --
    for _, target in ipairs(
      self.targets
    ) do
      updateTarget(
        target,
        now
      )

      refreshTarget(
        target,
        now
      )
    end

    if allowScheduling == false then
      return
    end

    --
    -- Phase 2:
    -- fair round-robin scheduling.
    --
    local count =
        #self.targets

    local start =
        self.cursor

    local activeJobs = 0

    for _, target in ipairs(self.targets) do
      if target.job then
        activeJobs = activeJobs + 1
      end
    end

    for offset = 0, count - 1 do
      if activeJobs >= self.maxConcurrent then
        break
      end

      local index =
          ((start + offset - 1) % count)
          + 1

      local target =
          self.targets[index]

      if
          not target.job
          and now >= target.nextRequestAt
      then
        local accepted =
            requestTarget(
              target,
              now
            )

        if accepted then
          activeJobs = activeJobs + 1

          --
          -- Next scheduling pass starts
          -- after the recipe that just won.
          --
          self.cursor =
              (index % count)
              + 1
        end
      end
    end
  end

  function instance:run()
    while self.running do
      self:step()

      os.sleep(
        POLL_INTERVAL
      )
    end
  end

  return instance
end

return scheduler
