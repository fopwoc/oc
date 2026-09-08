local dashboardIncidents =
    require("lib.telemetry.incidents.dashboard")

local savedHistory

local function historyStore()
  return {
    load = function()
      return savedHistory or {resolved = {}}
    end,
    save = function(_, state)
      savedHistory = state
    end,
  }
end

local incidents = dashboardIncidents.create({
  history = historyStore(),
})

local function packet(event, sourceId, data, uptime)
  return {
    source = "line-monitor",
    id = sourceId or "platline",
    event = event,
    uptime = uptime or 10,
    data = data,
  }
end

assert(
  incidents:handle(packet("incident_raised", "platline", {
    id = "stopped",
    title = "Line stopped",
    message = "Inspect the processing line",
    raisedAt = 10,
  }))
    and incidents:activeCount() == 1,
  "dashboard should accept a new incident"
)

assert(
  not incidents:handle(packet("incident_raised", "platline", {
    id = "stopped",
    title = "Line stopped",
    message = "Duplicate",
    raisedAt = 11,
  }))
    and incidents:activeCount() == 1,
  "dashboard should deduplicate an active incident"
)

assert(
  incidents:handle(packet("incident_raised", "monazite", {
    id = "stopped",
    title = "Line stopped",
    message = "Inspect the second line",
    raisedAt = 12,
  }))
    and incidents:activeCount() == 2,
  "dashboard should keep source identities separate"
)

local first = incidents:current()
assert(first and first.sourceId == "platline")
assert(incidents:dismiss(first.key))

local second = incidents:current()
assert(second and second.sourceId == "monazite")

assert(
  incidents:handle(packet("incident_resolved", "platline", {
    id = "stopped",
    resolvedAt = 20,
  }))
    and incidents:activeCount() == 1,
  "resolution should remove only the matching active incident"
)

assert(
  #incidents:history() == 1
    and incidents:history()[1].resolvedAt == 20,
  "resolved incidents should enter history"
)

assert(
  incidents:handle(packet("incident_resolved", "monazite", {
    id = "stopped",
    resolvedAt = 30,
  }))
    and incidents:activeCount() == 0,
    "second incident should resolve independently"
)

assert(
  incidents:handle(packet("incident_raised", "platline", {
    id = "stale",
    title = "Stale incident",
    message = "The source will reconcile it",
    raisedAt = 40,
  }))
)

assert(
  incidents:handle(packet("incident_snapshot", "platline", {
    active = {},
  }, 50))
    and incidents:activeCount() == 0,
  "source snapshots should reconcile resolved incidents"
)

for index = 1, 35 do
  local id = "history-" .. tostring(index)

  incidents:handle(packet("incident_raised", "history", {
    id = id,
    title = "History incident",
    message = "Bounded history test",
    raisedAt = 100 + index,
  }))

  incidents:handle(packet("incident_resolved", "history", {
    id = id,
    resolvedAt = 200 + index,
  }))
end

local restored = dashboardIncidents.create({
  history = historyStore(),
})

assert(
  #restored:history() == 32,
  "incident history should survive Dashboard restart"
)

print("dashboard incidents: OK")
