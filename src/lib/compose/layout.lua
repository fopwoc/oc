local unicode = require("unicode")

local layout = {}

local function clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end

  if value > maxValue then
    return maxValue
  end

  return value
end

local function copyConstraints(constraints)
  return {
    minWidth = constraints.minWidth or 0,
    maxWidth = constraints.maxWidth or math.huge,
    minHeight = constraints.minHeight or 0,
    maxHeight = constraints.maxHeight or math.huge,
  }
end

local function applyLayoutModifiers(node, constraints)
  local result = copyConstraints(constraints)

  if not node.modifier then
    return result
  end

  for _, element in ipairs(node.modifier.elements or {}) do
    if element.phase == "layout" then
      if element.type == "width" then
        result.minWidth = element.value
        result.maxWidth = element.value
      elseif element.type == "height" then
        result.minHeight = element.value
        result.maxHeight = element.value
      elseif element.type == "fillMaxWidth" then
        if result.maxWidth ~= math.huge then
          result.minWidth = result.maxWidth
        end
      elseif element.type == "fillMaxHeight" then
        if result.maxHeight ~= math.huge then
          result.minHeight = result.maxHeight
        end
      end
    end
  end

  return result
end

local function getPadding(node)
  local left = 0
  local top = 0
  local right = 0
  local bottom = 0

  if not node.modifier then
    return left, top, right, bottom
  end

  for _, element in ipairs(node.modifier.elements or {}) do
    if
        element.phase == "layout"
        and element.type == "padding"
    then
      left = left + element.left
      top = top + element.top
      right = right + element.right
      bottom = bottom + element.bottom
    end
  end

  return left, top, right, bottom
end

local function getBorderInsets(node)
  if not node.modifier then
    return 0, 0, 0, 0
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if
        element.phase == "border"
        and element.type == "border"
    then
      return 1, 1, 1, 1
    end
  end

  return 0, 0, 0, 0
end

local function getVerticalScroll(node)
  if not node.modifier then
    return nil
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if
        element.phase == "input"
        and element.type == "verticalScroll"
    then
      return element
    end
  end

  return nil
end

local function getAlignment(node)
  if not node.modifier then
    return nil, nil
  end

  local horizontal = nil
  local vertical = nil

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if
        element.phase == "layout"
        and element.type == "align"
    then
      horizontal =
          element.horizontal

      vertical =
          element.vertical
    end
  end

  return horizontal, vertical
end

local function getWeight(node)
  if not node.modifier then
    return nil
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if
        element.phase == "layout"
        and element.type == "weight"
    then
      return element.value
    end
  end

  return nil
end

local measureNode

local function measureText(node, constraints)
  local text =
      tostring(node.props.text or "")

  local width =
      unicode.wlen(text)

  return
      math.max(
        constraints.minWidth,
        math.min(
          constraints.maxWidth,
          width
        )
      ),
      math.max(
        constraints.minHeight,
        math.min(
          constraints.maxHeight,
          1
        )
      ),
      {}
end

local function measureProgress(node, constraints)
  local width

  if constraints.maxWidth == math.huge then
    width = 10
  else
    width = constraints.maxWidth
  end

  width = clamp(
    width,
    constraints.minWidth,
    constraints.maxWidth
  )

  local height = clamp(
    1,
    constraints.minHeight,
    constraints.maxHeight
  )

  return width, height, {}
end

