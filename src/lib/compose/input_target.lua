local inputTarget = {}

local function contains(
    node,
    x,
    y,
    parentX,
    parentY
)
  local absoluteX =
      parentX + node.x

  local absoluteY =
      parentY + node.y

  return
      x >= absoluteX
      and y >= absoluteY
      and x < absoluteX + node.width
      and y < absoluteY + node.height
end

local function findInputModifier(
    modifier,
    eventType
)
  if
      not modifier
      or not modifier.elements
  then
    return nil
  end

  for i = #modifier.elements, 1, -1 do
    local element =
        modifier.elements[i]

    if eventType == "touch" then
      if element.type == "clickable" then
        return element
      end
    elseif eventType == "scroll" then
      if
          element.type == "scrollable"
          or element.type == "verticalScroll"
      then
        return element
      end
    end
  end

  return nil
end

local function search(
    node,
    x,
    y,
    eventType,
    parentX,
    parentY
)
  if not contains(
        node,
        x,
        y,
        parentX,
        parentY
      ) then
    return nil
  end

  local absoluteX =
      parentX + node.x

  local absoluteY =
      parentY + node.y

  -- Last child is treated as visually on top.
  for i = #node.children, 1, -1 do
    local result =
        search(
          node.children[i],
          x,
          y,
          eventType,
          absoluteX,
          absoluteY
        )

    if result then
      return result
    end
  end

  local modifier =
      findInputModifier(
        node.node.modifier,
        eventType
      )

  if not modifier then
    return nil
  end

  return {
    node = node.node,
    layout = node,
    modifier = modifier,

    x = absoluteX,
    y = absoluteY,
    width = node.width,
    height = node.height,

    localX = x - absoluteX + 1,
    localY = y - absoluteY + 1,
  }
end

function inputTarget.find(
    root,
    x,
    y,
    eventType
)
  if not root then
    return nil
  end

  return search(
    root,
    x,
    y,
    eventType,
    0,
    0
  )
end

return inputTarget
