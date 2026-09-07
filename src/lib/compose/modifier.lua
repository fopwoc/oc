local modifier = {}

local Modifier = {}
Modifier.__index = Modifier

local function append(self, element)
  local elements = {}

  for i, value in ipairs(self.elements) do
    elements[i] = value
  end

  elements[#elements + 1] = element

  return setmetatable({
    elements = elements,
  }, Modifier)
end

-- Layout

function Modifier:padding(left, top, right, bottom)
  if top == nil then
    top = left
    right = left
    bottom = left
  elseif right == nil then
    right = left
    bottom = top
  end

  return append(self, {
    phase = "layout",
    type = "padding",

    left = left or 0,
    top = top or 0,
    right = right or 0,
    bottom = bottom or 0,
  })
end

function Modifier:width(value)
  return append(self, {
    phase = "layout",
    type = "width",
    value = value,
  })
end

function Modifier:height(value)
  return append(self, {
    phase = "layout",
    type = "height",
    value = value,
  })
end

function Modifier:fillMaxWidth()
  return append(self, {
    phase = "layout",
    type = "fillMaxWidth",
  })
end

function Modifier:fillMaxHeight()
  return append(self, {
    phase = "layout",
    type = "fillMaxHeight",
  })
end

function Modifier:weight(value)
  value = value or 1

  assert(
    type(value) == "number"
    and value > 0,
    "weight must be greater than 0"
  )

  return append(self, {
    phase = "layout",
    type = "weight",
    value = value,
  })
end

function Modifier:align(
    horizontal,
    vertical
)
  assert(
    horizontal == nil
    or horizontal == "left"
    or horizontal == "center"
    or horizontal == "right",
    "align horizontal must be left, center, or right"
  )

  assert(
    vertical == nil
    or vertical == "top"
    or vertical == "center"
    or vertical == "bottom",
    "align vertical must be top, center, or bottom"
  )

  return append(self, {
    phase = "layout",
    type = "align",
    horizontal = horizontal,
    vertical = vertical,
  })
end

-- Draw

function Modifier:background(color)
  return append(self, {
    phase = "draw",
    type = "background",
    color = color,
  })
end

function Modifier:foreground(color)
  return append(self, {
    phase = "draw",
    type = "foreground",
    color = color,
  })
end

local DEFAULT_BORDER_CHARACTERS = {
  topLeft = "┌",
  top = "─",
  topRight = "┐",
  right = "│",
  bottomRight = "┘",
  bottom = "─",
  bottomLeft = "└",
  left = "│",
}

local function normalizeBorderCharacters(
    characters
)
  if characters == nil then
    return DEFAULT_BORDER_CHARACTERS
  end

  if type(characters) == "string" then
    return {
      topLeft = characters,
      top = characters,
      topRight = characters,
      right = characters,
      bottomRight = characters,
      bottom = characters,
      bottomLeft = characters,
      left = characters,
    }
  end

  assert(
    type(characters) == "table",
    "border characters must be a string or table"
  )

  return {
    topLeft =
        characters.topLeft
        or DEFAULT_BORDER_CHARACTERS.topLeft,

    top =
        characters.top
        or DEFAULT_BORDER_CHARACTERS.top,

    topRight =
        characters.topRight
        or DEFAULT_BORDER_CHARACTERS.topRight,

    right =
        characters.right
        or DEFAULT_BORDER_CHARACTERS.right,

    bottomRight =
        characters.bottomRight
        or DEFAULT_BORDER_CHARACTERS.bottomRight,

    bottom =
        characters.bottom
        or DEFAULT_BORDER_CHARACTERS.bottom,

    bottomLeft =
        characters.bottomLeft
        or DEFAULT_BORDER_CHARACTERS.bottomLeft,

    left =
        characters.left
        or DEFAULT_BORDER_CHARACTERS.left,
  }
end

function Modifier:border(
    color,
    characters
)
  return append(self, {
    phase = "border",
    type = "border",

    color = color,
    characters =
        normalizeBorderCharacters(
          characters
        ),
  })
end

-- Input

function Modifier:clickable(onClick)
  assert(
    type(onClick) == "function",
    "clickable() requires a function"
  )

  return append(self, {
    phase = "input",
    type = "clickable",
    onClick = onClick,
  })
end

function Modifier:scrollable(onScroll)
  assert(
    type(onScroll) == "function",
    "scrollable() requires a function"
  )

  return append(self, {
    phase = "input",
    type = "scrollable",
    onScroll = onScroll,
  })
end

function Modifier:verticalScroll(state)
  assert(
    type(state) == "table",
    "verticalScroll requires ScrollState"
  )

  assert(
    type(state.scrollBy) == "function",
    "verticalScroll requires ScrollState"
  )

  return append(self, {
    phase = "input",
    type = "verticalScroll",
    state = state,

    onScroll = function(direction)
      state:scrollBy(-direction)
    end,
  })
end

modifier.Modifier = setmetatable({
  elements = {},
}, Modifier)

return modifier