local function measureColumn(
    node,
    constraints
)
  local source =
      node.props.children or {}

  local children = {}

  local fixedHeight = 0
  local totalWeight = 0
  local width = 0

  local verticalScroll =
      getVerticalScroll(node)

  -- В scrollable Column weight не имеет конечного
  -- viewport-space для распределения.
  local useWeight =
      not verticalScroll

  for index, child in ipairs(source) do
    local weight =
        useWeight
        and getWeight(child)
        or nil

    if weight then
      totalWeight =
          totalWeight + weight

      children[index] = {
        node = child,
        weight = weight,
      }
    else
      local childMaxHeight

      if verticalScroll then
        childMaxHeight =
            math.huge
      elseif constraints.maxHeight
          == math.huge
      then
        childMaxHeight =
            math.huge
      else
        childMaxHeight =
            math.max(
              0,
              constraints.maxHeight
              - fixedHeight
            )
      end

      local measured =
          measureNode(
            child,
            {
              minWidth = 0,
              maxWidth =
                  constraints.maxWidth,

              minHeight = 0,
              maxHeight =
                  childMaxHeight,
            }
          )

      children[index] =
          measured

      fixedHeight =
          fixedHeight + measured.height

      width =
          math.max(
            width,
            measured.width
          )
    end
  end

  local remainingHeight = 0

  if totalWeight > 0 then
    local availableHeight

    if constraints.maxHeight == math.huge then
      availableHeight =
          constraints.minHeight
    else
      availableHeight =
          constraints.maxHeight
    end

    remainingHeight =
        math.max(
          0,
          availableHeight - fixedHeight
        )

    local remainingWeight =
        totalWeight

    local remainingWeightedHeight =
        remainingHeight

    for index, child in ipairs(source) do
      local weight =
          getWeight(child)

      if weight then
        local allocated = 0

        if remainingWeight > 0 then
          allocated =
              math.floor(
                remainingWeightedHeight
                * weight
                / remainingWeight
              )
        end

        local measured =
            measureNode(
              child,
              {
                minWidth = 0,
                maxWidth =
                    constraints.maxWidth,

                minHeight = allocated,
                maxHeight = allocated,
              }
            )

        children[index] =
            measured

        width =
            math.max(
              width,
              measured.width
            )

        remainingWeightedHeight =
            remainingWeightedHeight
            - allocated

        remainingWeight =
            remainingWeight
            - weight
      end
    end
  end

  width =
      clamp(
        width,
        constraints.minWidth,
        constraints.maxWidth
      )

  local contentHeight =
      fixedHeight + remainingHeight

  if totalWeight == 0 then
    contentHeight =
        fixedHeight
  end

  local height =
      clamp(
        contentHeight,
        constraints.minHeight,
        constraints.maxHeight
      )

  local y = 0

  for _, child in ipairs(children) do
    child.x = 0
    child.y = y

    y =
        y + child.height
  end

  -- Column владеет горизонтальной осью.
  for _, child in ipairs(children) do
    local horizontal =
        getAlignment(child.node)

    if horizontal == "center" then
      child.x =
          math.floor(
            (width - child.width) / 2
          )
    elseif horizontal == "right" then
      child.x =
          width - child.width
    end
  end

  if verticalScroll then
    local state =
        verticalScroll.state

    local maxValue =
        math.max(
          0,
          contentHeight - height
        )

    state:setMaxValue(maxValue)

    local offset =
        state:getValue()

    for _, child in ipairs(children) do
      child.y =
          child.y - offset
    end
  end

  return
      width,
      height,
      children
end

local function measureRow(
    node,
    constraints
)
  local source =
      node.props.children or {}

  local children = {}
  local fixedWidth = 0
  local totalWeight = 0
  local height = 0

  -- Сначала измеряем обычных детей.
  -- Weighted пока только считаем.
  for index, child in ipairs(source) do
    local weight =
        getWeight(child)

    if weight then
      totalWeight =
          totalWeight + weight

      children[index] = {
        node = child,
        weight = weight,
      }
    else
      local remainingWidth

      if constraints.maxWidth == math.huge then
        remainingWidth =
            math.huge
      else
        remainingWidth =
            math.max(
              0,
              constraints.maxWidth
              - fixedWidth
            )
      end

      local measured =
          measureNode(
            child,
            {
              minWidth = 0,
              maxWidth =
                  remainingWidth,

              minHeight = 0,
              maxHeight =
                  constraints.maxHeight,
            }
          )

      children[index] =
          measured

      fixedWidth =
          fixedWidth + measured.width

      height =
          math.max(
            height,
            measured.height
          )
    end
  end

  local availableWidth

  if constraints.maxWidth == math.huge then
    availableWidth =
        constraints.minWidth
  else
    availableWidth =
        constraints.maxWidth
  end

  local remainingWidth =
      math.max(
        0,
        availableWidth - fixedWidth
      )

  -- Теперь weighted дети получают свою долю.
  local remainingWeight =
      totalWeight

  local remainingWeightedWidth =
      remainingWidth

  for index, child in ipairs(source) do
    local weight =
        getWeight(child)

    if weight then
      local allocated = 0

      if remainingWeight > 0 then
        allocated =
            math.floor(
              remainingWeightedWidth
              * weight
              / remainingWeight
            )
      end

      local measured =
          measureNode(
            child,
            {
              minWidth = allocated,
              maxWidth = allocated,

              minHeight = 0,
              maxHeight =
                  constraints.maxHeight,
            }
          )

      children[index] =
          measured

      height =
          math.max(
            height,
            measured.height
          )

      remainingWeightedWidth =
          remainingWeightedWidth
          - allocated

      remainingWeight =
          remainingWeight
          - weight
    end
  end

  local width =
      fixedWidth + remainingWidth

  if totalWeight == 0 then
    width =
        fixedWidth
  end

  width =
      clamp(
        width,
        constraints.minWidth,
        constraints.maxWidth
      )

  height =
      clamp(
        height,
        constraints.minHeight,
        constraints.maxHeight
      )

  local x = 0

  for _, child in ipairs(children) do
    child.x = x
    child.y = 0

    x =
        x + child.width
  end

  -- Row владеет вертикальной осью.
  for _, child in ipairs(children) do
    local _, vertical =
        getAlignment(child.node)

    if vertical == "center" then
      child.y =
          math.floor(
            (height - child.height) / 2
          )
    elseif vertical == "bottom" then
      child.y =
          height - child.height
    end
  end

  return
      width,
      height,
      children
