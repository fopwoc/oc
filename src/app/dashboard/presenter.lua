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
      or state == "DRAINING"
      or state == "IDLE"
  then
    return colors.good
  end

  if state == "WARMING" then
    return colors.warning
  end

  return colors.bad
end

local function crafterRows(sources, dashboard, colors, cells)
  local rows = {
    {
      "SOURCE",
      "STATE",
      "TARGET",
      "CRAFT",
      "WAIT",
      "COOL",
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

    rows[#rows + 1] = {
      cells:colored(source.id, colors.primary),
      cells:colored(activity, activityColor),
      cells:number(data.targets),
      cells:number(data.crafting, colors.good),
      cells:number(data.waiting),
      cells:number(data.cooldown, colors.warning),
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
      "EFF",
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
    {weight = 1, align = "left"},
    {weight = 1, align = "right"},
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
