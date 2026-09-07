local filesystem =
    require("filesystem")

local shell =
    require("shell")

local compose =
    require("lib.compose.init")

local components =
    require("lib.components.init")

local schedulerModule =
    require("app.crafter.scheduler")

local telemetry =
    require("lib.telemetry.sender")


local CONFIG_PATH =
    filesystem.canonical(
      filesystem.concat(
        shell.getWorkingDirectory(),
        "app/crafter/config.lua"
      )
    )

local CONFIG_EXAMPLE_PATH =
    filesystem.canonical(
      filesystem.concat(
        shell.getWorkingDirectory(),
        "app/crafter/config.example.lua"
      )
    )


local colors = {
  background = 0x111418,
  surface = 0x1A2026,
  border = 0x36414A,

  primary = 0x66CCFF,
  text = 0xD8DEE9,
  muted = 0x7F8C98,

  success = 0x66CC88,
  warning = 0xDDBB66,
  danger = 0xDD6666,
}


local function loadConfig()
  if not filesystem.exists(
        CONFIG_PATH
      ) then
    error(
      "Crafter configuration not found.\n"
      .. "\n"
      .. "Copy:\n"
      .. "  "
      .. CONFIG_EXAMPLE_PATH
      .. "\n"
      .. "to:\n"
      .. "  "
      .. CONFIG_PATH
      .. "\n"
      .. "\n"
      .. "Then edit config.lua and restart Crafter."
    )
  end

  local ok, config =
      pcall(
        dofile,
        CONFIG_PATH
      )

  if not ok then
    error(
      "Failed to load Crafter configuration:\n"
      .. tostring(config)
    )
  end

  return config
end


local function statusInfo(target)
  if target.status == "crafting" then
    return "CRAFTING",
        colors.success
  end

  if target.status == "cooldown" then
    return "COOLDOWN",
        colors.warning
  end

  return "WAITING",
      colors.muted
end


local function telemetryState(
    scheduler,
    playing
)
  local crafting = 0
  local waiting = 0
  local cooldown = 0

  local requests = 0
  local completed = 0
  local canceled = 0

  for _, target in ipairs(
    scheduler.targets
  ) do
    if target.status == "crafting" then
      crafting =
          crafting + 1
    elseif target.status == "cooldown" then
      cooldown =
          cooldown + 1
    else
      waiting =
          waiting + 1
    end

    requests =
        requests
        + target.requests

    completed =
        completed
        + target.completed

    canceled =
        canceled
        + target.canceled
  end

  return {
    playing =
        playing,

    targets =
        #scheduler.targets,

    crafting =
        crafting,

    waiting =
        waiting,

    cooldown =
        cooldown,

    requests =
        requests,

    completed =
        completed,

    canceled =
        canceled,
  }
end


local config =
    loadConfig()

local scheduler =
    schedulerModule.create(
      config
    )

local telemetrySender =
    telemetry.create({
      source = "crafter",
      id = "main-crafter",
    })


compose.App(function()
  local playing =
      compose.remember(true)

  local revision =
      compose.remember(0)


  compose.LaunchedEffect(
    "scheduler",
    function()
      while true do
        scheduler:step(
          playing.value
        )

        revision.value =
            revision.value + 1

        compose.delay(0.25)
      end
    end
  )


  compose.LaunchedEffect(
    "telemetry",
    function()
      while true do
        telemetrySender:send(
          telemetryState(
            scheduler,
            playing.value
          )
        )

        compose.delay(1)
      end
    end
  )


  --
  -- Depend on scheduler snapshots.
  --
  local _ =
      revision.value


  local rows = {}


  for _, target in ipairs(
    scheduler.targets
  ) do
    local status,
    statusColor =
        statusInfo(target)

    rows[#rows + 1] =
        components.Card(
          {
            compose.Column({
              compose.Row({
                  compose.Text(
                    target.label,
                    compose.Modifier
                    :foreground(
                      colors.primary
                    )
                  ),

                  compose.Spacer(
                    compose.Modifier
                    :weight(1)
                  ),

                  compose.Text(
                    status,
                    compose.Modifier
                    :foreground(
                      statusColor
                    )
                  ),
                },
                compose.Modifier
                :fillMaxWidth()
              ),

              compose.Text(
                "amount "
                .. tostring(
                  target.amount
                )
                .. "   done "
                .. tostring(
                  target.completed
                )
                .. "   canceled "
                .. tostring(
                  target.canceled
                )
                .. "   requests "
                .. tostring(
                  target.requests
                ),
                compose.Modifier
                :foreground(
                  colors.muted
                )
              ),
            })
          },

          compose.Modifier
          :fillMaxWidth()
          :background(
            colors.surface
          ),

          {
            color =
                target.status == "crafting"
                and colors.success
                or colors.border,
          }
        )

    rows[#rows + 1] =
        compose.Spacer(
          compose.Modifier
          :height(1)
        )
  end


  rows[#rows + 1] =
      compose.Spacer(
        compose.Modifier:weight(1)
      )

  return components.Entrypoint({
    title = "Crafter",
    colors = colors,
    service = "scheduler",
    topBarActions = function()
      return compose.Text(
        playing.value
        and "● RUNNING"
        or "● PAUSED",
        compose.Modifier:foreground(
          playing.value
          and colors.success
          or colors.danger
        )
      )
    end,
    bottomBarActions = function()
      return components.Button(
        playing.value
        and "PAUSE"
        or "PLAY",
        function()
          playing.value = not playing.value
        end,
        compose.Modifier:foreground(
          playing.value
          and colors.warning
          or colors.success
        )
      )
    end,
    content = compose.Column(
      rows,
      compose.Modifier
      :fillMaxWidth()
      :fillMaxHeight()
      :padding(1)
    ),
  })
end)