end

local function measureBox(
    node,
    constraints
)
  local children = {}

  local width = 0
  local height = 0

  for _, child in ipairs(
    node.props.children or {}
  ) do
    local measured =
        measureNode(
          child,
          {
            minWidth = 0,
            maxWidth =
                constraints.maxWidth,

            minHeight = 0,
            maxHeight =
                constraints.maxHeight,
          }
        )

    measured.x = 0
    measured.y = 0

    children[#children + 1] =
        measured

    width =
        math.max(
          width,
          measured.width
        )

    height =
        math.max(
          height,
          measured.height
        )
  end

  width =
      clamp(
        width,
        constraints.minWidth,
        constraints.maxWidth
      )

  height =
      clamp(
        height,
        constraints.minHeight,
        constraints.maxHeight
      )

  for _, child in ipairs(children) do
    local horizontal, vertical =
        getAlignment(child.node)

    if horizontal == "center" then
      child.x =
          math.floor(
            (width - child.width) / 2
          )
    elseif horizontal == "right" then
      child.x =
          width - child.width
    end

    if vertical == "center" then
      child.y =
          math.floor(
            (height - child.height) / 2
          )
    elseif vertical == "bottom" then
      child.y =
          height - child.height
    end
  end

  return width, height, children
end

local function measureSpacer(
    node,
    constraints
)
  return
      constraints.minWidth,
      constraints.minHeight,
      {}
end

measureNode = function(node, constraints)
  constraints = applyLayoutModifiers(
    node,
    constraints
  )

  local paddingLeft,
  paddingTop,
  paddingRight,
  paddingBottom =
      getPadding(node)

  local borderLeft,
  borderTop,
  borderRight,
  borderBottom =
      getBorderInsets(node)

  local left =
      paddingLeft + borderLeft

  local top =
      paddingTop + borderTop

  local right =
      paddingRight + borderRight

  local bottom =
      paddingBottom + borderBottom

  local innerConstraints = {
    minWidth = math.max(
      0,
      constraints.minWidth - left - right
    ),

    maxWidth = math.max(
      0,
      constraints.maxWidth - left - right
    ),

    minHeight = math.max(
      0,
      constraints.minHeight - top - bottom
    ),

    maxHeight = math.max(
      0,
      constraints.maxHeight - top - bottom
    ),
  }

  local width
  local height
  local children

  if node.type == "text" then
    width, height, children =
        measureText(node, innerConstraints)
  elseif node.type == "progress" then
    width, height, children =
        measureProgress(node, innerConstraints)
  elseif node.type == "column" then
    width, height, children =
        measureColumn(node, innerConstraints)
  elseif node.type == "row" then
    width, height, children =
        measureRow(node, innerConstraints)
  elseif node.type == "spacer" then
    width, height, children =
        measureSpacer(
          node,
          innerConstraints
        )
  elseif node.type == "box" then
    width, height, children =
        measureBox(
          node,
          innerConstraints
        )
  else
    width = 0
    height = 0
    children = {}
  end

  width = width + left + right
  height = height + top + bottom

  width = clamp(
    width,
    constraints.minWidth,
    constraints.maxWidth
  )

  height = clamp(
    height,
    constraints.minHeight,
    constraints.maxHeight
  )

  for _, child in ipairs(children) do
    child.x = child.x + left
    child.y = child.y + top
  end

  return {
    node = node,

    x = 0,
    y = 0,

    width = width,
    height = height,

    contentX = left,
    contentY = top,
    contentWidth = math.max(
      0,
      width - left - right
    ),
    contentHeight = math.max(
      0,
      height - top - bottom
    ),

    children = children,
  }
end

function layout.measure(tree, width, height)
  local root = measureNode(
    tree,
    {
      minWidth = 0,
      maxWidth = width,
      minHeight = 0,
      maxHeight = height,
    }
  )

  root.x = 1
  root.y = 1

  return root
end

return layout
