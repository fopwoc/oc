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

local function packet(event, sourceId, data, uptime, address)
  return {
    source = "line-monitor",
    id = sourceId or "platline",
    address = address or "computer-a",
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

assert(
  incidents:handle(packet("incident_raised", "monazite", {
    id = "stopped",
    title = "Line stopped",
    message = "Same configuration on another computer",
    raisedAt = 13,
  }, nil, "computer-b"))
    and incidents:activeCount() == 3,
  "dashboard should keep sender addresses separate"
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
    and incidents:activeCount() == 2,
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
    and incidents:activeCount() == 1,
    "resolution should affect only the matching sender address"
)

assert(
  incidents:handle(packet("incident_resolved", "monazite", {
    id = "stopped",
    resolvedAt = 31,
  }, nil, "computer-b"))
    and incidents:activeCount() == 0,
    "same-id sender incidents should resolve independently"
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

local function ambiguousPacket(source, sourceId)
  return {
    source = source,
    id = sourceId,
    address = "identity-test",
    event = "incident_raised",
    uptime = 60,
    data = {
      id = "same",
      title = "Identity test",
      message = "Separator-safe identity",
      raisedAt = 60,
    },
  }
end

local beforeAmbiguous = incidents:activeCount()

incidents:handle(ambiguousPacket("a:b", "c"))
incidents:handle(ambiguousPacket("a", "b:c"))

assert(
  incidents:activeCount() == beforeAmbiguous + 2,
  "incident identity fields must not collide when they contain separators"
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
