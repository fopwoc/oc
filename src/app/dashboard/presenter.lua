local format = require("lib.utils.format")
local grid = require("lib.components.grid")

local presenter = {}

local STALE_AFTER = 3
local OFFLINE_AFTER = 10

local TYPE_TITLES = {
  crafter = "CRAFTERS",
  production_line = "PRODUCTION LINES",
  power_monitor = "POWER MONITORS",
}

local function sourceType(source)
  local data = source.data or {}

  return tostring(
    data.type
      or source.source
      or "unknown"
  )
end

local function typeTitle(typeName)
  return (
    TYPE_TITLES[typeName]
      or typeName:gsub("_", " "):upper()
  )
end

local function sourceStatus(source, dashboard, colors)
  local age = dashboard:age(source)

  if age >= OFFLINE_AFTER then
    return "OFFLINE", colors.bad
  end

  if age >= STALE_AFTER then
    return "STALE", colors.warning
  end

  return "ONLINE", colors.good
end

local function lineStateColor(state, colors)
  if state == "HEALTHY"
      or state == "IDLE"
  then
    return colors.good
  end

  if state == "WARMING"
      or state == "DRAINING"
  then
    return colors.warning
  end

  return colors.bad
end

local function crafterCounts(data)
  local metrics = data.targetMetrics
  local targets = data.targets

  if type(targets) ~= "number" then
    targets = type(metrics) == "table"
      and #metrics
      or 0
  end

  local active

  if type(data.crafting) == "number"
      and type(data.requesting) == "number"
  then
    active = data.crafting + data.requesting
  elseif type(metrics) == "table" then
    active = 0

    for _, target in ipairs(metrics) do
      if target.status == "crafting"
          or target.status == "requesting"
      then
        active = active + 1
      end
    end
  end

  return targets, active
end

