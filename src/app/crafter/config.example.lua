return {
  -- GTNH AE2 request planning is serialized for this computer by default.
  -- Increase only if this setup is known to accept concurrent requests.
  maxConcurrent = 1,

  -- Rolling successful completions reported as crafts per hour.
  completionWindowSeconds = 60 * 60,
  completionHistoryCapacity = 1024,

  defaults = {
    amount = 1,
    cooldown = 0,
    retrySeconds = 1,
  },

  targets = {
    {
      label = "Ironwood Dust",
    },
    -- Item targets may use a technical name, a pretty label, or both.
    -- When label is omitted, the label returned by AE2 is used in the UI.
    -- {
    --   name = "minecraft:soul_sand",
    --   amount = 64,
    -- },
    -- {
    --   name = "gregtech:gt.metaitem.01",
    --   label = "Iron Dust",
    --   amount = 64,
    -- },
    {
      label = "Ironwood Ingot",
    },
    -- Fluid targets use GTNH's native fluid crafting API. `fluid` is the
    -- exact fluid name returned by the ME component.
    -- The amount uses the unit expected by the craftable, normally mB.
    -- {
    --   type = "fluid",
    --   label = "Molten Platinum",
    --   fluid = "molten.platinum",
    --   amount = 144,
    -- },
  },
}
