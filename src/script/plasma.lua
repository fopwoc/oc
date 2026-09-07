local component =
    require("component")

local computer =
    require("computer")

local event =
    require("event")

local framebuffer =
    require("lib.compose.framebuffer")


local gpu =
    component.gpu

local width,
height =
    gpu.getResolution()


local previous =
    nil

local mode =
    1

local fps =
    0

local frameMs =
    0

local presentMs =
    0

local lastFrame =
    computer.uptime()


local chars = {
  " ",
  "░",
  "▒",
  "▓",
  "█",
}


local palette = {
  0x223344,
  0x335577,
  0x4477AA,
  0x66AACC,
  0x88CCEE,
  0xAADDFF,
  0xFFFFFF,
}


local function clamp(
    value,
    min,
    max
)
  if value < min then
    return min
  end

  if value > max then
    return max
  end

  return value
end


local function plasmaValue(
    x,
    y,
    time
)
  local a =
      math.sin(
        x * 0.16
        + time * 1.3
      )

  local b =
      math.sin(
        y * 0.23
        - time * 0.9
      )

  local c =
      math.sin(
        (x + y) * 0.11
        + time * 0.7
      )

  local dx =
      x - width * 0.5

  local dy =
      y - height * 0.5

  local distance =
      math.sqrt(
        dx * dx
        + dy * dy
      )

  local d =
      math.sin(
        distance * 0.18
        - time * 1.6
      )

  return (
    a
    + b
    + c
    + d
    + 4
  ) / 8
end


local function drawWorstCase(
    frame,
    time
)
  for y = 1, height do
    for x = 1, width do
      local value =
          plasmaValue(
            x,
            y,
            time
          )

      local charIndex =
          clamp(
            math.floor(
              value * #chars
            ) + 1,
            1,
            #chars
          )

      local colorIndex =
          clamp(
            math.floor(
              value * #palette
            ) + 1,
            1,
            #palette
          )

      framebuffer.setForeground(
        frame,
        palette[colorIndex]
      )

      framebuffer.setBackground(
        frame,
        0x000000
      )

      framebuffer.write(
        frame,
        x,
        y,
        chars[charIndex]
      )
    end
  end
end


local function drawRowBatched(
    frame,
    time
)
  for y = 1, height do
    local phase =
        math.floor(
          time * 12
          + y * 2
        )

    local colorIndex =
        (
          math.floor(
            y / 4
          )
          % #palette
        ) + 1

    framebuffer.setForeground(
      frame,
      palette[colorIndex]
    )

    framebuffer.setBackground(
      frame,
      0x000000
    )

    local row = {}

    for x = 1, width do
      local index =
          (
            math.floor(
              (x + phase) / 8
            )
            % (#chars - 1)
          ) + 2

      row[x] =
          chars[index]
    end

    framebuffer.write(
      frame,
      1,
      y,
      table.concat(row)
    )
  end
end


local sparse =
{}


local function initSparse()
  sparse = {}

  for y = 1, height do
    sparse[y] = {}

    for x = 1, width do
      sparse[y][x] =
          chars[
          math.random(
            2,
            #chars
          )
          ]
    end
  end
end


local function drawSparse(frame)
  if not sparse[1] then
    initSparse()
  end

  local changes =
      math.max(
        1,
        math.floor(
          width * height * 0.01
        )
      )

  for _ = 1, changes do
    local x =
        math.random(
          1,
          width
        )

    local y =
        math.random(
          1,
          height
        )

    local char =
        chars[
        math.random(
          1,
          #chars
        )
        ]

    sparse[y][x] =
        char
  end

  framebuffer.setForeground(
    frame,
    0x88CCEE
  )

  framebuffer.setBackground(
    frame,
    0x000000
  )

  for y = 1, height do
    framebuffer.write(
      frame,
      1,
      y,
      table.concat(
        sparse[y]
      )
    )
  end
end


local function modeName()
  if mode == 1 then
    return "WORST PLASMA"
  elseif mode == 2 then
    return "ROW BATCHED"
  else
    return "SPARSE 1%"
  end
end


gpu.setBackground(
  0x000000
)

gpu.fill(
  1,
  1,
  width,
  height,
  " "
)


while true do
  local frameStart =
      computer.uptime()

  local delta =
      frameStart - lastFrame

  lastFrame =
      frameStart

  if delta > 0 then
    fps =
        1 / delta
  end

  local frame =
      framebuffer.create(
        width,
        height
      )

  if mode == 1 then
    drawWorstCase(
      frame,
      frameStart
    )
  elseif mode == 2 then
    drawRowBatched(
      frame,
      frameStart
    )
  else
    drawSparse(
      frame
    )
  end


  local stats =
      string.format(
        " [%d] %s | %.1f FPS | %.1f ms | present %.1f ms | 1/2/3 switch | Q exit ",
        mode,
        modeName(),
        fps,
        frameMs,
        presentMs
      )

  framebuffer.setForeground(
    frame,
    0xFFFFFF
  )

  framebuffer.setBackground(
    frame,
    0x000000
  )

  framebuffer.write(
    frame,
    2,
    2,
    stats
  )


  local presentStart =
      computer.uptime()

  framebuffer.present(
    gpu,
    frame,
    previous
  )

  presentMs =
      (
        computer.uptime()
        - presentStart
      ) * 1000

  previous =
      frame

  frameMs =
      (
        computer.uptime()
        - frameStart
      ) * 1000


  local signal = {
    event.pull(0)
  }

  if signal[1] == "key_down" then
    local char =
        signal[3]

    if
        char == string.byte("q")
        or char == string.byte("Q")
    then
      break
    elseif char == string.byte("1") then
      mode = 1
    elseif char == string.byte("2") then
      mode = 2
    elseif char == string.byte("3") then
      mode = 3
    end
  end

  os.sleep(0)
end
