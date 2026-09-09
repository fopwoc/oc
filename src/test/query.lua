package.path = "src/?.lua;" .. package.path

local matcher =
    require("lib.ae2.query")

local values = {
  {
    name = "gregtech:gt.metaitem.01",
    label = "Iron Dust",
    size = 64,
  },
  {
    name = "gregtech:gt.metaitem.02",
    label = "Iron Plate",
    size = 32,
  },
  {
    name = "minecraft:iron_ingot",
    label = "Iron Ingot",
    size = 128,
  },
}

local exact =
    matcher.search(values, "gt.metaitem.01")

assert(
  exact[1].value.name == "gregtech:gt.metaitem.01",
  "exact identifier matches should rank first"
)

local label =
    matcher.search(values, "iron plate")

assert(
  label[1].value.label == "Iron Plate",
  "label matches should rank first"
)

local limited =
    matcher.search(values, "iron", 2)

assert(
  #limited == 2,
  "query results should respect the result limit"
)

print("query matcher: OK")
