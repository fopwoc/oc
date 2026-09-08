local colorStyle = {}

local DEFAULT_COLORS = {
  background = 0x101418,
  surface = 0x1A2228,
  surfaceVariant = 0x26313A,

  foreground = 0xE2E8F0,
  text = 0xE2E8F0,
  onBackground = 0xE2E8F0,
  onSurface = 0xE2E8F0,

  muted = 0x8B96A3,
  border = 0x36414A,

  primary = 0x6BD5FF,
  action = 0x6BD5FF,
  onPrimary = 0x101418,
  primaryContainer = 0x245A73,
  onPrimaryContainer = 0xFFFFFF,

  good = 0x66CC88,
  onGood = 0x101418,
  goodContainer = 0x245A3E,
  onGoodContainer = 0xD9FFE7,

  success = 0x66CC88,
  warning = 0xE5C36A,
  bad = 0xE06C75,
  onBad = 0x101418,
  badContainer = 0x5A2930,
  onBadContainer = 0xFFE4E6,

  danger = 0xE06C75,

  scrim = 0x000000,
  scrimAlpha = 0.55,
}

local active = nil

local function copyDefaults(overrides)
  local result = {}

  for key, value in pairs(DEFAULT_COLORS) do
    result[key] = value
  end

  for key, value in pairs(overrides or {}) do
    result[key] = value
  end

  if overrides then
    if overrides.text ~= nil
        and overrides.foreground == nil
    then
      result.foreground = overrides.text
    end

    if overrides.foreground ~= nil
        and overrides.text == nil
    then
      result.text = overrides.foreground
    end

    local text =
        overrides.text
        or overrides.foreground

    if text ~= nil then
      if overrides.onBackground == nil then
        result.onBackground = text
      end

      if overrides.onSurface == nil then
        result.onSurface = text
      end
    end

    if overrides.primary ~= nil
        and overrides.action == nil
    then
      result.action = overrides.primary
    end

    if overrides.action ~= nil
        and overrides.primary == nil
    then
      result.primary = overrides.action
    end

    if overrides.good ~= nil
        and overrides.success == nil
    then
      result.success = overrides.good
    end

    if overrides.success ~= nil
        and overrides.good == nil
    then
      result.good = overrides.success
    end

    if overrides.bad ~= nil
        and overrides.danger == nil
    then
      result.danger = overrides.bad
    end

    if overrides.danger ~= nil
        and overrides.bad == nil
    then
      result.bad = overrides.danger
    end
  end

  return result
end

function colorStyle.create(colors)
  assert(
    colors == nil
      or type(colors) == "table",
    "ColorStyle requires a table"
  )

  return copyDefaults(colors)
end

function colorStyle.ColorStyle(colors)
  return colorStyle.create(colors)
end

function colorStyle.defaults()
  return colorStyle.create()
end

function colorStyle.current()
  return active
      or DEFAULT_COLORS
end

function colorStyle.with(colors, content)
  assert(
    type(colors) == "table",
    "ColorStyle.with requires a style table"
  )

  assert(
    type(content) == "function",
    "ColorStyle.with requires a content function"
  )

  local previous = active
  active = colors

  local ok, result = pcall(content)

  active = previous

  if not ok then
    error(result, 0)
  end

  return result
end

return colorStyle
