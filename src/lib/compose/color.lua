local color = {}

local Color = {}
Color.__index = Color

local function validateRgb(rgb)
  assert(
    type(rgb) == "number"
      and rgb >= 0
      and rgb <= 0xFFFFFF
      and rgb == math.floor(rgb),
    "Color RGB value must be an integer from 0x000000 to 0xFFFFFF"
  )
end

local function validateAlpha(alpha)
  assert(
    type(alpha) == "number"
      and alpha >= 0
      and alpha <= 1,
    "Color alpha must be a number from 0 to 1"
  )
end

function color.create(rgb, alpha)
  if getmetatable(rgb) == Color then
    if alpha == nil then
      return rgb
    end

    rgb = rgb.rgb
  end

  validateRgb(rgb)

  if alpha == nil then
    alpha = 1
  end

  validateAlpha(alpha)

  return setmetatable({
    rgb = rgb,
    alpha = alpha,
  }, Color)
end

function color.resolve(value)
  if type(value) == "number" then
    validateRgb(value)
    return value, 1
  end

  assert(
    getmetatable(value) == Color,
    "Expected an RGB number or Compose Color"
  )

  return value.rgb, value.alpha
end

local function channel(rgb, shift)
  return math.floor(rgb / 2 ^ shift) % 0x100
end

local function pack(red, green, blue)
  return red * 0x10000
    + green * 0x100
    + blue
end

local function luminance(rgb)
  return
      channel(rgb, 16) * 299
      + channel(rgb, 8) * 587
      + channel(rgb, 0) * 114
end

function color.invert(value)
  local rgb =
      color.resolve(value)

  return pack(
    0xFF - channel(rgb, 16),
    0xFF - channel(rgb, 8),
    0xFF - channel(rgb, 0)
  )
end

function color.contrast(foreground, background)
  local backgroundRgb =
      color.blend(background, 0x000000)

  local resolvedForeground =
      color.blend(foreground, backgroundRgb)

  local preferredDistance =
      math.abs(
        luminance(resolvedForeground)
        - luminance(backgroundRgb)
      )

  if preferredDistance >= 96000 then
    return resolvedForeground
  end

  local inverted =
      color.invert(resolvedForeground)

  local invertedDistance =
      math.abs(
        luminance(inverted)
        - luminance(backgroundRgb)
      )

  if invertedDistance > preferredDistance then
    return inverted
  end

  return
      luminance(backgroundRgb) > 128000
      and 0x000000
      or 0xFFFFFF
end

function color.blend(source, destination)
  local sourceRgb, alpha = color.resolve(source)

  if alpha == 1 then
    return sourceRgb
  end

  if alpha == 0 then
    return destination
  end

  local destinationRgb = color.resolve(destination)
  local inverse = 1 - alpha

  local red = math.floor(
    channel(sourceRgb, 16) * alpha
      + channel(destinationRgb, 16) * inverse
      + 0.5
  )

  local green = math.floor(
    channel(sourceRgb, 8) * alpha
      + channel(destinationRgb, 8) * inverse
      + 0.5
  )

  local blue = math.floor(
    channel(sourceRgb, 0) * alpha
      + channel(destinationRgb, 0) * inverse
      + 0.5
  )

  return pack(red, green, blue)
end

return color
