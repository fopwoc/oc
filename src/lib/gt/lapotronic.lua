local component = require("component")

local adapter = {}

local REQUIRED_METHODS = {
  "getStoredEUString",
  "getEUCapacityString",
  "getEUInputAverage",
  "getEUOutputAverage",
}

local function supports(proxy)
  for _, method in ipairs(REQUIRED_METHODS) do
    local ok, member = pcall(function()
      return proxy[method]
    end)

    if not ok or member == nil then
      return false
    end
  end

  return true
end

function adapter.firstAddress()
  local iterator = component.list("gt_machine")

  while true do
    local address = iterator()

    if not address then
      return nil
    end

    local ok, proxy = pcall(component.proxy, address)

    if ok and proxy and supports(proxy) then
      return address
    end
  end
end

local function resolve(address)
  local ok, proxy =
      pcall(component.proxy, address)

  if ok and proxy then
    return proxy
  end

  if type(component.get) ~= "function" then
    return nil, tostring(proxy or "component is unavailable")
  end

  local fullAddress, resolveError =
      component.get(address, "gt_machine")

  if not fullAddress then
    return nil, tostring(resolveError or proxy or "component is unavailable")
  end

  local proxyOk, resolvedProxy =
      pcall(component.proxy, fullAddress)

  if not proxyOk or not resolvedProxy then
    return nil, tostring(resolvedProxy or "component is unavailable")
  end

  return resolvedProxy
end

local function call(proxy, method)
  local function invoke()
    local member = proxy[method]

    assert(
      member ~= nil,
      "gt_machine does not provide " .. method
    )

    return member()
  end

  local ok, value = pcall(invoke)

  if not ok then
    return nil, tostring(value)
  end

  return value
end

function adapter.create()
  local instance = {
    proxies = {},
  }

  function instance:sample(target)
    assert(
      type(target) == "table"
        and type(target.id) == "string"
        and type(target.address) == "string",
      "Lapotronic target requires id and address"
    )

    local proxy = self.proxies[target.id]

    if not proxy then
      local errorMessage
      proxy, errorMessage = resolve(target.address)

      if not proxy then
        return nil, errorMessage
      end

      self.proxies[target.id] = proxy
    end

    local stored, storedError =
        call(proxy, "getStoredEUString")
    local capacity, capacityError =
        call(proxy, "getEUCapacityString")
    local input, inputError =
        call(proxy, "getEUInputAverage")
    local output, outputError =
        call(proxy, "getEUOutputAverage")

    if not stored
        or not capacity
        or input == nil
        or output == nil
    then
      self.proxies[target.id] = nil

      return nil,
        storedError
        or capacityError
        or inputError
        or outputError
        or "gt_machine returned incomplete power data"
    end

    if type(stored) ~= "string"
        or type(capacity) ~= "string"
    then
      self.proxies[target.id] = nil

      return nil,
        "gt_machine absolute energy methods must return decimal strings"
    end

    input = tonumber(input)
    output = tonumber(output)

    if not input or not output then
      self.proxies[target.id] = nil

      return nil,
        "gt_machine power-flow methods must return numbers"
    end

    return {
      stored = stored,
      capacity = capacity,
      input = input,
      output = output,
    }
  end

  return instance
end

return adapter
