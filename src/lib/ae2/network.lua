local component = require("component")

local ae2 = {}

local function firstAddress(componentType)
  local iterator = component.list(componentType)
  return iterator()
end

local function proxyAt(address)
  if not address then
    return nil
  end

  local ok, proxy =
      pcall(component.proxy, address)

  if ok then
    return proxy
  end

  return nil
end

function ae2.resolveProxy(address)
  if address then
    return proxyAt(address), "configured"
  end

  local controller =
      firstAddress("me_controller")

  if controller then
    return proxyAt(controller), "me_controller"
  end

  local interface =
      firstAddress("me_interface")

  if interface then
    return proxyAt(interface), "me_interface"
  end

  return nil, "none"
end

local function call(proxy, method, ...)
  local arguments = {...}
  local ok, result =
      pcall(function()
        local member = proxy[method]

        assert(
          member ~= nil,
          "GTNH OpenComputers AE2 API does not provide " .. method
        )

        return member(table.unpack(arguments))
      end)

  if not ok then
    return nil, tostring(result)
  end

  return result
end

local function query(proxy, resource)
  local identifier =
      resource.name
      or resource.id

  if resource.nbt ~= nil then
    return call(
      proxy,
      "getItemInNetwork",
      identifier,
      resource.damage or 0,
      resource.nbt
    )
  end

  return call(
    proxy,
    "getItemInNetwork",
    identifier,
    resource.damage or 0
  )
end

local function fluidIdentifier(resource)
  return resource.name
    or resource.id
end

local function fluidMatches(result, resource)
  local identifier =
      fluidIdentifier(resource)

  if type(result) ~= "table"
      or result.name ~= identifier
      or (
        resource.fluidLabel ~= nil
        and result.label ~= resource.fluidLabel
      )
  then
    return false
  end

  return true
end

local function fluidAmount(result, resource)
  if not fluidMatches(result, resource) then
    return 0
  end

  return tonumber(result.amount) or 0
end

local function itemAmount(result)
  if result == nil then
    return 0
  end

  if type(result) == "number" then
    return result
  end

  local ok, size =
      pcall(function()
        return result.size
      end)

  if not ok then
    return nil, tostring(size)
  end

  return tonumber(size) or 0
end

local function sampleResources(proxy, resources, keyOf)
  local values = {}
  local records = {}

  for index, resource in ipairs(resources or {}) do
    if resource.type == "fluid" then
      local result, errorMessage =
          call(
            proxy,
            "getFluidInNetwork",
            fluidIdentifier(resource)
          )

      if errorMessage then
        return nil, errorMessage
      end

      local key =
          keyOf(resource, index)

      values[key] =
          fluidAmount(result, resource)

      if fluidMatches(result, resource) then
        records[key] = result
      end
    else
      local ok, result, errorMessage =
          pcall(query, proxy, resource)

      if not ok then
        return nil, tostring(result)
      end

      if errorMessage then
        return nil, errorMessage
      end

      local key =
          keyOf(resource, index)

      if result == nil then
        values[key] = 0
      elseif type(result) == "number" then
        values[key] = result
      else
        local amount, amountError =
            itemAmount(result)

        if not amount then
          return nil, amountError
        end

        values[key] =
            amount
        records[key] = result
      end
    end
  end

  return values, nil, records
end

function ae2.create(options)
  options = options or {}

  local proxy, kind =
      ae2.resolveProxy(options.address)

  local instance = {
    proxy = proxy,
    kind = kind,
  }

  function instance:ensureProxy()
    if not self.proxy then
      self.proxy, self.kind =
          ae2.resolveProxy(options.address)
    end

    if not self.proxy then
      return nil,
        "no ME Controller or ME Interface component"
    end

    return self.proxy
  end

  function instance:isAvailable()
    return self:ensureProxy() ~= nil
  end

  function instance:getFluidsInNetwork()
    local network, errorMessage =
        self:ensureProxy()

    if not network then
      return nil, errorMessage
    end

    local result, errorMessage =
        call(network, "getFluidsInNetwork")

    if errorMessage then
      return nil, errorMessage
    end

    if type(result) ~= "table" then
      return nil, "getFluidsInNetwork must return a table"
    end

    return result
  end

  function instance:getItemsInNetwork(filter)
    local network, errorMessage =
        self:ensureProxy()

    if not network then
      return nil, errorMessage
    end

    local result, errorMessage =
        call(network, "getItemsInNetwork", filter)

    if errorMessage then
      return nil, errorMessage
    end

    if type(result) ~= "table" then
      return nil, "getItemsInNetwork must return a table"
    end

    return result
  end

  function instance:getAmountInNetwork(resource)
    assert(
      type(resource) == "table",
      "AE2 resource is required"
    )

    local network, errorMessage =
        self:ensureProxy()

    if not network then
      return nil, errorMessage
    end

    local result

    if resource.type == "fluid" then
      result, errorMessage =
          call(
            network,
            "getFluidInNetwork",
            resource.name or resource.id
          )

      if errorMessage then
        return nil, errorMessage
      end

      return fluidAmount(result, resource), nil, result
    end

    local identifier =
        resource.name or resource.id

    if not identifier then
      local items, itemsError =
          call(
            network,
            "getItemsInNetwork",
            {label = resource.label}
          )

      if itemsError then
        return nil, itemsError
      end

      if type(items) ~= "table" then
        return nil, "getItemsInNetwork must return a table"
      end

      local total = 0

      for _, item in ipairs(items) do
        local amount, amountError =
            itemAmount(item)

        if not amount then
          return nil, amountError
        end

        total = total + amount
      end

      return total, nil, items[1]
    end

    result, errorMessage =
        call(
          network,
          "getItemInNetwork",
          identifier,
          resource.damage or 0,
          resource.nbt
        )

    if errorMessage then
      return nil, errorMessage
    end

    local amount, amountError =
        itemAmount(result)

    if amount == nil then
      return nil, amountError
    end

    return amount, nil, result
  end

  function instance:getCraftables(filter)
    local network, errorMessage =
        self:ensureProxy()

    if not network then
      return nil, errorMessage
    end

    local result, errorMessage =
        call(network, "getCraftables", filter)

    if errorMessage then
      return nil, errorMessage
    end

    if type(result) ~= "table" then
      return nil, "getCraftables must return a table"
    end

    return result
  end

  function instance:sample(resources, keyOf)
    local network, errorMessage =
        self:ensureProxy()

    if not network then
      return nil, errorMessage
    end

    local values, sampleError, records =
        sampleResources(
          network,
          resources,
          keyOf
        )

    if not values then
      self.proxy = nil
      return nil, sampleError
    end

    return values, nil, records
  end

  return instance
end

return ae2
