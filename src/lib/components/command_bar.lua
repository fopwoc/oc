local compose = require("lib.compose.init")
local colorStyle = require("lib.components.color_style")

local commandBar = {}

local function appendAction(children, action, colors)
  if action == nil then
    return
  end

  if type(action) == "string" then
    children[#children + 1] =
        compose.Text(
          action,
          compose.Modifier:foreground(
            colors.foreground
          )
        )

    return
  end

  assert(
    type(action) == "table"
      and type(action.label) == "string",
    "CommandBar action requires a label"
  )

  local actionModifier =
      action.modifier
      or compose.Modifier

  actionModifier =
      actionModifier:foreground(
        action.color or colors.action
      )

  if action.onClick then
    actionModifier =
        actionModifier:clickable(
          action.onClick
        )
  end

  children[#children + 1] =
      compose.Text(
        action.label,
        actionModifier
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
    "CommandBar actions must return a node or node list"
  )

  if slot.type then
    children[#children + 1] = slot
    return true
  end

  for _, child in ipairs(slot) do
    assert(
      type(child) == "table",
      "CommandBar action list must contain nodes"
    )

    children[#children + 1] = child
  end

  return #slot > 0
end

function commandBar.CommandBar(options)
  options = options or {}

  local colors =
      (options.colorStyle or options.colors)
      and colorStyle.create(
        options.colorStyle or options.colors
      )
      or colorStyle.current()
  local children = {}

  for _, action in ipairs(options.hints or {}) do
    appendAction(children, action, colors)

    children[#children + 1] =
        compose.Spacer(
          compose.Modifier:width(1)
        )
  end

  appendAction(children, options.service, colors)

  children[#children + 1] =
      compose.Spacer(
        compose.Modifier:weight(1)
      )

  local hasActions = appendSlot(
    children,
    options.actions,
    options.context
  )

  local trailing =
      options.trailing
      or {
        label = "q quit",
        color = colors.muted,
      }

  if hasActions and trailing then
    children[#children + 1] =
        compose.Spacer(
          compose.Modifier:width(2)
        )
  end

  appendAction(
    children,
    trailing,
    colors
  )

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

return commandBar
