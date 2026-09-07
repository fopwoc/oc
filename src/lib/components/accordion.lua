local compose = require("lib.compose.init")

local accordion = {}

function accordion.Accordion(options)
  assert(
    type(options) == "table",
    "Accordion requires an options table"
  )

  assert(
    type(options.title) == "string",
    "Accordion requires a title"
  )

  assert(
    type(options.content) == "function",
    "Accordion requires a content function"
  )

  local expandedState

  if options.expanded == nil then
    expandedState =
        compose.remember(options.initiallyExpanded == true)
  end

  local expanded =
      options.expanded ~= nil
      and options.expanded == true
      or expandedState
      and expandedState.value
      or false

  local function setExpanded(value)
    if expandedState then
      expandedState.value = value
    end

    if options.onExpandedChange then
      options.onExpandedChange(value)
    end
  end

  local headerModifier =
      options.headerModifier
      or compose.Modifier

  local header =
      compose.Row({
        compose.Text(
          (expanded and "^ " or "v ")
          .. options.title
        ),

        compose.Spacer(
          compose.Modifier:weight(1)
        ),

        compose.Text(
          expanded and "^" or "v"
        ),
      },
      headerModifier
      :fillMaxWidth()
      :clickable(function()
        setExpanded(not expanded)
      end))

  local children = {header}

  if expanded then
    local content =
        compose.RecomposeScope(
          options.key
          or "accordion:" .. options.title,
          function()
            local node = options.content()

            assert(
              type(node) == "table",
              "Accordion content must return a node"
            )

            return node
          end
        )

    children[#children + 1] = content
  end

  return compose.Column(
    children,
    options.modifier
  )
end

return accordion
