package.path = "src/?.lua;" .. package.path

local analytics =
    require("lib.production_line.analytics")

local model = analytics.create({
  id = "line",
  name = "Test line",
  shortWindow = 60,
  mediumWindow = 300,
  historyCapacity = 16,
  inputs = {
    {
      key = "input",
      label = "Input",
      name = "example:input",
      capacity = 1000,
    },
  },
  outputs = {
    {
      key = "output",
      label = "Output",
      name = "example:output",
      capacity = 100,
    },
  },
})

model:sample(0, {
  inputs = {input = 0},
  outputs = {output = 0},
})

assert(
  model:snapshot(0).state == "WARMING",
  "one sample should not produce a diagnosis"
)

model:sample(10, {
  inputs = {input = 100},
  outputs = {output = 10},
})

model:sample(20, {
  inputs = {input = 200},
  outputs = {output = 20},
})

local snapshot = model:snapshot(20)
local input = snapshot.inputs[1]
local output = snapshot.outputs[1]

assert(
  input.arrivalRate == 10,
  "positive input stock changes should estimate arrival rate"
)

assert(
  input.processingRate == 0,
  "input without stock decreases should have no processing estimate"
)

assert(
  input.backlogRate == 10,
  "input stock growth should estimate backlog growth"
)

assert(
  input.utilization == 0.2,
  "configured capacity should produce utilization"
)

assert(
  snapshot.efficiency == 0,
  "an accumulating input with no consumption should be inefficient"
)

assert(
  snapshot.state == "OVERLOADED",
  "growing input backlog should be overloaded"
)

assert(
  output.productionRate == 1
    and output.netRate == 1,
  "positive output stock changes should be production and net rate"
)

assert(
  #input.chart == 60,
  "resource history should use fixed five-second timeline slots"
)

local runtimeLabels = analytics.create({
  id = "runtime-labels",
  name = "Runtime labels",
  inputs = {
    {
      key = "input",
      name = "minecraft:soul_sand",
    },
  },
})

runtimeLabels:sample(
  0,
  {inputs = {input = 12}},
  {
    inputs = {
      input = {
        name = "minecraft:soul_sand",
        label = "Soul Sand",
        size = 12,
      },
    },
  }
)

local labeled =
    runtimeLabels:snapshot(0).inputs[1]

assert(
  labeled.label == "Soul Sand"
    and labeled.available == true,
  "runtime AE2 records should provide labels for technical resources"
)

runtimeLabels:sample(
  10,
  {inputs = {input = 0}},
  {inputs = {}}
)

local missing =
    runtimeLabels:snapshot(10).inputs[1]

assert(
  missing.available == false
    and missing.technicalName == "minecraft:soul_sand",
  "missing runtime resources should retain their technical name"
)

local draining = analytics.create({
  id = "draining",
  name = "Draining line",
  inputs = {
    {
      key = "input",
      name = "example:input",
      capacity = 1000,
    },
  },
})

draining:sample(0, {inputs = {input = 500}})
draining:sample(10, {inputs = {input = 400}})
draining:sample(20, {inputs = {input = 300}})

local drainingSnapshot = draining:snapshot(20)

assert(
  drainingSnapshot.efficiency == 100,
  "draining an existing backlog should still report full efficiency"
)

assert(
  drainingSnapshot.state == "DRAINING",
  "negative input stock change should be draining"
)

draining:setOffline("test disconnect")

local offline = draining:snapshot(20)

assert(
  offline.state == "OFFLINE"
    and offline.health == 0,
  "offline AE2 should be critical"
)

local expectedCapacity = analytics.create({
  id = "expected-capacity",
  name = "Expected capacity",
  inputs = {
    {
      type = "fluid",
      key = "fluid",
      name = "molten.example",
      capacity = 1000,
      capacityPolicy = "expected",
    },
  },
})

expectedCapacity:sample(0, {
  inputs = {fluid = 1000},
})
expectedCapacity:sample(10, {
  inputs = {fluid = 1000},
})

local expectedSnapshot = expectedCapacity:snapshot(10)

assert(
  expectedSnapshot.inputs[1].type == "fluid"
    and expectedSnapshot.state == "IDLE"
    and expectedSnapshot.health == 100,
  "expected full fluid capacity should not create capacity pressure"
)

local pressureCapacity = analytics.create({
  id = "pressure-capacity",
  name = "Pressure capacity",
  inputs = {
    {
      key = "input",
      name = "example:input",
      capacity = 1000,
      capacityPolicy = "pressure",
    },
  },
})

pressureCapacity:sample(0, {inputs = {input = 1000}})
pressureCapacity:sample(10, {inputs = {input = 1000}})

local pressureSnapshot = pressureCapacity:snapshot(10)

assert(
  pressureSnapshot.state == "OVERLOADED"
    and pressureSnapshot.health < 100,
  "pressure capacity should diagnose a full resource"
)

print("production line analytics: OK")
