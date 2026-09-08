local decimal = {}

local function normalized(value)
  if type(value) ~= "string" then
    return nil
  end

  value = value:gsub("^%s+", ""):gsub("%s+$", "")

  if not value:match("^%d+$") then
    return nil
  end

  value = value:gsub("^0+", "")

  return value == "" and "0" or value
end

local function scientific(value)
  value = normalized(value)

  if not value then
    return nil
  end

  if value == "0" then
    return 0, 0
  end

  local digits = math.min(#value, 15)
  local leading = tonumber(value:sub(1, digits))

  return leading / (10 ^ (digits - 1)), #value - 1
end

function decimal.normalize(value)
  return normalized(value)
end

function decimal.approx(value)
  local coefficient, exponent = scientific(value)

  if not coefficient then
    return nil
  end

  if coefficient == 0 then
    return 0
  end

  return coefficient * (10 ^ exponent)
end

function decimal.ratio(numerator, denominator)
  local numeratorCoefficient, numeratorExponent =
      scientific(numerator)
  local denominatorCoefficient, denominatorExponent =
      scientific(denominator)

  if not numeratorCoefficient
      or not denominatorCoefficient
      or denominatorCoefficient == 0
  then
    return nil
  end

  return numeratorCoefficient
      / denominatorCoefficient
      * (10 ^ (numeratorExponent - denominatorExponent))
end

function decimal.compact(value, suffix)
  local coefficient, exponent = scientific(value)

  if not coefficient then
    return "--"
  end

  if coefficient == 0 then
    return "0" .. (suffix or "")
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

  if not units[unitExponent] then
    return string.format(
      "%.3e%s",
      coefficient * (10 ^ exponent),
      suffix or ""
    )
  end

  local scaled = coefficient * (10 ^ (exponent - unitExponent))

  return string.format(
    "%.3g %s%s",
    scaled,
    units[unitExponent],
    suffix or ""
  )
end

return decimal
