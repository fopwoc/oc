local compose = require("lib.compose.init")
local scaffold = require("lib.components.scaffold")
local topAppBar = require("lib.components.top_app_bar")
local commandBar = require("lib.components.command_bar")

-- Uncomment while debugging recomposition: require("lib.compose.debug").setEnabled(true)

local entrypoint = {}
local HARDWARE_REFRESH_SECONDS = 3

local DEFAULT_COLORS = {
  background = 0x101418,
  surface = 0x1A2228,
  foreground = 0xE2E8F0,
  muted = 0x8B96A3,
  action = 0x6BD5FF,
  danger = 0xE06C75,
}

local function mergeColors(colors)
  local result = {}

  for key, value in pairs(DEFAULT_COLORS) do
    result[key] = value
  end

  for key, value in pairs(colors or {}) do
    result[key] = value
  end

  if result.foreground == DEFAULT_COLORS.foreground
      and result.text ~= nil
  then
    result.foreground = result.text
  end

  if result.action == DEFAULT_COLORS.action
      and result.primary ~= nil
  then
    result.action = result.primary
  end

  return result
end

local function formatUptime(seconds)
  seconds = math.floor(seconds)

  return string.format(
    "%02dm %02ds",
    math.floor(seconds / 60),
    seconds % 60
  )
end

local function routeProvider(routes, context)
  if type(routes) == "function" then
    return function(entry)
      return routes(entry, context)
    end
  end

  assert(
    type(routes) == "table",
    "Entrypoint routes must be a table or function"
  )

  return function(entry)
    local route = routes[entry.key]

    assert(
      type(route) == "function",
      "Entrypoint has no destination for: "
      .. tostring(entry.key)
    )

    return route(entry, context)
  end
end

function entrypoint.Entrypoint(options)
  assert(
    type(options) == "table",
    "Entrypoint requires an options table"
  )

  assert(
    type(options.title) == "string"
      and options.title ~= "",
    "Entrypoint requires a title"
  )

  assert(
    options.content ~= nil
      or options.routes ~= nil,
    "Entrypoint requires content or routes"
  )

  local colors =
      mergeColors(options.colors)

  local navigation =
      options.navigation

  if navigation == nil then
    navigation =
        compose.rememberNavBackStack(
          options.start
          or options.startRoute
          or "home"
        )
  end

  local uptimeRevision =
      compose.remember(0)

  compose.LaunchedEffect(
    "entrypoint-uptime",
    function()
      while true do
        compose.delay(1)
        uptimeRevision.value =
            uptimeRevision.value + 1
      end
    end
  )

  local _ = uptimeRevision.value

  local hardwareSnapshot =
      compose.remember(function()
        return compose.hardware()
      end)

  compose.LaunchedEffect(
    "entrypoint-hardware",
    function()
      while true do
        compose.delay(HARDWARE_REFRESH_SECONDS)
        hardwareSnapshot.value = compose.hardware()
      end
    end
  )

  local hardware = hardwareSnapshot.value

  local runtimeMetrics =
      compose.metrics()

  local rendererMetrics =
      compose.rendererMetrics()

  local context = {
    navigation = navigation,
    uptime = compose.uptime(),
    uptimeRevision = uptimeRevision,
    hardware = hardware,
    metrics = {
      cpuPercent = runtimeMetrics.cpuPercent,
      cpuEstimated = runtimeMetrics.cpuEstimated,
      gpuActivityPercent =
          rendererMetrics.gpuActivityPercent,
      gpuEstimated = rendererMetrics.gpuEstimated,
    },
  }

  function context.navigate(key, args)
    return navigation:push(key, args)
  end

  function context.back()
    return navigation:pop()
  end

  local content

  if type(options.content) == "function" then
    content = options.content(context)
  elseif options.content then
    content = options.content
  else
    content = compose.NavDisplay(
      navigation,
      routeProvider(options.routes, context)
    )
  end

  assert(
    type(content) == "table",
    "Entrypoint content must return a node"
  )

  local defaultTopBar = function(scaffoldContext)
    return topAppBar.TopAppBar({
      navigation = navigation,
      onRootAction = scaffoldContext.requestQuit,
      title = options.title,
      point = options.point == false
        and nil
        or navigation:current().key,
      trailing = options.trailing
        or "│uptime " .. formatUptime(context.uptime),
      colors = colors,
      context = context,
      actions = options.topBarActions,
      background = options.surface
        or colors.surface,
    })
  end

  local defaultBottomBar = function()
    local memoryLabel = "RAM --"

    if hardware.memoryPercent ~= nil then
      memoryLabel =
          "RAM "
          .. tostring(hardware.memoryPercent)
          .. "%"
    end

    return commandBar.CommandBar({
      hints = options.hints,
      service = options.service,
      context = context,
      actions = options.bottomBarActions,
      trailing = options.quitHint
        or {
          label = "│" .. memoryLabel,
          color = colors.muted,
        },
      colors = colors,
      background = options.surface
        or colors.surface,
    })
  end

  local overlay

  if options.overlay then
    overlay = function(scaffoldContext)
      return options.overlay(
        context,
        scaffoldContext
      )
    end
  end

  return scaffold.Scaffold({
    background = options.background
      or colors.background,
    navigation = navigation,
    topBar = options.topBar
      or defaultTopBar,
    content = content,
    bottomBar = options.bottomBar
      or defaultBottomBar,
    overlay = overlay,
  })
end

return entrypoint
