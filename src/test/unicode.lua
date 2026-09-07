local component = require("component")
local event = require("event")

local gpu = component.gpu

gpu.setResolution(40, 10)
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, 40, 10, " ")

gpu.set(1, 1, "A😀B")
gpu.set(1, 3, "A日B")
gpu.set(1, 5, "AяB")

gpu.set(1, 7, "12345678901234567890")

event.pull("key_down")
