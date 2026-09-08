local compose = require("lib.compose.init")
local colorStyle = require("lib.components.color_style")

local progress = {}

local function clamp(value)
  return math.max(
    0,
    math.min(1, tonumber(value) or 0)
  )
end

local function tile(color, modifier)
  return compose.Box(
    {},
    modifier
    :fillMaxWidth()
    :fillMaxHeight()
    :background(color)
  )
end

function progress.Progress(options)
  assert(
    type(options) == "table",
    "Progress requires an options table"
  )

  local value = clamp(options.value)
  local orientation = options.orientation or "horizontal"
  local colors = colorStyle.current()

  assert(
    orientation == "horizontal"
      or orientation == "vertical",
    "Progress orientation must be horizontal or vertical"
  )

  local fillColor =
      options.fillColor
      or options.color
      or colors.primary

  local emptyColor =
      options.emptyColor
      or colors.surfaceVariant

  local tiles = {}

  if orientation == "vertical" then
    local height =
        options.height or 1

    local filledHeight =
        math.floor(height * value + 0.5)

    local emptyHeight =
        height - filledHeight

    if emptyHeight > 0 then
      tiles[#tiles + 1] =
          tile(
            emptyColor,
            compose.Modifier:height(emptyHeight)
          )
    end

    if filledHeight > 0 then
      tiles[#tiles + 1] =
          tile(
            fillColor,
            compose.Modifier:height(filledHeight)
          )
    end
  else
    if value > 0 then
      tiles[#tiles + 1] =
          tile(
            fillColor,
            compose.Modifier:weight(value)
          )
    end

    if value < 1 then
      tiles[#tiles + 1] =
          tile(
            emptyColor,
            compose.Modifier:weight(1 - value)
          )
    end
  end

  local track =
      orientation == "vertical"
      and compose.Column(
        tiles,
        compose.Modifier
        :fillMaxWidth()
        :fillMaxHeight()
      )
      or compose.Row(
        tiles,
        compose.Modifier
        :fillMaxWidth()
        :fillMaxHeight()
      )

  local children = {
    track,
  }

  if options.label ~= nil
      and options.label ~= false
  then
    local label = options.label

    if label == true then
      label =
          tostring(
            math.floor(value * 100 + 0.5)
          ) .. "%"
    end

    local labelModifier =
        compose.Modifier
        :align("center", "center")
        :foreground(
          options.labelColor
          or colors.onSurface
        )

    if options.labelContrast then
      labelModifier =
          labelModifier:autoContrast()
    end

    children[#children + 1] =
        compose.Text(
          tostring(label),
          labelModifier
        )
  end

  local modifier =
      options.modifier
      or compose.Modifier

  modifier =
      modifier:height(
        options.height or 1
      )

  if options.width then
    modifier =
        modifier:width(options.width)
  end

  return compose.Box(children, modifier)
end

return progress
