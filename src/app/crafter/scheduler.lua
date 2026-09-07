local component =
  require("component")

local computer =
  require("computer")

local scheduler = {}

local me =
  component.me_interface

local POLL_INTERVAL = 0.25

local function loadCraftable(label)
  local found =
    me.getCraftables({
      label = label,
    })

  if not found or #found == 0 then
    error(
      "Craftable not found: "
        .. label
    )
  end

  return found[1]
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
  defaults
)
  assert(
    type(config) == "table",
    "Target must be a table"
  )

  local label =
    assert(
      config.label,
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

  return {
    label = label,

    amount = amount,
    cooldown = cooldown,

    craftable =
      loadCraftable(label),

    job = nil,

    status = "waiting",

    nextRequestAt = 0,

    completed = 0,
    canceled = 0,
    requests = 0,
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
    target.canceled =
      target.canceled + 1

    target.status = "cooldown"
    target.nextRequestAt =
      now + target.cooldown

    return
  end

  if target.job.isDone() then
    target.job = nil
    target.completed =
      target.completed + 1

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

  target.requests =
    target.requests + 1

  local job =
    target.craftable.request(
      target.amount
    )

  if not job then
    target.status = "cooldown"
    target.nextRequestAt =
      now + target.cooldown

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
        defaults
      )
  end

  function instance:stop()
    self.running = false
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
