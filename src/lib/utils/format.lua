local decimal = require("lib.utils.decimal")

local format = {}

local function compactPower(value, suffix)
  if value == nil then
    return "--"
  end

  local magnitude = math.abs(value)
  local unit = ""
  local divisor = 1

  if magnitude >= 1e18 then
    unit = "E"
    divisor = 1e18
  elseif magnitude >= 1e15 then
    unit = "P"
    divisor = 1e15
  elseif magnitude >= 1e12 then
    unit = "T"
    divisor = 1e12
  elseif magnitude >= 1e9 then
    unit = "G"
    divisor = 1e9
  elseif magnitude >= 1e6 then
    unit = "M"
    divisor = 1e6
  elseif magnitude >= 1e3 then
    unit = "k"
    divisor = 1e3
  end

  return string.format(
    "%.3g %s%s",
    value / divisor,
    unit,
    suffix or ""
  )
end

function format.number(value)
  value = math.floor(tonumber(value) or 0)

  local text = tostring(value)

  while true do
    local formatted, count =
        text:gsub(
          "^(-?%d+)(%d%d%d)",
          "%1,%2"
        )

    text = formatted

    if count == 0 then
      break
    end
  end

  return text
end

function format.grouped(value)
  if value == nil then
    return "--"
  end

  local text = tostring(value)
  local sign = ""

  if text:sub(1, 1) == "-" then
    sign = "-"
    text = text:sub(2)
  end

  if not text:match("^%d+$") then
    return "--"
  end

  text = text:gsub("^0+", "")

  if text == "" then
    text = "0"
  end

  while true do
    local formatted, count =
        text:gsub(
          "^(%d+)(%d%d%d)",
          "%1,%2"
        )

    text = formatted

    if count == 0 then
      break
    end
  end

  return sign .. text
end

function format.percent(value)
  if value == nil then
    return "--"
  end

  return tostring(value) .. "%"
end

function format.duration(seconds)
  if not seconds then
    return "--"
  end

  seconds = math.max(0, math.floor(seconds))

  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)

  if hours > 0 then
    return tostring(hours)
      .. "h "
      .. string.format("%02dm", minutes)
  end

  return tostring(minutes) .. "m"
end

function format.age(seconds)
  if seconds < 1 then
    return "<1s"
  end

  return tostring(math.floor(seconds)) .. "s"
end

function format.uptime(seconds)
  seconds = math.floor(seconds or 0)

  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)

  if hours > 0 then
    return tostring(hours) .. "h " .. tostring(minutes) .. "m"
  end

  return tostring(minutes) .. "m"
end

function format.rate(value)
  if value == nil then
    return "--"
  end

  return format.number(value * 60) .. "/m"
end

function format.powerRate(value)
  return compactPower(value, "EU/t")
end

function format.energy(value)
  return decimal.compact(value, "EU")
end

function format.energyExact(value)
  local grouped = format.grouped(value)

  if grouped == "--" then
    return grouped
  end

  return grouped .. " EU"
end

function format.amount(value, capacity)
  local text = format.number(value)

  if capacity then
    return text .. "/" .. format.number(capacity)
  end

  return text .. "/--"
end

return format
