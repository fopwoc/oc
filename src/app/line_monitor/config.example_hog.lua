return {
  id = "line_hog",
  name = "HOG Line",

  meAddress = nil,

  sampleSeconds = 5,
  incidentFailureSamples = 3,
  incidentSyncSeconds = 30,
  shortWindow = 60,
  mediumWindow = 300,

  inputs = {
    {
      type = "item",
      name = "minecraft:soul_sand",
      damage = 0,
      capacity = 2000000,
      capacityPolicy = "expected",
    },
  },

  outputs = {
    {
      type = "fluid",
      name = "highoctanegasoline",
      damage = 110,
      capacity = 130000000,
      capacityPolicy = "expected",
    }
  },
}
