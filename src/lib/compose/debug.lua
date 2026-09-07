local debug = {}

-- Recomposition colors are a development aid and must not alter normal UI.
local enabled = false

local recompositionColors = {
  0xFF0055,   -- hot pink
  0x00FF66,   -- acid green
  0x0066FF,   -- electric blue
  0xFFFF00,   -- yellow
  0xFF6600,   -- orange
  0xAA00FF,   -- violet
  0x00FFFF,   -- cyan
  0xFF00FF,   -- magenta
  0x66FF00,   -- lime
  0xFF0033,   -- red-pink
  0x00FFCC,   -- turquoise
  0xCCFF00,   -- chartreuse
  0xFF00AA,   -- neon pink
  0x3300FF,   -- deep electric blue
  0xFFCC00,   -- amber
  0x00CCFF,   -- sky cyan
}

function debug.setEnabled(value)
  enabled = value == true
end

function debug.isEnabled()
  return enabled
end

function debug.getRecompositionGeneration(node)
  if not enabled then
    return nil
  end

  if not node then
    return nil
  end

  local compose = node.__compose

  if not compose then
    return nil
  end

  return compose.generation
end

function debug.getRecompositionColor(node)
  local generation =
      debug.getRecompositionGeneration(node)

  if not generation or generation < 1 then
    return nil
  end

  local index =
      ((generation - 1) % #recompositionColors) + 1

  return recompositionColors[index]
end

return debug
