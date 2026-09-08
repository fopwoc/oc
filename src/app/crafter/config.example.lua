return {
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
