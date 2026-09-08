local unicode = require("unicode")

local layout = require("lib.compose.layout")
local framebuffer = require("lib.compose.framebuffer")
local debug = require("lib.compose.debug")

local renderer = {}

local previousFrame = nil
local previousScrollRegions = nil
local lastMetrics = {
  changedCells = 0,
  gpuWrites = 0,
  scrollBlit = false,
  foregroundChanges = 0,
  backgroundChanges = 0,
  cells = 0,
  gpuActivityPercent = 0,
  gpuEstimated = true,
}

local function defaultGpu()
  local component = require("component")

  if not component.isAvailable("gpu") then
    error(
      "Compose requires a GPU component",
      0
    )
  end

  local gpu = component.gpu
  local ok, screen = pcall(gpu.getScreen)

  if not ok or not screen then
    error(
      "Compose requires a GPU bound to a screen",
      0
    )
  end

  return gpu
end

local function getResolution(gpu)
  local ok, width, height =
      pcall(gpu.getResolution)

  if not ok or not width or not height then
    error(
      "Compose could not read the bound screen resolution",
      0
    )
  end

  return width, height
end

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

local function isVisible(node)
  if not node.modifier then
    return true
  end

  for _, element in ipairs(node.modifier.elements or {}) do
    if element.type == "visible" then
      return element.value
    end
  end

  return true
end

local function getScrim(node)
  if not node.modifier then
    return nil
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if
        element.phase == "draw"
        and element.type == "scrim"
    then
      return element.color
    end
  end

  return nil
end

local function getAutoContrast(node)
  if not node.modifier then
    return false
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if
        element.phase == "draw"
        and element.type == "autoContrast"
    then
      return element.value
    end
  end

  return false
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

