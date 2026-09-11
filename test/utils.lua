for _, path in ipairs({
  "test/utils/clock.lua",
  "test/utils/format.lua",
  "test/utils/series.lua",
}) do
  dofile(path)
end

print("utils tests: OK")
