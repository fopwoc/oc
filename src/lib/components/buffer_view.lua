local compose = require("lib.compose.init")
local colorStyle = require("lib.components.color_style")

local bufferView = {}

local function defaultItem(value)
  return compose.Text(
    value,
    compose.Modifier:foreground(
      colorStyle.current().foreground
    )
  )
end

function bufferView.BufferView(options)
  assert(
    type(options) == "table",
    "BufferView requires an options table"
  )

  assert(
    type(options.buffer) == "table"
      and type(options.buffer.iter) == "function"
      and type(options.buffer.subscribe) == "function",
    "BufferView requires a RingBuffer"
  )

  local renderItem =
      options.item
      or defaultItem

  assert(
    type(renderItem) == "function",
    "BufferView item must be a function"
  )

  local scrollState =
      compose.rememberScrollState()

  local initialized =
      compose.remember(false)

  if not initialized.value then
    scrollState:followEnd()
    initialized.value = true
  end

  local revision =
      compose.remember(0)

  compose.DisposableEffect(
    "buffer-view-subscription",
    function()
      return options.buffer:subscribe(function()
        local wasAtEnd =
            scrollState:isAtEnd()

        revision.value = revision.value + 1

        if wasAtEnd then
          scrollState:followEnd()
        end
      end)
    end
  )

  local _ = revision.value

  local children = {}

  for index, value in options.buffer:iter() do
    local node =
        renderItem(value, index)

    assert(
      type(node) == "table",
      "BufferView item must return a node"
    )

    children[#children + 1] = node
  end

  if #children == 0 and options.empty ~= nil then
    if type(options.empty) == "function" then
      children[#children + 1] = options.empty()
    else
      children[#children + 1] = compose.Text(
        options.empty,
        compose.Modifier:foreground(
          colorStyle.current().muted
        )
      )
    end
  end

  local modifier =
      options.modifier
      or compose.Modifier

  return compose.Column(
    children,
    modifier:verticalScroll(scrollState)
  )
end

return bufferView
