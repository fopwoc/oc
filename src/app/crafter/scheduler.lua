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

local POLL_INTERVAL = 0.25

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

  local craftableLabel =
      config.label

  assert(
    targetType == "fluid"
      or type(craftableLabel) == "string",
    "Item target label is required"
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
    name = name,

    amount = amount,
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

  if target.job.isCanceled() then
    target.job = nil

    target.status = "cooldown"
    target.nextRequestAt =
        now + target.cooldown

    return
  end

  if target.job.isDone() then
    target.job = nil
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
      pcall(
        target.craftable.request,
        target.amount
      )

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

  assert(
    #targetConfigs > 0,
    "At least one target is required"
  )

  local instance = {
    targets = {},

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
    local waiting = 0
    local cooldown = 0

    local completedPerHour = 0
    local now = computer.uptime()

    for _, target in ipairs(self.targets) do
      if target.status == "crafting" then
        crafting = crafting + 1
      elseif target.status == "cooldown" then
        cooldown = cooldown + 1
      else
        waiting = waiting + 1
      end

      completedPerHour = completedPerHour
          + target.completions:perHour(now)
    end

    return {
      playing = playing,
      targets = #self.targets,
      crafting = crafting,
      waiting = waiting,
      cooldown = cooldown,
      completedPerHour = completedPerHour,
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

    for offset = 0, count - 1 do
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
