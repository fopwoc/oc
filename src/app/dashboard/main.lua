package.loaded["../lib/compose/init"] = nil
package.loaded["../lib/compose/runtime"] = nil
package.loaded["../lib/compose/nodes"] = nil
package.loaded["../lib/compose/renderer"] = nil
package.loaded["../lib/compose/framebuffer"] = nil
package.loaded["../lib/compose/debug"] = nil
package.loaded["../lib/compose/modifier"] = nil
package.loaded["../lib/compose/layout"] = nil
package.loaded["../lib/compose/input"] = nil
package.loaded["../lib/compose/input_target"] = nil
package.loaded["../lib/compose/scroll"] = nil

package.loaded["../lib/components/init"] = nil
package.loaded["../lib/components/card"] = nil
package.loaded["../lib/components/button"] = nil
package.loaded["../lib/components/toggle"] = nil
package.loaded["../lib/components/dialog"] = nil

package.loaded["../lib/telemetry/receiver"] = nil
package.loaded["../lib/telemetry/protocol"] = nil


local compose = require("../lib/compose/init")

local components = require("../lib/components/init")

local telemetry = require("../lib/telemetry/receiver")

local stateModule = require("../app/dashboard/state")


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


local STALE_AFTER =
    3

local OFFLINE_AFTER =
    10


local receiver =
    telemetry.create()

local dashboard =
    stateModule.create()


receiver:open()


local function sourceStatus(source)
  local age =
      dashboard:age(source)

  if age >= OFFLINE_AFTER then
    return "OFFLINE",
        colors.danger
  end

  if age >= STALE_AFTER then
    return "STALE",
        colors.warning
  end

  return "ONLINE",
      colors.success
end


local function formatAge(age)
  if age < 1 then
    return "<1s"
  end

  return tostring(
    math.floor(age)
  ) .. "s"
end


local function formatUptime(seconds)
  seconds =
      math.floor(
        seconds or 0
      )

  local hours =
      math.floor(
        seconds / 3600
      )

  local minutes =
      math.floor(
        (seconds % 3600) / 60
      )

  if hours > 0 then
    return tostring(hours)
        .. "h "
        .. tostring(minutes)
        .. "m"
  end

  return tostring(minutes)
      .. "m"
end

local function formatNumber(value)
  value =
      math.floor(
        tonumber(value) or 0
      )

  local text =
      tostring(value)

  while true do
    local formatted, count =
        text:gsub(
          "^(-?%d+)(%d%d%d)",
          "%1,%2"
        )

    text = formatted

    if count == 0 then
      break
    end
  end

  return text
end


local function stat(
    label,
    value,
    color
)
  return compose.Column({
    compose.Text(
      label,
      compose.Modifier
      :foreground(
        colors.muted
      )
    ),

    compose.Text(
      formatNumber(value),
      compose.Modifier
      :foreground(
        color or colors.text
      )
    ),
  })
end


