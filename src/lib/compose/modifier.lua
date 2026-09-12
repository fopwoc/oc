local modifier = {}
local color = require("lib.compose.color")

local Modifier = {}

-- A modifier is a persistent chain: each step only records its parent and
-- one element, so building `Modifier:a():b():c()` is O(1) per call. The
-- flat `elements` list that layout and rendering read is materialized on
-- first access and cached on that modifier only.
local function materialize(self)
  local reversed = {}
  local current = self

  while current and current.element do
    reversed[#reversed + 1] = current.element
    current = current.parent
  end

  local elements = {}
  local count = #reversed

  for i = count, 1, -1 do
    elements[count - i + 1] = reversed[i]
  end

  rawset(self, "elements", elements)

  return elements
end

Modifier.__index = function(self, key)
  if key == "elements" then
    return materialize(self)
  end

  return Modifier[key]
end

local function append(self, element)
  return setmetatable({
    parent = self,
    element = element,
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

function Modifier:offset(x, y)
  assert(
    type(x) == "number"
      and type(y or 0) == "number",
    "offset requires numeric x and y values"
  )

  return append(self, {
    phase = "layout",
    type = "offset",
    x = x,
    y = y or 0,
  })
end

-- Draw

function Modifier:background(value)
  return append(self, {
    phase = "draw",
    type = "background",
    color = color.validate(value),
  })
end

function Modifier:foreground(value)
  return append(self, {
    phase = "draw",
    type = "foreground",
    color = color.validate(value),
  })
end

function Modifier:autoContrast(value)
  return append(self, {
    phase = "draw",
    type = "autoContrast",
    value = value ~= false,
  })
end

function Modifier:visible(value)
  return append(self, {
    phase = "visibility",
    type = "visible",
    value = value ~= false,
  })
end

function Modifier:scrim(value, alpha)
  return append(self, {
    phase = "draw",
    type = "scrim",
    color = color.create(value, alpha),
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

function Modifier:clickable(onClick, options)
  assert(
    type(onClick) == "function",
    "clickable() requires a function"
  )

  options = options or {}

  return append(self, {
    phase = "input",
    type = "clickable",
    onClick = onClick,
    onPress = options.onPress,
    onRelease = options.onRelease,
  })
end

function Modifier:draggable(onDrag, onDrop)
  assert(
    type(onDrag) == "function",
    "draggable() requires an onDrag function"
  )

  assert(
    onDrop == nil
      or type(onDrop) == "function",
    "draggable() onDrop must be a function"
  )

  return append(self, {
    phase = "input",
    type = "draggable",
    onDrag = onDrag,
    onDrop = onDrop,
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
