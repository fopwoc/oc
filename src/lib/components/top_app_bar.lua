local compose = require("lib.compose.init")
local button = require("lib.components.button")
local colorStyle = require("lib.components.color_style")

local topAppBar = {}

local function resolveNavigation(value, rootAction)
  if type(value) == "function" then
    return {
      label = "<",
      onClick = value,
    }
  end

  if type(value) ~= "table" then
    return nil
  end

  if
      type(value.canPop) == "function"
      and type(value.pop) == "function"
  then
    if not value:canPop() then
      if not rootAction then
        return nil
      end

      return {
        label = "X",
        color = "bad",
        onClick = rootAction,
      }
    end

    return {
      label = value.backLabel or "<",
      onClick = function()
        value:pop()
      end,
    }
  end

  if type(value.onClick) == "function" then
    return {
      label = value.label or "<",
      onClick = value.onClick,
    }
  end

  if rootAction then
    return {
      label = "X",
      color = "bad",
      onClick = rootAction,
    }
  end

  return nil
end

local function appendText(
    children,
    value,
    foreground,
    onClick,
    modifierValue
)
  if value == nil then
    return
  end

  local textModifier =
      modifierValue
      or compose.Modifier

  if foreground then
    textModifier =
        textModifier:foreground(foreground)
  end

  if onClick then
    textModifier =
        textModifier:clickable(onClick)
  end

  children[#children + 1] =
      compose.Text(
        tostring(value),
        textModifier
      )
end

local function appendSlot(children, slot, context)
  if slot == nil then
    return false
  end

  if type(slot) == "function" then
    slot = slot(context)
  end

  assert(
    type(slot) == "table",
    "TopAppBar actions must return a node or node list"
  )

  if slot.type then
    children[#children + 1] = slot
    return true
  end

  for _, child in ipairs(slot) do
    assert(
      type(child) == "table",
      "TopAppBar action list must contain nodes"
    )

    children[#children + 1] = child
  end

  return #slot > 0
end

function topAppBar.TopAppBar(options)
  assert(
    type(options) == "table",
    "TopAppBar requires an options table"
  )

  assert(
    options.title ~= nil,
    "TopAppBar requires a title"
  )

  local colors =
      (options.colorStyle or options.colors)
      and colorStyle.create(
        options.colorStyle or options.colors
      )
      or colorStyle.current()
  local children = {}
  local navigation = resolveNavigation(
    options.navigation,
    options.onRootAction
  )

  local navigationColor =
      navigation
      and (
        (navigation.color == "bad"
          or navigation.color == "danger")
        and colors.bad
        or colors.action
      )

  if navigation then
    children[#children + 1] =
        button.Button(
          navigation.label,
          navigation.onClick,
          compose.Modifier:foreground(
            navigationColor
          )
        )

    children[#children + 1] =
        compose.Spacer(
          compose.Modifier:width(1)
        )
  end

  appendText(
    children,
    options.title,
    colors.primary
  )

  children[#children + 1] =
      compose.Spacer(
        compose.Modifier:weight(1)
      )

  local hasActions = appendSlot(
    children,
    options.actions,
    options.context
  )

  if hasActions and options.trailing then
    children[#children + 1] =
        compose.Spacer(
          compose.Modifier:width(2)
        )
  end

  if options.trailing then
    local trailing = options.trailing

    if type(trailing) == "table" then
      appendText(
        children,
        trailing.label,
        trailing.color or colors.muted,
        trailing.onClick,
        trailing.modifier
      )
    else
      appendText(
        children,
        trailing,
        colors.muted
      )
    end
  end

  local barModifier =
      options.modifier
      or compose.Modifier

  barModifier =
      barModifier:fillMaxWidth()

  if options.background ~= nil then
    barModifier =
        barModifier:background(
          options.background
        )
  end

  return compose.Row(
    children,
    barModifier
  )
end

return topAppBar
