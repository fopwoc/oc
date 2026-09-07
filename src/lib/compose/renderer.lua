local unicode = require("unicode")
local component = require("component")

local layout = require("../lib/compose/layout")
local framebuffer = require("../lib/compose/framebuffer")
local debug = require("../lib/compose/debug")

local renderer = {}

local previousFrame = nil

local function getStyle(node)
  local foreground =
      0xFFFFFF

  local background =
      nil

  if not node.modifier then
    return foreground, background
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if element.phase == "draw" then
      if element.type == "foreground" then
        foreground =
            element.color
      elseif element.type == "background" then
        background =
            element.color
      end
    end
  end

  return foreground, background
end

local function getBorder(node)
  if not node.modifier then
    return nil
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if
        element.phase == "border"
        and element.type == "border"
    then
      return element
    end
  end

  return nil
end

local function hasVerticalScroll(node)
  if not node.modifier then
    return false
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if element.type == "verticalScroll" then
      return true
    end
  end

  return false
end

local function intersectClip(a, b)
  if not a then
    return b
  end

  if not b then
    return a
  end

  local left =
      math.max(a.left, b.left)

  local top =
      math.max(a.top, b.top)

  local right =
      math.min(a.right, b.right)

  local bottom =
      math.min(a.bottom, b.bottom)

  if
      left > right
      or top > bottom
  then
    return nil
  end

  return {
    left = left,
    top = top,
    right = right,
    bottom = bottom,
  }
end

local function fillBounds(
    frame,
    measured,
    foreground,
    background,
    clip
)
  if background == nil then
    return
  end

  local bounds = {
    left = measured.x,
    top = measured.y,

    right =
        measured.x
        + measured.width
        - 1,

    bottom =
        measured.y
        + measured.height
        - 1,
  }

  local visible =
      intersectClip(
        bounds,
        clip
      )

  if not visible then
    return
  end

  framebuffer.setForeground(
    frame,
    foreground
  )

  framebuffer.setBackground(
    frame,
    background
  )

  for y = visible.top, visible.bottom do
    framebuffer.write(
      frame,
      visible.left,
      y,
      string.rep(
        " ",
        visible.right
        - visible.left
        + 1
      )
    )
  end
end

local function drawBorder(
    frame,
    measured,
    border,
    clip
)
  if not border then
    return
  end

  local left =
      measured.x

  local top =
      measured.y

  local right =
      measured.x
      + measured.width
      - 1

  local bottom =
      measured.y
      + measured.height
      - 1

  if
      left > right
      or top > bottom
  then
    return
  end

  local color =
      border.color
      or 0xFFFFFF

  local chars =
      border.characters

  framebuffer.setForeground(
    frame,
    color
  )

  local function visible(x, y)
    return
        x >= clip.left
        and x <= clip.right
        and y >= clip.top
        and y <= clip.bottom
  end

  local function put(x, y, char)
    if visible(x, y) then
      framebuffer.writeForeground(
        frame,
        x,
        y,
        char
      )
    end
  end

  -- Совсем вырожденный случай.
  if
      left == right
      and top == bottom
  then
    put(
      left,
      top,
      chars.topLeft
    )

    return
  end

  -- Верх / низ.
  if left < right then
    put(
      left,
      top,
      chars.topLeft
    )

    put(
      right,
      top,
      chars.topRight
    )

    if bottom ~= top then
      put(
        left,
        bottom,
        chars.bottomLeft
      )

      put(
        right,
        bottom,
        chars.bottomRight
      )
    end

    for x = left + 1, right - 1 do
      put(
        x,
        top,
        chars.top
      )

      if bottom ~= top then
        put(
          x,
          bottom,
          chars.bottom
        )
      end
    end
  end

  -- Боковины.
  for y = top + 1, bottom - 1 do
    put(
      left,
      y,
      chars.left
    )

    if right ~= left then
      put(
        right,
        y,
        chars.right
      )
    end
  end
end

