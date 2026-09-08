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

local function fluidAmount(fluids, resource)
  local identifier =
      resource.name
      or resource.id
  local amount = 0

  for _, fluid in ipairs(fluids or {}) do
    if fluid.name == identifier
        and (
          resource.fluidLabel == nil
          or fluid.label == resource.fluidLabel
        )
    then
      amount = amount + (tonumber(fluid.amount) or 0)
    end
  end

  return amount
end

local function sampleResources(proxy, resources, keyOf)
  local values = {}
  local fluids

  for _, resource in ipairs(resources or {}) do
    if resource.type == "fluid" then
      local result, errorMessage =
          call(proxy, "getFluidsInNetwork")

      if errorMessage then
        return nil, errorMessage
      end

      if type(result) ~= "table" then
        return nil,
          "getFluidsInNetwork must return a table"
      end

      fluids = result
      break
    end
  end

  for index, resource in ipairs(resources or {}) do
    if resource.type == "fluid" then
      values[keyOf(resource, index)] =
          fluidAmount(fluids, resource)
    else
      local ok, result =
          pcall(query, proxy, resource)

      if not ok then
        return nil, tostring(result)
      end

      values[keyOf(resource, index)] =
          result
          and tonumber(result.size)
          or 0
    end
  end

  return values
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

    local values, sampleError =
        sampleResources(
          network,
          resources,
          keyOf
        )

    if not values then
      self.proxy = nil
      return nil, sampleError
    end

    return values
  end

  return instance
end

return ae2
