local unicode = require("unicode")
local color = require("lib.compose.color")

local framebuffer = {}

local DEFAULT_FOREGROUND = 0xFFFFFF
local DEFAULT_BACKGROUND = 0x000000

local CONTINUATION = false

local function index(width, x, y)
  return (y - 1) * width + x
end

function framebuffer.create(width, height)
  return {
    width = width,
    height = height,

    chars = {},
    foreground = {},
    background = {},

    foregroundColor = DEFAULT_FOREGROUND,
    foregroundAutoContrast = false,
    backgroundColor = DEFAULT_BACKGROUND,
  }
end

-- Clears in place so a reused frame keeps its already-sized arrays instead
-- of regrowing three 8000-slot tables on every render.
function framebuffer.clear(frame)
  local chars = frame.chars
  local foreground = frame.foreground
  local background = frame.background

  for i = 1, frame.width * frame.height do
    chars[i] = nil
    foreground[i] = nil
    background[i] = nil
  end
end

function framebuffer.setForeground(frame, color)
  frame.foregroundColor = color
end

function framebuffer.setForegroundAutoContrast(frame, value)
  frame.foregroundAutoContrast = value == true
end

function framebuffer.setBackground(frame, color)
  frame.backgroundColor = color
end

local function setCell(
    frame,
    x,
    y,
    char,
    foreground,
    background
)
  local i = index(
    frame.width,
    x,
    y
  )

  frame.chars[i] = char
  frame.foreground[i] = foreground
  frame.background[i] = background
end

local function clearOverlappingGlyph(frame, x, y)
  local i = index(frame.width, x, y)
  local char = frame.chars[i]

  if char == CONTINUATION and x > 1 then
    frame.chars[index(frame.width, x - 1, y)] = " "
  elseif char
      and char ~= CONTINUATION
      and unicode.charWidth(char) == 2
      and x < frame.width
  then
    frame.chars[index(frame.width, x + 1, y)] = " "
  end
end

local function writeChar(
    frame,
    x,
    y,
    char,
    preserveBackground
)
  local width =
      unicode.charWidth(char)

  if width < 1 then
    return 0
  end

  if x < 1 then
    return width
  end

  if
      x > frame.width
      or x + width - 1 > frame.width
  then
    return width
  end

  local i =
      index(
        frame.width,
        x,
        y
      )

  local existingBackground =
      frame.background[i]
      or DEFAULT_BACKGROUND

  local background

  if preserveBackground then
    background = existingBackground
  else
    background =
        color.blend(
          frame.backgroundColor,
          existingBackground
        )
  end

  local foreground

  if frame.foregroundAutoContrast then
    foreground =
        color.contrast(
          frame.foregroundColor,
          background
        )
  else
    foreground =
        color.blend(
          frame.foregroundColor,
          background
        )
  end

  clearOverlappingGlyph(frame, x, y)

  if width == 2 then
    clearOverlappingGlyph(frame, x + 1, y)
  end

  setCell(
    frame,
    x,
    y,
    char,
    foreground,
    background
  )

  if width == 2 then
    setCell(
      frame,
      x + 1,
      y,
      CONTINUATION,
      foreground,
      background
    )
  end

  return width
end

function framebuffer.set(frame, x, y, char)
  if
      x < 1
      or x > frame.width
      or y < 1
      or y > frame.height
  then
    return
  end

  if
      not char
      or char == ""
  then
    return
  end

  char =
      unicode.sub(
        tostring(char),
        1,
        1
      )

  writeChar(
    frame,
    x,
    y,
    char,
    false
  )
end

local function write(
    frame,
    x,
    y,
    text,
    preserveBackground
)
  if
      y < 1
      or y > frame.height
  then
    return
  end

  text =
      tostring(text)

  local length =
      unicode.len(text)

  local px = x

  for i = 1, length do
    local char =
        unicode.sub(
          text,
          i,
          i
        )

    local width =
        unicode.charWidth(char)

    if px > frame.width then
      break
    end

    if px >= 1 then
      writeChar(
        frame,
        px,
        y,
        char,
        preserveBackground
      )
    end

    px =
        px + width
  end
end

function framebuffer.write(
    frame,
    x,
    y,
    text
)
  write(
    frame,
    x,
    y,
    text,
    false
  )
end

function framebuffer.writeForeground(
    frame,
    x,
    y,
    text
)
  write(
    frame,
    x,
    y,
    text,
    true
  )
end

function framebuffer.fillBackground(
    frame,
    x,
    y,
    width,
    height,
    background
)
  local rgb, alpha =
      color.resolve(background)

  if alpha == 0 then
    return
  end

  local left = math.max(1, x)
  local right = math.min(frame.width, x + width - 1)
  local top = math.max(1, y)
  local bottom = math.min(frame.height, y + height - 1)

  if alpha == 1 then
    -- Opaque fill: the common case, kept free of per-cell blending.
    local foregroundRgb, foregroundAlpha =
        color.resolve(frame.foregroundColor)
    local chars = frame.chars
    local foregrounds = frame.foreground
    local backgrounds = frame.background

    for row = top, bottom do
      for column = left, right do
        local i = index(frame.width, column, row)

        clearOverlappingGlyph(frame, column, row)
        chars[i] = " "
        backgrounds[i] = rgb

        if foregroundAlpha == 1 then
          foregrounds[i] = foregroundRgb
        else
          foregrounds[i] =
              color.blend(
                frame.foregroundColor,
                foregrounds[i] or DEFAULT_FOREGROUND
              )
        end
      end
    end

    return
  end

  for row = top, bottom do
    for column = left, right do
      local i = index(frame.width, column, row)

      frame.background[i] =
          color.blend(
            background,
            frame.background[i] or DEFAULT_BACKGROUND
          )
    end
  end
