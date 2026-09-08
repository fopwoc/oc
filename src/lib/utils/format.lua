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
  if type(value) ~= "string" then
    return "--"
  end

  local normalized = value:gsub("^0+", "")

  if normalized == "" then
    normalized = "0"
  end

  local length = #normalized
  local exponent = length - 1
  local digits = math.min(length, 15)
  local leading = tonumber(normalized:sub(1, digits))

  if not leading then
    return "--"
  end

  if normalized == "0" then
    return "0 EU"
  end

  local unitExponent = math.floor(exponent / 3) * 3
  local units = {
    [0] = "",
    [3] = "k",
    [6] = "M",
    [9] = "G",
    [12] = "T",
    [15] = "P",
    [18] = "E",
  }
  local unit = units[unitExponent]

  if not unit then
    return string.format(
      "%.3e EU",
      leading / (10 ^ (digits - 1)) * (10 ^ exponent)
    )
  end

  return string.format(
    "%.3g %sEU",
    leading / (10 ^ (digits - 1))
      * (10 ^ (exponent - unitExponent)),
    unit
  )
end

function format.amount(value, capacity)
  local text = format.number(value)

  if capacity then
    return text .. "/" .. format.number(capacity)
  end

  return text .. "/--"
end

return format
