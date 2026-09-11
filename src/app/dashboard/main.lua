local compose = require("lib.compose.init")

local components = require("lib.components.init")

local telemetry = require("lib.telemetry.receiver")
local telemetryStore = require("lib.telemetry.store")
local incidentDashboard = require("lib.telemetry.incidents.dashboard")
local storage = require("lib.storage.store")

local presenter = require("app.dashboard.presenter")


local colors = components.ColorStyle()
local REFRESH_SECONDS = 1


local receiver =
    telemetry.create()

local dashboard =
    telemetryStore.create()

local incidents =
    incidentDashboard.create({
      history = storage.open(
        "dashboard",
        "incidents",
        {
          version = 1,
          default = function()
            return {resolved = {}}
          end,
        }
      ),
    })

compose.App(function()
  local revision =
      compose.remember(0)

  local refreshPending =
      compose.remember(false)

  compose.DisposableEffect(
    "telemetry-port",
    function()
      local opened, errorMessage = receiver:open()

      assert(
        opened,
        "Dashboard could not open the telemetry modem: "
          .. tostring(errorMessage)
      )

      return function()
        receiver:close()
      end
    end
  )


  compose.LaunchedEffect(
    "telemetry",
    function()
      while true do
        local packet =
            receiver:receive(
              compose.awaitEvent(
                "modem_message"
              )
            )

        if packet then
          local incidentChanged =
              incidents:handle(packet)

          if packet.event == "telemetry" then
            dashboard:update(packet)
          end

          if incidentChanged
              or packet.event == "telemetry"
          then
            refreshPending.value = true
          end
        end
      end
    end
  )

  compose.LaunchedEffect(
    "dashboard-refresh",
    function()
      while true do
        compose.delay(REFRESH_SECONDS)

        if refreshPending.value then
          refreshPending.value = false
          revision.value =
              revision.value + 1
        end
      end
    end
  )

  return components.Entrypoint({
    title = "Dashboard",
    service = "Telemetry :4242",
    topBarActions = function()
      local _ = revision.value
      local sourceCount = dashboard:size()
      local activeIncidentCount = incidents:activeCount()

      return compose.Row({
        compose.Text(
          tostring(sourceCount) .. " SOURCES",
          compose.Modifier:foreground(colors.muted)
        ),
        compose.Spacer(compose.Modifier:width(1)),
        compose.Text(
          "INCIDENTS " .. tostring(activeIncidentCount),
          compose.Modifier:foreground(
            activeIncidentCount > 0
              and colors.bad
              or colors.muted
          )
        ),
      })
    end,
    overlay = function()
      local _ = revision.value
      local currentIncident = incidents:current()

      if not currentIncident then
        return nil
      end

      return components.Dialog(
        "INCIDENT",
        {
          compose.Text(
            currentIncident.title,
            compose.Modifier:foreground(colors.onSurface)
          ),

          compose.Spacer(compose.Modifier:height(1)),

          compose.Text(
            currentIncident.message,
            compose.Modifier:foreground(colors.text)
          ),

          compose.Spacer(compose.Modifier:height(1)),

          compose.Text(
            currentIncident.source
              .. " · "
              .. currentIncident.sourceId
              .. " · "
              .. currentIncident.address:sub(1, 8),
            compose.Modifier:foreground(colors.muted)
          ),

          compose.Spacer(compose.Modifier:height(1)),

          components.Button(
            "CLOSE",
            function()
              if incidents:dismiss(currentIncident.key) then
                revision.value =
                    revision.value + 1
              end
            end,
            compose.Modifier:foreground(colors.primary)
          ),
        },
        compose.Modifier
        :width(40)
        :background(colors.surfaceVariant)
      )
    end,
    content = function()
      local _ = revision.value
      local sources = dashboard:all()
      local sections = presenter.sections(
        sources,
        dashboard,
        colors
      )
      local content = {}

      for _, section in ipairs(sections) do
        content[#content + 1] = components.Section(
          section.title .. " · " .. tostring(section.count),
          {
            components.Grid({
              rows = section.rows,
              columns = section.columns,
              appearance = "alternating",
              oddBackground = colors.surface,
              evenBackground = colors.surfaceVariant,
              horizontalCellPadding = 1,
              cell = section.cell,
              modifier = compose.Modifier:fillMaxWidth(),
            }),
          }
        )

        content[#content + 1] = compose.Spacer(
          compose.Modifier:height(1)
        )
      end

      if #content == 0 then
        content[#content + 1] = compose.Text(
          "WAITING FOR TELEMETRY",
          compose.Modifier:foreground(colors.muted)
        )
      end

      local scrollState = compose.rememberScrollState()

      return compose.Column(
        content,
        compose.Modifier
        :fillMaxWidth()
        :fillMaxHeight()
        :verticalScroll(scrollState)
      )
    end,
  })
end)