end

-- Mirrors gpu.copy(): rows vacated by the copy keep their previous content
-- on the screen, so they keep it here too and the next present() diffs them
-- against the new frame like any other cell.
function framebuffer.shift(
    frame,
    left,
    top,
    width,
    height,
    delta
)
  if
      delta == 0
      or width <= 0
      or height <= 0
  then
    return
  end

  local amount = math.abs(delta)

  if amount >= height then
    return
  end

  local function copyRow(sourceY, targetY)
    for x = left, left + width - 1 do
      local source = index(frame.width, x, sourceY)
      local target = index(frame.width, x, targetY)

      frame.chars[target] = frame.chars[source]
      frame.foreground[target] = frame.foreground[source]
      frame.background[target] = frame.background[source]
    end
  end

  if delta > 0 then
    for y = top, top + height - amount - 1 do
      copyRow(y + amount, y)
    end
  else
    for y = top + height - 1, top + amount, -1 do
      copyRow(y - amount, y)
    end
  end
end

function framebuffer.tint(
    frame,
    x,
    y,
    width,
    height,
    value
)
  local _, alpha = color.resolve(value)

  if alpha == 0 then
    return
  end

  for row = y, y + height - 1 do
    if row >= 1 and row <= frame.height then
      for column = x, x + width - 1 do
        if column >= 1 and column <= frame.width then
          local i = index(frame.width, column, row)

          frame.foreground[i] =
              color.blend(
                value,
                frame.foreground[i]
                  or DEFAULT_FOREGROUND
              )

          frame.background[i] =
              color.blend(
                value,
                frame.background[i]
                  or DEFAULT_BACKGROUND
              )
        end
      end
    end
  end
end

local function getCell(frame, i)
  if not frame then
    return
        " ",
        DEFAULT_FOREGROUND,
        DEFAULT_BACKGROUND
  end

  local char =
      frame.chars[i]

  if char == nil then
    char = " "
  end

  return
      char,
      frame.foreground[i]
      or DEFAULT_FOREGROUND,
      frame.background[i]
      or DEFAULT_BACKGROUND
end

local function cellsEqual(
    current,
    previous,
    i
)
  local char,
  foreground,
  background =
      getCell(current, i)

  local previousChar,
  previousForeground,
  previousBackground =
      getCell(previous, i)

  return
      char == previousChar
      and foreground == previousForeground
      and background == previousBackground
end

local function isContinuation(
    frame,
    width,
    x,
    y
)
  if not frame then
    return false
  end

  return
      frame.chars[
      index(width, x, y)
      ] == CONTINUATION
end

function framebuffer.present(
    gpu,
    current,
    previous
)
  local width =
      current.width

  local height =
      current.height

  local activeForeground = nil
  local activeBackground = nil
  local changedCells = 0
  local gpuWrites = 0
  local foregroundChanges = 0
  local backgroundChanges = 0

  local changed = {}

  local function markChanged(x)
    if x >= 1 and x <= width and not changed[x] then
      changed[x] = true
      changedCells = changedCells + 1
    end
  end

  for y = 1, height do
    for x = 1, width do
      changed[x] = nil
    end

    for x = 1, width do
      local i =
          index(
            width,
            x,
            y
          )

      if not cellsEqual(
            current,
            previous,
            i
          ) then
        markChanged(x)

        -- A changed continuation cell also invalidates the wide glyph lead.
        if
            x > 1
            and (
              isContinuation(
                current,
                width,
                x,
                y
              )
              or isContinuation(
                previous,
                width,
                x,
                y
              )
            )
        then
          markChanged(x - 1)
        end

        -- A changed wide glyph lead also invalidates its continuation cell.
        if
            x < width
            and (
              isContinuation(
                current,
                width,
                x + 1,
                y
              )
              or isContinuation(
                previous,
                width,
                x + 1,
                y
              )
            )
        then
          markChanged(x + 1)
        end
      end
    end

    local x = 1

    while x <= width do
      if not changed[x] then
        x = x + 1
      else
        local char,
        foreground,
        background =
            getCell(
              current,
              index(
                width,
                x,
                y
              )
            )

        -- A changed span must never begin inside a wide character.
        if char == CONTINUATION then
          x = x + 1
        else
          local runStart = x
          local run = {}

          while x <= width do
            local i =
                index(
                  width,
                  x,
                  y
                )

            local runChar,
            runForeground,
            runBackground =
                getCell(
                  current,
                  i
                )

            if not changed[x] then
              break
            end

            if runChar == CONTINUATION then
              x = x + 1
            elseif
                runForeground ~= foreground
                or runBackground ~= background
            then
              break
            else
              run[#run + 1] =
                  runChar

              x =
                  x
                  + unicode.charWidth(
                    runChar
                  )
            end
          end

          if #run > 0 then
            if
                activeForeground
                ~= foreground
            then
              gpu.setForeground(
                foreground
              )

              foregroundChanges =
                  foregroundChanges + 1

              activeForeground =
                  foreground
            end

            if
                activeBackground
                ~= background
            then
              gpu.setBackground(
                background
              )

              backgroundChanges =
                  backgroundChanges + 1

              activeBackground =
                  background
            end

            gpu.set(
              runStart,
              y,
              table.concat(run)
            )

            gpuWrites =
                gpuWrites + 1
          end
        end
      end
    end
  end

  return {
    changedCells = changedCells,
    gpuWrites = gpuWrites,
    foregroundChanges = foregroundChanges,
    backgroundChanges = backgroundChanges,
    cells = width * height,
  }
end

return framebuffer
