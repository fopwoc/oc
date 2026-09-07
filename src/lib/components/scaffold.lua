local compose = require("lib.compose.init")
local dialog = require("lib.components.dialog")

local scaffold = {}

local function resolveSlot(slot, name, context)
  if type(slot) == "function" then
    slot = slot(context)
  end

  assert(
    type(slot) == "table",
    "Scaffold " .. name .. " slot must return a node"
  )

  return slot
end

local function resolveOptionalSlot(slot, name, context)
  if type(slot) == "function" then
    slot = slot(context)
  end

  if slot == nil then
    return nil
  end

  assert(
    type(slot) == "table",
    "Scaffold " .. name .. " slot must return a node"
  )

  return slot
end

function scaffold.Scaffold(options)
  assert(
    type(options) == "table",
    "Scaffold requires an options table"
  )

  assert(
    options.content ~= nil,
    "Scaffold requires a content slot"
  )

  local quitRequested =
      compose.remember(false)

  compose.setKeyHandler(function(item)
    if
        item.type ~= "keyDown"
        or (
          item.char ~= string.byte("q")
          and item.char ~= string.byte("Q")
        )
    then
      return false
    end

    if quitRequested.value then
      quitRequested.value = false
      return true
    end

    local navigation = options.navigation

    if
        navigation
        and type(navigation.canPop) == "function"
        and navigation:canPop()
    then
      navigation:pop()
    else
      quitRequested.value = true
    end

    return true
  end)

  local columnChildren = {}

  local slotContext = {
    requestQuit = function()
      quitRequested.value = true
    end,
  }

  if options.topBar then
    columnChildren[#columnChildren + 1] =
        resolveSlot(
          options.topBar,
          "topBar",
          slotContext
        )
  end

  local content =
      resolveSlot(options.content, "content")

  columnChildren[#columnChildren + 1] =
      compose.Box(
        {content},
        compose.Modifier
        :fillMaxWidth()
        :fillMaxHeight()
        :weight(1)
      )

  if options.bottomBar then
    columnChildren[#columnChildren + 1] =
        resolveSlot(options.bottomBar, "bottomBar")
  end

  local column =
      compose.Column(
        columnChildren,
        compose.Modifier
        :fillMaxWidth()
        :fillMaxHeight()
      )

  local children = {column}

  local overlay =
      resolveOptionalSlot(
        options.overlay,
        "overlay",
        slotContext
      )

  if quitRequested.value then
    overlay =
        dialog.Dialog(
          "QUIT",
          {
            compose.Text("Exit application?"),

            compose.Spacer(
              compose.Modifier:height(1)
            ),

            compose.Row({
              compose.Text(
                "[ YES ]",
                compose.Modifier
                :foreground(0xDD6666)
                :clickable(function()
                  compose.quit()
                end)
              ),

              compose.Spacer(
                compose.Modifier:width(2)
              ),

              compose.Text(
                "[ NO ]",
                compose.Modifier
                :foreground(0x66CC88)
                :clickable(function()
                  quitRequested.value = false
                end)
              ),
            }),
          },
          compose.Modifier
          :width(28)
          :background(0x222222)
        )
  end

  if overlay then
    children[#children + 1] =
        overlay
  end

  local rootModifier =
      options.modifier
      or compose.Modifier

  rootModifier =
      rootModifier
      :fillMaxWidth()
      :fillMaxHeight()

  if options.background ~= nil then
    rootModifier =
        rootModifier:background(
          options.background
        )
  end

  return compose.Box(
    children,
    rootModifier
  )
end

return scaffold
