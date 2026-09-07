local component = require("component")
local event = require("event")
local computer = require("computer")

local gpu = component.gpu

local w, h = gpu.maxResolution()
gpu.setResolution(w, h)

gpu.setBackground(0x000000)
gpu.fill(1, 1, w, h, " ")

math.randomseed(math.floor(computer.uptime() * 1000))

local drops = {}

for x = 1, w do
  drops[x] = {
    y = math.random(-h, 0),
    speed = math.random(1, 3),
    tick = 0
  }
end

local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function char()
  local i = math.random(1, #chars)
  return chars:sub(i, i)
end

while true do
  for x = 1, w do
    local d = drops[x]

    d.tick = d.tick + 1

    if d.tick >= d.speed then
      d.tick = 0

      -- erase tail
      local tail = d.y - math.random(6, 14)

      if tail >= 1 and tail <= h then
        gpu.setForeground(0x000000)
        gpu.set(x, tail, " ")
      end

      -- darker trail
      if d.y - 2 >= 1 and d.y - 2 <= h then
        gpu.setForeground(0x005500)
        gpu.set(x, d.y - 2, char())
      end

      -- bright trail
      if d.y - 1 >= 1 and d.y - 1 <= h then
        gpu.setForeground(0x00AA00)
        gpu.set(x, d.y - 1, char())
      end

      -- white head
      if d.y >= 1 and d.y <= h then
        gpu.setForeground(0xCCFFCC)
        gpu.set(x, d.y, char())
      end

      d.y = d.y + 1

      if d.y > h + 15 then
        d.y = math.random(-20, -1)
        d.speed = math.random(1, 3)
      end
    end
  end

  -- touch/key = exit
  local e = { event.pull(0.05) }

  if e[1] == "key_down" or e[1] == "touch" then
    break
  end
end

gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, w, h, " ")
gpu.set(1, 1, "Matrix terminated.")