local function crafterCard(
    source,
    status,
    statusColor,
    age
)
  local data =
      source.data or {}

  local activity =
      data.playing
      and "RUNNING"
      or "PAUSED"

  local activityColor =
      data.playing
      and colors.success
      or colors.warning

  -- Transport status takes precedence.
  if status ~= "ONLINE" then
    activity =
        status

    activityColor =
        statusColor
  end

  return components.Card(
    {
      compose.Column({
        compose.Row({
            compose.Text(
              source.id,
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
              "● " .. activity,
              compose.Modifier
              :foreground(
                activityColor
              )
            ),
          },
          compose.Modifier
          :fillMaxWidth()
        ),

        compose.Text(
          "CRAFTER",
          compose.Modifier
          :foreground(
            colors.muted
          )
        ),

        compose.Spacer(
          compose.Modifier
          :height(1)
        ),

        compose.Row({
            stat(
              "TARGETS",
              data.targets
            ),

            compose.Spacer(
              compose.Modifier
              :weight(1)
            ),

            stat(
              "CRAFTING",
              data.crafting,
              colors.success
            ),

            compose.Spacer(
              compose.Modifier
              :weight(1)
            ),

            stat(
              "WAITING",
              data.waiting
            ),

            compose.Spacer(
              compose.Modifier
              :weight(1)
            ),

            stat(
              "COOLDOWN",
              data.cooldown,
              colors.warning
            ),
          },
          compose.Modifier
          :fillMaxWidth()
        ),

        compose.Spacer(
          compose.Modifier
          :height(1)
        ),

        compose.Row({
            stat(
              "REQUESTS",
              data.requests
            ),

            compose.Spacer(
              compose.Modifier
              :weight(1)
            ),

            stat(
              "COMPLETED",
              data.completed,
              colors.success
            ),

            compose.Spacer(
              compose.Modifier
              :weight(1)
            ),

            stat(
              "CANCELED",
              data.canceled,
              colors.danger
            ),

            compose.Spacer(
              compose.Modifier
              :weight(1)
            ),
          },
          compose.Modifier
          :fillMaxWidth()
        ),

        compose.Spacer(
          compose.Modifier
          :height(1)
        ),

        compose.Text(
          "seen "
          .. formatAge(age)
          .. " ago"
          .. "   uptime "
          .. formatUptime(
            source.remoteUptime
          )
          .. (
            source.distance
            and (
              "   distance "
              .. tostring(
                math.floor(
                  source.distance
                )
              )
              .. "m"
            )
            or ""
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
          activityColor,
    }
  )
end


local function genericCard(
    source,
    status,
    statusColor,
    age
)
  return components.Card(
    {
      compose.Column({
        compose.Row({
            compose.Text(
              source.id,
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
              "● " .. status,
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
          source.source
          .. "   seen "
          .. formatAge(age)
          .. " ago"
          .. "   uptime "
          .. formatUptime(
            source.remoteUptime
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
          statusColor,
    }
  )
end

compose.App(function()
  local revision =
      compose.remember(0)


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
          dashboard:update(packet)

          revision.value =
              revision.value + 1
        end
      end
    end
  )

  compose.LaunchedEffect(
    "clock",
    function()
      while true do
        compose.delay(1)

        revision.value =
            revision.value + 1
      end
    end
  )


  local _ =
      revision.value

  local sources =
      dashboard:all()

  local rows = {
    compose.Row({
        compose.Text(
          "DASHBOARD",
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
          tostring(#sources)
          .. " SOURCES",
          compose.Modifier
          :foreground(
            colors.muted
          )
        ),
      },
      compose.Modifier
      :fillMaxWidth()
    ),

    compose.Spacer(
      compose.Modifier
      :height(1)
    ),
  }


  if #sources == 0 then
    rows[#rows + 1] =
        compose.Text(
          "Waiting for telemetry...",
          compose.Modifier
          :foreground(
            colors.muted
          )
        )
  end


  for _, source in ipairs(
    sources
  ) do
    local status,
    statusColor =
        sourceStatus(source)

    local age =
        dashboard:age(source)

    if source.source == "crafter" then
      rows[#rows + 1] =
          crafterCard(
            source,
            status,
            statusColor,
            age
          )
    else
      rows[#rows + 1] =
          genericCard(
            source,
            status,
            statusColor,
            age
          )
    end

    rows[#rows + 1] =
        compose.Spacer(
          compose.Modifier
          :height(1)
        )
  end


  rows[#rows + 1] =
      compose.Spacer(
        compose.Modifier
        :weight(1)
      )


  rows[#rows + 1] =
      compose.Row({
          compose.Text(
            "Telemetry :4242",
            compose.Modifier
            :foreground(
              colors.muted
            )
          ),

          compose.Spacer(
            compose.Modifier
            :weight(1)
          ),

          compose.Text(
            "Q to exit",
            compose.Modifier
            :foreground(
              colors.muted
            )
          ),
        },
        compose.Modifier
        :fillMaxWidth()
      )


  return compose.Column(
    rows,
    compose.Modifier
    :fillMaxWidth()
    :fillMaxHeight()
    :background(
      colors.background
    )
    :foreground(
      colors.text
    )
    :padding(1)
  )
end)