local function getVerticalScroll(node)
  if not node.modifier then
    return nil
  end

  for _, element in ipairs(
    node.modifier.elements or {}
  ) do
    if element.type == "verticalScroll" then
      return element
    end
  end

  return nil
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

    framebuffer.fillBackground(
        frame,
        visible.left,
        visible.top,
        visible.right - visible.left + 1,
        visible.bottom - visible.top + 1,
        background
    )
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

  if not isVisible(node) then
    return
  end

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

  local scrim =
      getScrim(node)

  if scrim then
    local scrimBounds =
        intersectClip(
          {
            left = measured.x,
            top = measured.y,
            right = measured.x + measured.width - 1,
            bottom = measured.y + measured.height - 1,
          },
          clip
        )

    if scrimBounds then
      framebuffer.tint(
          frame,
          scrimBounds.left,
          scrimBounds.top,
          scrimBounds.right - scrimBounds.left + 1,
          scrimBounds.bottom - scrimBounds.top + 1,
          scrim
      )
    end
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

  framebuffer.setForegroundAutoContrast(
    frame,
    getAutoContrast(node)
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
  end

  local childClip =
      clip

  if getVerticalScroll(node) then
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

local function collectScrollRegions(
    measured,
    parentX,
    parentY,
    clip,
    regions
)
  local node = measured.node

  if not isVisible(node) then
    return
  end

  local absoluteX =
      parentX + measured.x

  local absoluteY =
      parentY + measured.y

  local childClip = clip
  local verticalScroll =
      getVerticalScroll(node)

  if verticalScroll then
    local viewport = {
      left = absoluteX + measured.contentX,
      top = absoluteY + measured.contentY,
      right =
          absoluteX
          + measured.contentX
          + measured.contentWidth
          - 1,
      bottom =
          absoluteY
          + measured.contentY
          + measured.contentHeight
          - 1,
    }

    local visible =
        intersectClip(
          clip,
          viewport
        )

    if
        visible
        and visible.left == viewport.left
        and visible.top == viewport.top
        and visible.right == viewport.right
        and visible.bottom == viewport.bottom
    then
      regions[#regions + 1] = {
        state = verticalScroll.state,
        left = viewport.left,
        top = viewport.top,
        width = measured.contentWidth,
        height = measured.contentHeight,
        offset = verticalScroll.state:getValue(),
      }
    end

    childClip = visible
  end

  if not childClip then
    return
  end

  for _, child in ipairs(measured.children) do
    collectScrollRegions(
      child,
      absoluteX,
      absoluteY,
      childClip,
      regions
    )
  end
end

local function sameScrollRegion(current, previous)
  return
      current.state == previous.state
      and current.left == previous.left
      and current.top == previous.top
      and current.width == previous.width
      and current.height == previous.height
end

local function applyScrollBlit(gpu, regions)
  if
      not previousFrame
      or not previousScrollRegions
      or #regions ~= 1
      or #previousScrollRegions ~= 1
  then
    return false
  end

  local current = regions[1]
  local previous = previousScrollRegions[1]

  if not sameScrollRegion(current, previous) then
    return false
  end

  local delta =
      current.offset - previous.offset

  if
      delta == 0
      or delta ~= math.floor(delta)
      or math.abs(delta) >= current.height
  then
    return false
  end

  local sourceY
  local copyHeight
  local translationY = -delta

  if delta > 0 then
    sourceY = current.top + delta
    copyHeight = current.height - delta
  else
    sourceY = current.top
    copyHeight = current.height + delta
  end

  local ok, result =
      pcall(
        gpu.copy,
        current.left,
        sourceY,
        current.width,
        copyHeight,
        0,
        translationY
      )

  if not ok or result == false then
    return false
  end

  framebuffer.shift(
    previousFrame,
    current.left,
    current.top,
    current.width,
    current.height,
    delta
  )

  return true
end

function renderer.render(tree, options)
  local gpu =
      options
      and options.gpu
      or defaultGpu()

  local width,
  height =
      getResolution(gpu)

  if
      previousFrame
      and (
        previousFrame.width ~= width
        or previousFrame.height ~= height
      )
  then
    previousFrame = nil
    previousScrollRegions = nil
  end

  local measured =
      layout.measure(
        tree,
        width,
        height
      )

  local scrollRegions = {}

  collectScrollRegions(
    measured,
    0,
    0,
    {
      left = 1,
      top = 1,
      right = width,
      bottom = height,
    },
    scrollRegions
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

  local scrollBlit =
      applyScrollBlit(
        gpu,
        scrollRegions
      )

  local presentMetrics =
      framebuffer.present(
    gpu,
    frame,
    previousFrame
  )

  local activityPercent = 0

  if presentMetrics.cells > 0 then
    activityPercent = math.floor(
      presentMetrics.changedCells
      / presentMetrics.cells
      * 100
      + 0.5
    )
  end

  lastMetrics = {
    changedCells = presentMetrics.changedCells,
    gpuWrites = presentMetrics.gpuWrites,
    scrollBlit = scrollBlit,
    foregroundChanges = presentMetrics.foregroundChanges,
    backgroundChanges = presentMetrics.backgroundChanges,
    cells = presentMetrics.cells,
    gpuActivityPercent = activityPercent,
    gpuEstimated = true,
  }

  previousFrame =
      frame

  previousScrollRegions =
      scrollRegions

  return measured
end

function renderer.metrics()
  local result = {}

  for key, value in pairs(lastMetrics) do
    result[key] = value
  end

  return result
end

function renderer.reset(options)
  previousFrame = nil
  previousScrollRegions = nil

  lastMetrics = {
    changedCells = 0,
    gpuWrites = 0,
    scrollBlit = false,
    foregroundChanges = 0,
    backgroundChanges = 0,
    cells = 0,
    gpuActivityPercent = 0,
    gpuEstimated = true,
  }

  local gpu =
      options
      and options.gpu
      or defaultGpu()

  local width,
  height =
      getResolution(gpu)

  if not options or options.clear ~= false then
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
end

return renderer
