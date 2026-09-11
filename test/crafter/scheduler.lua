package.path = "src/?.lua;" .. package.path

local now = 0
local jobState = "computing"
local networkAmount = 0
local lastRequestAmount
local proxyError = false
local proxiedAddress

local me = {}
local craftable = {}

function me.getItemInNetwork()
  return {
    label = "Test Dust",
    size = networkAmount,
  }
end

function me.getItemsInNetwork()
  return {
    {
      label = "Test Dust",
      size = networkAmount,
    },
  }
end

function me.getCraftables()
  return {craftable}
end

function craftable.request(amount)
  lastRequestAmount = amount

  local function callable(callback)
    return setmetatable({}, {
      __call = function(_, ...)
        return callback(...)
      end,
    })
  end

  return {
    isCanceled = callable(function()
      return false
    end),

    hasFailed = callable(function()
      if jobState == "failed" then
        return true, "missing resources"
      end

      return false
    end),

    isComputing = callable(function()
      return jobState == "computing"
    end),

    isDone = callable(function()
      return jobState == "done"
    end),
  }
end

local previousComputer = package.loaded.computer
local previousComponent = package.loaded.component
local previousComputerLoader = package.preload.computer
local previousComponentLoader = package.preload.component

package.loaded.computer = nil
package.loaded.component = nil

package.preload.computer = function()
  return {
    uptime = function()
      return now
    end,
  }
end

package.preload.component = function()
  return {
    list = function()
      return function()
        return "me-address"
      end
    end,

    proxy = function(address)
      proxiedAddress = address

      if proxyError then
        error("component unavailable")
      end

      return me
    end,
  }
end

package.loaded["lib.ae2.network"] = nil
package.loaded["app.crafter.scheduler"] = nil

local schedulerModule =
    require("app.crafter.scheduler")

local configuredScheduler = schedulerModule.create({
  meAddress = "configured-address",
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {label = "Configured network"},
  },
})

assert(
  proxiedAddress == "configured-address"
    and configuredScheduler.adapter.kind == "configured",
  "crafter should use its configured ME component"
)

proxyError = true

local disconnectedScheduler = schedulerModule.create({
  meAddress = "offline-address",
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {label = "Offline network", retrySeconds = 1},
  },
})

disconnectedScheduler:step(true)

assert(
  disconnectedScheduler.targets[1].status == "waiting"
    and disconnectedScheduler.targets[1].resolveError,
  "crafter should remain alive while its ME component is unavailable"
)

proxyError = false

local scheduler = schedulerModule.create({
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {
      label = "Test Dust",
      retrySeconds = 1,
    },
  },
})

local target = scheduler.targets[1]

scheduler:step(true)

assert(
  target.status == "crafting",
  "accepted request should start with an active job"
)

networkAmount = 7
local deficitScheduler = schedulerModule.create({
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {
      label = "Stock Dust",
      amount = 10,
    },
  },
})

local deficitTarget = deficitScheduler.targets[1]

deficitScheduler:step(true)

assert(
  lastRequestAmount == 3
    and deficitTarget.currentAmount == 7,
  "crafter should request only the missing target amount"
)

local deficitSnapshot =
    deficitScheduler:snapshot(true)

assert(
  deficitSnapshot.targets == 1
    and deficitSnapshot.crafting == 1
    and deficitSnapshot.satisfaction == 70
    and deficitSnapshot.targetMetrics == nil,
  "crafter telemetry should expose bounded aggregate target satisfaction"
)

networkAmount = 5

local averageSatisfactionScheduler = schedulerModule.create({
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {
      label = "Small target",
      amount = 10,
    },
    {
      label = "Large target",
      amount = 20,
    },
  },
})

averageSatisfactionScheduler:step(true)

assert(
  averageSatisfactionScheduler:snapshot(true).satisfaction == 38,
  "satisfaction should equally average each target percentage"
)

networkAmount = 0

local namedScheduler = schedulerModule.create({
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {
      name = "test:item",
    },
  },
})

namedScheduler:step(true)

assert(
  namedScheduler.targets[1].label == "Test Dust",
  "technical-only targets should use the AE2 display label"
)

now = 1
scheduler:step(false)

assert(
  target.status == "requesting",
  "AE2 planning should not be reported as crafting"
)

jobState = "active"
now = 2
scheduler:step(false)

assert(
  target.status == "crafting",
  "submitted AE2 job should be reported as crafting"
)

jobState = "done"
now = 3
scheduler:step(false)

assert(
  target.status == "cooldown"
    and target.completions:size() == 1,
  "completed jobs should leave crafting and count once"
)

jobState = "active"
local serialScheduler = schedulerModule.create({
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {label = "First Dust"},
    {label = "Second Dust"},
  },
})

serialScheduler:step(true)

local active = 0

for _, serialTarget in ipairs(serialScheduler.targets) do
  if serialTarget.job then
    active = active + 1
  end
end

assert(
  active == 1,
  "the default scheduler should keep only one AE2 request active"
)

jobState = "done"
now = 4
serialScheduler:step(false)

jobState = "active"
now = 5
serialScheduler:step(true)

assert(
  serialScheduler.targets[2].job ~= nil,
  "the next target should start after the previous request completes"
)

jobState = "computing"
local failedScheduler = schedulerModule.create({
  completionWindowSeconds = 3600,
  completionHistoryCapacity = 16,
  targets = {
    {
      label = "Failed Dust",
      retrySeconds = 1,
    },
  },
})

local failedTarget = failedScheduler.targets[1]

function me.getCraftables()
  return {craftable}
end

failedScheduler:step(true)
jobState = "failed"
now = 4
failedScheduler:step(false)

assert(
  failedTarget.status == "waiting"
    and failedTarget.completions:size() == 0
    and failedTarget.resolveError == "missing resources",
  "failed requests should not count as completions"
)

package.loaded.computer = previousComputer
package.loaded.component = previousComponent
package.preload.computer = previousComputerLoader
package.preload.component = previousComponentLoader

print("crafter scheduler: OK")
