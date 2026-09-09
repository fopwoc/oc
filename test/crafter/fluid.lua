package.path = "src/?.lua;" .. package.path

local resolver =
    require("lib.ae2.craftable")

local function craftableIdentity(value)
  return value.name
    or value.label
    or value.displayName
    or value.id
end

local nativeCraftable = {
  label = "Molten Tin",
}

local nativeMe = {
  getCraftables = function(filter)
    if filter.name == "molten.tin" then
      return {nativeCraftable}
    end

    return {}
  end,
}

local resolvedNative =
    resolver.resolve(
      nativeMe,
      {
        type = "fluid",
        label = "Molten Tin",
        name = "molten.tin",
      }
    )

assert(
  craftableIdentity(resolvedNative)
    == craftableIdentity(nativeCraftable),
  "resolver should find native fluid craftables"
)

local itemCraftable = {
  label = "Ironwood Dust",
}

local itemMe = {
  getCraftables = function(filter)
    if filter.label == "Ironwood Dust" then
      return {itemCraftable}
    end

    return {}
  end,
}

local resolvedItem =
    resolver.resolve(
      itemMe,
      {
        type = "item",
        label = "Ironwood Dust",
      }
    )

assert(
  craftableIdentity(resolvedItem)
    == craftableIdentity(itemCraftable),
  "resolver should preserve item target lookup"
)

local userdataLikeCraftable = {
  getItemStack = function()
    return {
      label = "Fallback Dust",
    }
  end,
}

local fallbackMe = {
  getCraftables = function(filter)
    if next(filter) == nil then
      return {userdataLikeCraftable}
    end

    return {}
  end,
}

local resolvedFallback =
    resolver.resolve(
      fallbackMe,
      {
        type = "item",
        label = "Fallback Dust",
      }
    )

assert(
  resolvedFallback == userdataLikeCraftable,
  "resolver should match craftable item stacks in an unfiltered fallback"
)

local missing, missingError =
    resolver.resolve(
      {
        getCraftables = function()
          return {}
        end,
      },
      {
        type = "item",
        label = "Unavailable Dust",
      }
    )

assert(
  missing == nil
    and type(missingError) == "string"
    and missingError:find("Craftable not found", 1, true),
  "missing craftables should be retryable instead of throwing"
)

print("crafter fluid resolver: OK")