local function crafterSatisfaction(data)
  if type(data.satisfaction) == "number" then
    return math.max(0, math.min(100, data.satisfaction))
  end

  local metrics = data.targetMetrics

  if type(metrics) ~= "table" or #metrics == 0 then
    return nil
  end

  local total = 0

  for _, target in ipairs(metrics) do
    local desired = tonumber(target.targetAmount)
    local current = tonumber(target.currentAmount)

    if not desired or desired <= 0 or not current then
      return nil
    end

    total = total
        + math.max(0, math.min(1, current / desired))
  end

  return math.floor(total / #metrics * 100 + 0.5)
end

local function crafterRows(sources, dashboard, colors, cells)
  local rows = {
    {
      "SOURCE",
      "STATE",
      "TARGETS",
      "ACTIVE",
      "SAT",
      "DONE/H",
      "SEEN",
      "UP",
    },
  }

  for _, source in ipairs(sources) do
    local status, statusColor =
        sourceStatus(source, dashboard, colors)
    local data = source.data or {}
    local activity =
        data.playing and "RUNNING" or "PAUSED"
    local activityColor =
        data.playing and colors.good or colors.warning

    if status ~= "ONLINE" then
      activity = status
      activityColor = statusColor
    end

    local targets, active = crafterCounts(data)
    local satisfaction = crafterSatisfaction(data)

    rows[#rows + 1] = {
      cells:colored(source.id, colors.primary),
      cells:colored(activity, activityColor),
      cells:colored(tostring(targets), colors.text),
      cells:colored(
        active ~= nil and tostring(active) or "--",
        active and active > 0 and colors.primary or colors.muted
      ),
      cells:colored(
        format.percent(satisfaction),
        satisfaction == 100 and colors.good or colors.primary
      ),
      cells:colored(
        data.completedPerHour
          and string.format("%.1f", data.completedPerHour)
          or "--",
        colors.good
      ),
      cells:colored(
        format.age(dashboard:age(source)),
        colors.muted
      ),
      cells:colored(
        format.uptime(source.remoteUptime),
        colors.muted
      ),
    }
  end

  return rows
end

local function lineRows(sources, dashboard, colors, cells)
  local rows = {
    {
      "SOURCE",
      "STATE",
      "LINE",
      "KEEP-UP",
      "HEALTH",
      "REASON",
      "SEEN",
      "UP",
    },
  }

  for _, source in ipairs(sources) do
    local status, statusColor =
        sourceStatus(source, dashboard, colors)
    local data = source.data or {}
    local activity = data.state or "UNKNOWN"
    local activityColor =
        lineStateColor(activity, colors)

    if status ~= "ONLINE" then
      activity = status
      activityColor = statusColor
    end

    rows[#rows + 1] = {
      cells:colored(source.id, colors.primary),
      cells:colored(activity, activityColor),
      cells:colored(data.name or source.id, colors.text),
      cells:colored(format.percent(data.efficiency), colors.primary),
      cells:colored(format.percent(data.health), activityColor),
      cells:colored(data.reason or "-", colors.muted),
      cells:colored(
        format.age(dashboard:age(source)),
        colors.muted
      ),
      cells:colored(
        format.uptime(source.remoteUptime),
        colors.muted
      ),
    }
  end

  return rows
end

local function powerRows(sources, dashboard, colors, cells)
  local rows = {
    {
      "SOURCE",
      "POWER",
      "STATE",
      "FILL",
      "24H",
      "NET",
      "ETA",
      "SEEN",
      "UP",
    },
  }

  for _, source in ipairs(sources) do
    local status, statusColor =
        sourceStatus(source, dashboard, colors)
    local data = source.data or {}

    local metricColor = statusColor
    local state = data.state or status

    if status == "ONLINE" then
      if data.offline then
        state = "OFFLINE"
        metricColor = colors.bad
      elseif data.state == "NORMAL" then
        metricColor = colors.good
      elseif data.state == "DRAINING" then
        metricColor = colors.warning
      else
        metricColor = colors.bad
      end
    end

    rows[#rows + 1] = {
      cells:colored(source.id, colors.primary),
      cells:colored(data.name or source.id, colors.text),
      cells:colored(state, metricColor),
      cells:colored(
        data.fill
          and tostring(math.floor(data.fill * 100 + 0.5)) .. "%"
          or "--",
        metricColor
      ),
      cells:colored(
        data.averageFill24h
          and tostring(math.floor(data.averageFill24h * 100 + 0.5)) .. "%"
          or "--",
        colors.muted
      ),
      cells:colored(
        format.powerRate(data.net),
        metricColor
      ),
      cells:colored(
        data.etaSeconds
          and format.duration(data.etaSeconds)
          or "--",
        metricColor
      ),
      cells:colored(
        format.age(dashboard:age(source)),
        colors.muted
      ),
      cells:colored(
        format.uptime(source.remoteUptime),
        colors.muted
      ),
    }
  end

  return rows
end

local function genericRows(sources, dashboard, colors, cells)
  local rows = {
    {
      "SOURCE",
      "STATE",
      "NAME",
      "SEEN",
      "UP",
    },
  }

  for _, source in ipairs(sources) do
    local status, statusColor =
        sourceStatus(source, dashboard, colors)
    local data = source.data or {}

    rows[#rows + 1] = {
      cells:colored(source.id, colors.primary),
      cells:colored(
        data.state or status,
        data.state and colors.primary or statusColor
      ),
      cells:colored(data.name or source.id, colors.text),
      cells:colored(
        format.age(dashboard:age(source)),
        colors.muted
      ),
      cells:colored(
        format.uptime(source.remoteUptime),
        colors.muted
      ),
    }
  end

  return rows
end

local function crafterColumns()
  return {
    {weight = 2, align = "left"},
    {weight = 2, align = "left"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
  }
end

local function lineColumns()
  return {
    {weight = 2, align = "left"},
    {weight = 1, align = "left"},
    {weight = 2, align = "left"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
    {weight = 3, align = "left"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
  }
end

local function powerColumns()
  return {
    {weight = 2, align = "left"},
    {weight = 3, align = "left"},
    {weight = 2, align = "left"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
    {weight = 2, align = "right"},
    {weight = 2, align = "right"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
  }
end

local function genericColumns()
  return {
    {weight = 2, align = "left"},
    {weight = 1, align = "left"},
    {weight = 3, align = "left"},
    {weight = 1, align = "right"},
    {weight = 1, align = "right"},
  }
end

local function sectionFor(typeName, sources, dashboard, colors, cells)
  local rows
  local columns

  if typeName == "crafter" then
    rows = crafterRows(
      sources,
      dashboard,
      colors,
      cells
    )
    columns = crafterColumns()
  elseif typeName == "production_line" then
    rows = lineRows(
      sources,
      dashboard,
      colors,
      cells
    )
    columns = lineColumns()
  elseif typeName == "power_monitor" then
    rows = powerRows(
      sources,
      dashboard,
      colors,
      cells
    )
    columns = powerColumns()
  else
    rows = genericRows(
      sources,
      dashboard,
      colors,
      cells
    )
    columns = genericColumns()
  end

  return {
    title = typeTitle(typeName),
    count = #sources,
    rows = rows,
    columns = columns,
    cell = cells.render,
  }
end

function presenter.sections(sources, dashboard, colors)
  local cells = grid.GridCells(colors)
  local groups = {}
  local typeNames = {}

  for _, source in ipairs(sources) do
    local typeName = sourceType(source)
    local group = groups[typeName]

    if not group then
      group = {}
      groups[typeName] = group
      typeNames[#typeNames + 1] = typeName
    end

    group[#group + 1] = source
  end

  table.sort(typeNames)

  local sections = {}

  for _, typeName in ipairs(typeNames) do
    sections[#sections + 1] = sectionFor(
      typeName,
      groups[typeName],
      dashboard,
      colors,
      cells
    )
  end

  return sections
end

return presenter