local function drawText(
    frame,
    measured,
    node,
    clip,
    background
)
  local text =
      tostring(node.props.text or "")

  local y =
      measured.contentY

  if
      y < clip.top
      or y > clip.bottom
  then
    return
  end

  local textLeft =
      measured.contentX

  local contentRight =
      textLeft
      + measured.contentWidth
      - 1

  local visibleLeft =
      math.max(
        textLeft,
        clip.left
      )

  local visibleRight =
      math.min(
        contentRight,
        clip.right
      )

  if visibleLeft > visibleRight then
    return
  end

  local chars = {}
  local drawX = nil

  local x =
      textLeft

  local length =
      unicode.len(text)

  for i = 1, length do
    local char =
        unicode.sub(
          text,
          i,
          i
        )

    local width =
        unicode.charWidth(char)

    local charLeft =
        x

    local charRight =
        x + width - 1

    if charLeft > contentRight then
      break
    end

    -- Рисуем только полностью видимый glyph.
    -- Половину wide-char рисовать нельзя.
    if
        charLeft >= visibleLeft
        and charRight <= visibleRight
        and charRight <= contentRight
    then
      if not drawX then
        drawX =
            charLeft
      end

      chars[#chars + 1] =
          char
    end

    x =
        x + width
  end

  if
      not drawX
      or #chars == 0
  then
    return
  end

  local visibleText =
      table.concat(chars)

  if background ~= nil then
    framebuffer.write(
      frame,
      drawX,
      y,
      visibleText
    )
  else
    framebuffer.writeForeground(
      frame,
      drawX,
      y,
      visibleText
    )
  end
end

local function drawProgress(
    frame,
    measured,
    node,
    clip,
    background
)
  local width =
      measured.contentWidth

  local value =
      node.props.value or 0

  local filled =
      math.floor(
        width * value
      )

  local text =
      string.rep("#", filled)
      .. string.rep(
        "-",
        width - filled
      )

  local y =
      measured.contentY

  if
      y < clip.top
      or y > clip.bottom
  then
    return
  end

  local left =
      measured.contentX

  local right =
      left + width - 1

  local visibleLeft =
      math.max(
        left,
        clip.left
      )

  local visibleRight =
      math.min(
        right,
        clip.right
      )

  if visibleLeft > visibleRight then
    return
  end

  local visibleText =
      text:sub(
        visibleLeft - left + 1,
        visibleRight - left + 1
      )

  if background ~= nil then
    framebuffer.write(
      frame,
      visibleLeft,
      y,
      visibleText
    )
  else
    framebuffer.writeForeground(
      frame,
      visibleLeft,
      y,
      visibleText
    )
  end
end

local function drawNode(
    frame,
    measured,
    parentX,
    parentY,
    parentDebugColor,
    clip
)
  local node =
      measured.node

  local absoluteX =
      parentX + measured.x

  local absoluteY =
      parentY + measured.y

  local originalX =
      measured.x

  local originalY =
      measured.y

  local originalContentX =
      measured.contentX

  local originalContentY =
      measured.contentY

  measured.x =
      absoluteX

  measured.y =
      absoluteY

  measured.contentX =
      absoluteX
      + originalContentX

  measured.contentY =
      absoluteY
      + originalContentY

  local foreground,
  background =
      getStyle(node)

  local ownDebugColor =
      debug.getRecompositionColor(node)

  local debugColor =
      ownDebugColor
      or parentDebugColor

  if debugColor then
    background =
        debugColor
  end

  fillBounds(
    frame,
    measured,
    foreground,
    background,
    clip
  )

  local border =
      getBorder(node)

  drawBorder(
    frame,
    measured,
    border,
    clip
  )

  framebuffer.setForeground(
    frame,
    foreground
  )

  if background ~= nil then
    framebuffer.setBackground(
      frame,
      background
    )
  end

  if node.type == "text" then
    drawText(
      frame,
      measured,
      node,
      clip,
      background
    )
  elseif node.type == "progress" then
    drawProgress(
      frame,
      measured,
      node,
      clip,
      background
    )
  end

  local childClip =
      clip

  if hasVerticalScroll(node) then
    local viewport = {
      left =
          measured.contentX,

      top =
          measured.contentY,

      right =
          measured.contentX
          + measured.contentWidth
          - 1,

      bottom =
          measured.contentY
          + measured.contentHeight
          - 1,
    }

    childClip =
        intersectClip(
          clip,
          viewport
        )
  end

  if childClip then
    for _, child in ipairs(
      measured.children
    ) do
      drawNode(
        frame,
        child,
        absoluteX,
        absoluteY,
        debugColor,
        childClip
      )
    end
  end

  measured.x =
      originalX

  measured.y =
      originalY

  measured.contentX =
      originalContentX

  measured.contentY =
      originalContentY
end

function renderer.render(tree)
  local gpu =
      component.gpu

  local width,
  height =
      gpu.getResolution()

  local measured =
      layout.measure(
        tree,
        width,
        height
      )

  local frame = framebuffer.create(width, height)

  drawNode(
    frame,
    measured,
    0,
    0,
    nil,
    {
      left = 1,
      top = 1,
      right = width,
      bottom = height,
    }
  )

  framebuffer.present(
    gpu,
    frame,
    previousFrame
  )

  previousFrame =
      frame

  return measured
end

function renderer.reset()
  previousFrame = nil

  local gpu =
      component.gpu

  local width,
  height =
      gpu.getResolution()

  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)

  gpu.fill(
    1,
    1,
    width,
    height,
    " "
  )
end

return renderer
