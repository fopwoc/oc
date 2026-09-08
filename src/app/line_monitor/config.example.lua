return {
  id = "platline",
  name = "Platinum Line",

  -- Optional. Leave nil to discover the first attached ME Controller,
  -- then ME Interface.
  meAddress = nil,

  sampleSeconds = 5,
  incidentFailureSamples = 3,
  incidentSyncSeconds = 30,
  shortWindow = 60,
  mediumWindow = 300,
  historyCapacity = 120,

  -- Capacity is the maximum amount assigned to this resource's isolated
  -- storage on the line subnet. It is intentionally configured because
  -- GTNH's OC AE2 API does not expose ME cell capacity. Replace every
  -- example item id, damage value, and capacity with values from your line.
  -- capacityPolicy = "pressure" treats a full resource as a problem;
  -- capacityPolicy = "expected" keeps capacity for display and chart scale.
  inputs = {
    {
      type = "item",
      label = "Platinum Metallic Powder",
      name = "gregtech:gt.metaitem.01",
      damage = 0,
      capacity = 512000,
      capacityPolicy = "pressure",
    },

    -- Fluid resources use getFluidsInNetwork() and match by fluid name.
    -- The optional fluidLabel disambiguates networks exposing the same name.
    -- {
    --   type = "fluid",
    --   label = "Molten Platinum",
    --   name = "molten.platinum",
    --   fluidLabel = "Molten Platinum",
    --   capacity = 16000,
    --   capacityPolicy = "expected",
    -- },
  },

  outputs = {
    {
      type = "item",
      label = "Platinum",
      name = "gregtech:gt.metaitem.01",
      damage = 110,
      capacity = 16384,
      capacityPolicy = "expected",
    },
    {
      type = "item",
      label = "Palladium",
      name = "gregtech:gt.metaitem.01",
      damage = 111,
      capacity = 16384,
      capacityPolicy = "expected",
    },
    {
      type = "item",
      label = "Rhodium",
      name = "gregtech:gt.metaitem.01",
      damage = 112,
      capacity = 16384,
      capacityPolicy = "expected",
    },
  },
}
