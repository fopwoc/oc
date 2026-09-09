local ae2 =
    require("lib.ae2.network")

local matcher =
    require("lib.ae2.query")

local args = {...}
local needle =
    table.concat(args, " ")

local function printHelp()
  print("Usage: query <text>")
  print()
  print("Search item and fluid names in the connected AE2 network.")
  print("Matches are ranked by exact, prefix, substring, and fuzzy match.")
  print()
  print("Examples:")
  print("  run.lua query metaitem.01")
  print("  run.lua query Iron Dust")
end

if needle == ""
    or needle == "--help"
    or needle == "-h"
then
  printHelp()
  return
end

local adapter =
    ae2.create()

assert(
  adapter:isAvailable(),
  "No ME controller or interface component found"
)

local items, itemError =
    adapter:getItemsInNetwork()

assert(
  items,
  itemError
    or "Unable to read items from the AE2 network"
)

local fluids, fluidError =
    adapter:getFluidsInNetwork()

local function amount(value)
  return value.size
    or value.amount
    or "?"
end

local function name(value)
  return value.name
    or value.id
    or value.label
    or value.displayName
    or "?"
end

local function printMatches(title, values)
  local matches =
      matcher.search(values, needle, 12)

  print(title .. " (" .. tostring(#matches) .. ")")

  if #matches == 0 then
    print("  no matches")
    return
  end

  for index, match in ipairs(matches) do
    local value = match.value
    local label =
        value.label
        or value.displayName
        or "-"
    local damage =
        value.damage
        and " damage=" .. tostring(value.damage)
        or ""

    print(string.format(
      "  %2d  %-36s  %-24s  x%s%s",
      index,
      name(value),
      label,
      tostring(amount(value)),
      damage
    ))
  end
end

print("Query: " .. needle)
print()
printMatches("ITEMS", items)
print()

if fluids then
  printMatches("FLUIDS", fluids)
else
  print("FLUIDS (unavailable)")
  print("  " .. tostring(fluidError))
end
