local compose = require("lib.compose.init")
local colorStyle = require("lib.components.color_style")
local format = require("lib.utils.format")

local grid = {}

function grid.GridCells(colors)
  assert(
    type(colors) == "table",
    "Grid cells require colors"
  )

  local instance = {}

  function instance:colored(value, color)
    return {
      text = tostring(value),
      color = color,
    }
  end

  function instance:number(value, color)
    return self:colored(
      format.number(value),
      color or colors.text
    )
  end

  function instance.render(value, row)
    if type(value) == "table" then
      return compose.Text(
        value.text,
        compose.Modifier:foreground(
          value.color or colors.text
        )
      )
    end

    return compose.Text(
      tostring(value or ""),
      compose.Modifier:foreground(
        row == 1
        and colors.primary
        or colors.text
      )
    )
  end

  return instance
end

local function sharedBorderCharacters(
    row,
    rowCount,
    column,
    columnCount
)
  local firstRow = row == 1
  local lastRow = row == rowCount
  local firstColumn = column == 1
  local lastColumn = column == columnCount

  return {
    topLeft =
        firstRow
        and (firstColumn and "┌" or "┬")
        or "│",

    top = firstRow and "─" or "",

    topRight =
        firstRow
        and (lastColumn and "┐" or "─")
        or (lastColumn and "│" or ""),

    left = "│",
    right = lastColumn and "│" or "",

    bottomRight =
        lastRow
        and (lastColumn and "┘" or "─")
        or (lastColumn and "┤" or "─"),

    bottom = "─",

    bottomLeft =
        lastRow
        and (firstColumn and "└" or "┴")
        or (firstColumn and "├" or "┼"),
  }
end

local function countColumns(rows)
  local columns = 0

  for _, row in ipairs(rows) do
    columns = math.max(columns, #row)
  end

  return columns
end

local function resolveCell(options, value, row, column, colors)
  if options.cell then
    local node = options.cell(value, row, column)

    assert(
      type(node) == "table",
      "Grid cell function must return a node"
    )

    return node
  end

  if value == nil then
    return compose.Spacer()
  end

  if type(value) == "table" then
    return value
  end

  return compose.Text(
    tostring(value),
    compose.Modifier:foreground(colors.onSurface)
  )
end

function grid.Grid(options)
  assert(
    type(options) == "table",
    "Grid requires an options table"
  )

  assert(
    type(options.rows) == "table"
      and #options.rows > 0,
    "Grid requires a non-empty rows table"
  )

  local appearance =
      options.appearance
      or "none"

  assert(
    appearance == "border"
      or appearance == "alternating"
      or appearance == "none",
    "Grid appearance must be border, alternating, or none"
  )

  local columns =
      options.columns
      or countColumns(options.rows)

  local colors = colorStyle.current()

  local specifications = {}

  if type(columns) == "table" then
    for index, specification in ipairs(columns) do
      assert(
        type(specification) == "table",
        "Grid column specification must be a table"
      )

      specifications[index] = specification
    end

    columns = #specifications
  else
    assert(
      type(columns) == "number",
      "Grid columns must be a number or specification table"
    )

    for index = 1, columns do
      specifications[index] = {
        weight =
            options.columnWeights
            and options.columnWeights[index]
            or 1,
      }
    end
  end

  assert(
    type(columns) == "number"
      and columns > 0
      and columns == math.floor(columns),
    "Grid columns must be a positive integer"
  )

  local rows = {}
  local cellPadding = options.cellPadding or 0
  local horizontalCellPadding =
      options.horizontalCellPadding

  if horizontalCellPadding ~= nil then
    assert(
      type(horizontalCellPadding) == "number"
        and horizontalCellPadding >= 0,
      "Grid horizontalCellPadding must be non-negative"
    )
  end

  for rowIndex, values in ipairs(options.rows) do
    assert(
      type(values) == "table",
      "Grid row must be a table"
    )

    local cells = {}

    for columnIndex = 1, columns do
      local specification =
          specifications[columnIndex]

      local cellModifier = compose.Modifier

      if options.cellModifier then
        cellModifier = options.cellModifier(
          cellModifier,
          rowIndex,
          columnIndex,
          values[columnIndex]
        )

        assert(
          type(cellModifier) == "table",
          "Grid cellModifier must return a modifier"
        )
      end

      if specification.width then
        cellModifier =
            cellModifier:width(
              specification.width
            )
      else
        cellModifier =
            cellModifier:weight(
              specification.weight
              or 1
            )
      end

      if appearance == "border" then
        cellModifier =
            cellModifier:border(
              options.borderColor
              or colors.border,
              options.borderCharacters
              or sharedBorderCharacters(
                rowIndex,
                #options.rows,
                columnIndex,
                columns
              )
            )
      elseif appearance == "alternating" then
        local background =
            options.cellBackground
            or (
              rowIndex % 2 == 0
              and colors.surfaceVariant
              or colors.surface
            )

        background =
            rowIndex % 2 == 0
            and (
              options.evenBackground
              or background
            )
            or (
              options.oddBackground
              or background
            )

        cellModifier =
            cellModifier:background(
              background
            )
      end

      if horizontalCellPadding ~= nil then
        cellModifier = cellModifier:padding(
          horizontalCellPadding,
          0
        )
      else
        cellModifier = cellModifier:padding(cellPadding)
      end

      local alignment =
          specification.align
          or options.align
          or "left"

      assert(
        alignment == "left"
          or alignment == "center"
          or alignment == "right",
        "Grid alignment must be left, center, or right"
      )

          local cell =
          resolveCell(
            options,
            values[columnIndex],
            rowIndex,
            columnIndex,
            colors
          )

      local alignedChildren = {}

      if alignment ~= "left" then
        alignedChildren[#alignedChildren + 1] =
            compose.Spacer(
              compose.Modifier:weight(1)
            )
      end

      alignedChildren[#alignedChildren + 1] = cell

      if alignment ~= "right" then
        alignedChildren[#alignedChildren + 1] =
            compose.Spacer(
              compose.Modifier:weight(1)
            )
      end

      cells[#cells + 1] =
          compose.Box(
            {
              compose.Row(
                alignedChildren,
                compose.Modifier:fillMaxWidth()
              ),
            },
            cellModifier
          )
    end

    rows[#rows + 1] =
        compose.Row(
          cells,
          compose.Modifier:fillMaxWidth()
        )
  end

  return compose.Column(
    rows,
    options.modifier
    or compose.Modifier
  )
end

return grid
