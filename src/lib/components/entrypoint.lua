local compose = require("lib.compose.init")
local scaffold = require("lib.components.scaffold")
local topAppBar = require("lib.components.top_app_bar")
local commandBar = require("lib.components.command_bar")
local colorStyle = require("lib.components.color_style")

-- Uncomment while debugging recomposition: require("lib.compose.debug").setEnabled(true)

local entrypoint = {}
local HARDWARE_REFRESH_SECONDS = 3

local function formatUptime(seconds)
  seconds = math.floor(seconds)

  if seconds >= 24 * 60 * 60 then
    return string.format(
      "%dd %02dh",
      math.floor(seconds / (24 * 60 * 60)),
      math.floor(seconds / (60 * 60)) % 24
    )
  end

  if seconds >= 60 * 60 then
    return string.format(
      "%dh %02dm",
      math.floor(seconds / (60 * 60)),
      math.floor(seconds / 60) % 60
    )
  end

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

  local contentPadding = options.contentPadding

  if contentPadding == nil then
    contentPadding = 1
  end

  assert(
    type(contentPadding) == "number"
      and contentPadding >= 0,
    "Entrypoint contentPadding must be non-negative"
  )

  local colors =
      colorStyle.defaults()

  if options.colorStyle
      or options.colors
  then
    colors =
        colorStyle.create(
          options.colorStyle
          or options.colors
        )
  end

  return colorStyle.with(colors, function()

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

  local context = {
    colorStyle = colors,
    colors = colors,
    navigation = navigation,
    uptimeRevision = uptimeRevision,
  }

  setmetatable(context, {
    __index = function(_, key)
      if key == "uptime" then
        local _ = uptimeRevision.value
        return compose.uptime()
      end

      if key == "hardware" then
        return hardwareSnapshot.value
      end

      if key == "metrics" then
        local _ = uptimeRevision.value
        local runtimeMetrics = compose.metrics()
        local rendererMetrics = compose.rendererMetrics()

        return {
          cpuPercent = runtimeMetrics.cpuPercent,
          cpuEstimated = runtimeMetrics.cpuEstimated,
          gpuActivityPercent =
              rendererMetrics.gpuActivityPercent,
          gpuEstimated = rendererMetrics.gpuEstimated,
        }
      end
    end,
  })

  function context.navigate(key, args)
    return navigation:push(key, args)
  end

  function context.back()
    return navigation:pop()
  end

  local content = compose.RecomposeScope(
    "entrypoint-content",
    function()
      local node

      if type(options.content) == "function" then
        node = options.content(context)
      elseif options.content then
        node = options.content
      else
        node = compose.NavDisplay(
          navigation,
          routeProvider(options.routes, context)
        )
      end

      assert(
        type(node) == "table",
        "Entrypoint content must return a node"
      )

      return compose.Box(
        {node},
        compose.Modifier
        :fillMaxWidth()
        :fillMaxHeight()
        :padding(contentPadding)
      )
    end
  )

  local defaultTopBar = function(scaffoldContext)
    return topAppBar.TopAppBar({
      navigation = navigation,
      onRootAction = scaffoldContext.requestQuit,
      title = options.title,
      trailing = options.trailing
        or "UP " .. formatUptime(context.uptime),
      colorStyle = colors,
      context = context,
      actions = options.topBarActions,
      background = options.surface
        or colors.surfaceVariant,
    })
  end

  local defaultBottomBar = function()
    local hardware = context.hardware
    local memoryLabel = "RAM --"

    if hardware.memoryPercent ~= nil then
      memoryLabel =
          "RAM "
          .. tostring(hardware.memoryPercent)
          .. "%"
    end

    return commandBar.CommandBar({
      hints = options.hints,
      service = type(options.service) == "string"
        and {
          label = options.service,
          color = colors.muted,
        }
        or options.service,
      context = context,
      actions = options.bottomBarActions,
      trailing = options.quitHint
        or {
          label = memoryLabel,
          color = colors.muted,
        },
      colorStyle = colors,
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

  local function scopedSlot(key, slot)
    return function(scaffoldContext)
      return compose.RecomposeScope(
        key,
        function()
          if type(slot) == "function" then
            return slot(scaffoldContext)
          end

          return slot
        end
      )
    end
  end

  return scaffold.Scaffold({
    background = options.background
      or colors.background,
    navigation = navigation,
    topBar = scopedSlot(
      "entrypoint-top-bar",
      options.topBar or defaultTopBar
    ),
    content = content,
    bottomBar = scopedSlot(
      "entrypoint-bottom-bar",
      options.bottomBar or defaultBottomBar
    ),
    overlay = overlay,
  })
  end)
end

return entrypoint
