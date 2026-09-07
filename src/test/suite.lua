local tests = {
  "test/engine.lua",
  "test/color.lua",
  "test/navigation_engine.lua",
  "test/lifecycle.lua",
  "test/renderer.lua",
}

for _, path in ipairs(tests) do
  dofile(path)
end

print("test suite: OK")
