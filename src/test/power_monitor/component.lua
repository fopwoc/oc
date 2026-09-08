local component = require("component")

local addresses = {}

for address in component.list("gt_machine") do
  addresses[#addresses + 1] = address
end

local proxy

for _, address in ipairs(addresses) do
  local candidate = component.proxy(address)

  if type(candidate.getStoredEUString) == "function"
      and type(candidate.getEUCapacityString) == "function"
      and type(candidate.getEUInputAverage) == "function"
      and type(candidate.getEUOutputAverage) == "function"
  then
    proxy = candidate
    break
  end
end

if not proxy then
  print("power monitor OC adapter: SKIPPED (no LSC gt_machine attached)")
else

  local stored = proxy.getStoredEUString()
  local capacity = proxy.getEUCapacityString()

  assert(
    type(stored) == "string"
      and type(capacity) == "string",
    "LSC absolute energy methods must return decimal strings"
  )

  assert(
    tonumber(proxy.getEUInputAverage()) ~= nil
      and tonumber(proxy.getEUOutputAverage()) ~= nil,
    "LSC power-flow methods must return numeric values"
  )

  print("power monitor OC adapter: OK")
end
