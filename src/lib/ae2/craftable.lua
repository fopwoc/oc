local craftable = {}

local function itemStack(value)
  if type(value) ~= "userdata"
      and type(value) ~= "table"
  then
    return nil
  end

  local ok, getter =
      pcall(function()
        return value.getItemStack
      end)

  if not ok or type(getter) ~= "function" then
    return value
  end

  local stackOk, stack =
      pcall(function()
        return value.getItemStack()
      end)

  if stackOk and type(stack) == "table" then
    return stack
  end

  return nil
end

local function query(me, filter)
  local result, errorMessage =
      me:getCraftables(filter)

  if not result then
    return nil, errorMessage
  end

  return result, nil
end

local function matchesLabel(value, label)
  if not label then
    return true
  end

  return value.label == label
    or value.displayName == label
    or value.name == label
    or value.id == label
end

local function matchesCraftable(value, target)
  local stack = itemStack(value)

  if not stack then
    return false
  end

  return matchesLabel(stack, target.label)
    or target.name
    and (
      stack.name == target.name
      or stack.id == target.name
    )
end

local function resolveFluid(me, target)
  local found, errorMessage =
      query(me, {
        name = target.name,
        label = target.label,
      })

  if not found then
    return nil, errorMessage
  end

  if #found > 0 then
    return found[1]
  end

  if not target.label then
    return nil
  end

  found, errorMessage =
      query(me, {
        name = target.name,
      })

  if not found then
    return nil, errorMessage
  end

  if #found > 0 then
    return found[1]
  end

  return nil
end

local function resolveItem(me, target)
  local found, errorMessage =
      query(me, {
        label = target.label,
      })

  if not found then
    return nil, errorMessage
  end

  if #found > 0 then
    return found[1]
  end

  if target.name then
    found, errorMessage =
        query(me, {
          name = target.name,
        })

    if not found then
      return nil, errorMessage
    end

    if #found > 0 then
      return found[1]
    end

  end

  -- Some GTNH builds do not apply the label filter to craftables. The
  -- unfiltered query lets us match the actual returned display fields.
  found, errorMessage = query(me, {})

  if not found then
    return nil, errorMessage
  end

  for _, value in ipairs(found) do
    if matchesCraftable(value, target) then
      return value
    end
  end

  return nil
end

function craftable.resolve(me, target)
  assert(
    me ~= nil,
    "ME component is required"
  )

  assert(
    type(target) == "table",
    "Craft target is required"
  )

  if target.type ~= "fluid" then
    local result, errorMessage =
        resolveItem(me, target)

    if result then
      return result
    end

    return nil,
      errorMessage
      or "Craftable not found: " .. target.label
  end

  local result, errorMessage =
      resolveFluid(me, target)

  if result then
    return result
  end

  return nil,
    errorMessage
    or "Fluid craftable not found: " .. target.name
end

return craftable
