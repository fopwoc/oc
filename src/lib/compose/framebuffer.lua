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

function framebuffer.clear(frame)
  frame.chars = {}
  frame.foreground = {}
  frame.background = {}
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
  local _, alpha =
      color.resolve(background)

  if alpha == 0 then
    return
  end

  for row = y, y + height - 1 do
    if row >= 1 and row <= frame.height then
      for column = x, x + width - 1 do
        if column >= 1 and column <= frame.width then
          local i = index(frame.width, column, row)
          local existingBackground =
              frame.background[i]
              or DEFAULT_BACKGROUND

          frame.background[i] =
              color.blend(
                background,
                existingBackground
              )

          if alpha == 1 then
            frame.chars[i] = " "
            frame.foreground[i] =
                color.blend(
                  frame.foregroundColor,
                  frame.foreground[i]
                    or DEFAULT_FOREGROUND
                )
          end
        end
      end
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

  for y = 1, height do
    local changed = {}

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
        if not changed[x] then
          changed[x] = true
          changedCells = changedCells + 1
        end

        -- Если изменилась continuation-cell,
        -- перерисовываем и начало wide-глифа.
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
          changed[x - 1] = true
        end

        -- Если lead wide-глифа изменился,
        -- его вторая клетка тоже логически
        -- относится к этому изменению.
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
          changed[x + 1] = true
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

        -- changed span никогда не должен
        -- реально стартовать внутри wide-char.
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
