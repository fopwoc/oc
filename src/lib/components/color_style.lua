local colorStyle = {}

local DEFAULT_COLORS = {
  background = 0x080D10,
  surface = 0x11191E,
  surfaceVariant = 0x1B272D,

  foreground = 0xDDE7E7,
  text = 0xDDE7E7,
  onBackground = 0xDDE7E7,
  onSurface = 0xDDE7E7,

  muted = 0x7F8E93,
  border = 0x2D3B40,

  primary = 0x5ED7CF,
  action = 0x5ED7CF,
  onPrimary = 0x080D10,
  primaryContainer = 0x174A48,
  onPrimaryContainer = 0xD9FFFB,

  good = 0x73D58C,
  onGood = 0x080D10,
  goodContainer = 0x1C4930,
  onGoodContainer = 0xDEFFE7,

  success = 0x73D58C,
  warning = 0xE0B96A,
  bad = 0xE77779,
  onBad = 0x080D10,
  badContainer = 0x51272B,
  onBadContainer = 0xFFE3E3,

  danger = 0xE77779,

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
