package.path = "src/?.lua;" .. package.path

local previousGrid = package.loaded["lib.components.grid"]
local previousPresenter = package.loaded["app.dashboard.presenter"]

package.loaded["lib.components.grid"] = {
  GridCells = function()
    return {
      colored = function(_, value, color)
        return {text = tostring(value), color = color}
      end,
      render = function()
      end,
    }
  end,
}
package.loaded["app.dashboard.presenter"] = nil

local presenter = require("app.dashboard.presenter")
local colors = {
  primary = 1,
  text = 2,
  muted = 3,
  good = 4,
  warning = 5,
  bad = 6,
}
local dashboard = {
  age = function()
    return 0
  end,
}
local sections = presenter.sections({
  {
    source = "crafter",
    id = "main",
    remoteUptime = 60,
    data = {
      type = "crafter",
      playing = false,
      targets = 3,
      crafting = 1,
      requesting = 1,
      waiting = 1,
      cooldown = 0,
      completedPerHour = 12.5,
      satisfaction = 50,
      targetMetrics = {
        {
          label = "Ironwood Ingot",
          currentAmount = 0,
          targetAmount = 1,
          status = "crafting",
          completedPerHour = 1,
        },
        {
          label = "Ironwood Dust",
          currentAmount = 0,
          targetAmount = 1,
          status = "requesting",
          completedPerHour = 2,
        },
      },
    },
  },
}, dashboard, colors)

assert(
  #sections == 1
    and sections[1].count == 1
    and #sections[1].columns == 8
    and #sections[1].rows == 2,
  "dashboard should render one eight-column summary row per crafter"
)

assert(
  sections[1].rows[1][5] == "SAT",
  "crafter summaries should label target satisfaction explicitly"
)

for _, row in ipairs(sections[1].rows) do
  assert(
    #row == #sections[1].columns,
    "dashboard rows must match their column definitions"
  )
end

assert(
  sections[1].rows[2][2].text == "PAUSED"
    and sections[1].rows[2][3].text == "3"
    and sections[1].rows[2][4].text == "2"
    and sections[1].rows[2][5].text == "50%"
    and sections[1].rows[2][6].text == "12.5",
  "crafter summaries should expose activity and target satisfaction"
)

local powerSections = presenter.sections({
  {
    source = "power_monitor",
    id = "power",
    remoteUptime = 120,
    data = {
      type = "power_monitor",
      state = "NORMAL",
      fill = 1,
      averageFill24h = 1,
      net = 0,
    },
  },
}, dashboard, colors)

assert(
  #powerSections[1].columns == 9
    and powerSections[1].rows[1][8] == "SEEN"
    and powerSections[1].rows[1][9] == "UP"
    and powerSections[1].rows[2][9].text == "2m",
  "power rows should use the shared SEEN and UP suffix"
)

local drainingSections = presenter.sections({
  {
    source = "production_line",
    id = "line",
    remoteUptime = 120,
    data = {
      type = "production_line",
      state = "DRAINING",
      efficiency = 0,
      health = 70,
    },
  },
}, dashboard, colors)

assert(
  drainingSections[1].rows[2][2].color == colors.warning
    and drainingSections[1].rows[2][5].color == colors.warning,
  "draining production lines should be presented as warnings"
)

local allSections = presenter.sections({
  {
    source = "crafter",
    id = "crafter",
    remoteUptime = 1,
    data = {type = "crafter", playing = true, targets = 0},
  },
  {
    source = "power_monitor",
    id = "power",
    remoteUptime = 1,
    data = {type = "power_monitor", state = "NORMAL"},
  },
  {
    source = "production_line",
    id = "line",
    remoteUptime = 1,
    data = {type = "production_line", state = "HEALTHY"},
  },
  {
    source = "custom",
    id = "custom",
    remoteUptime = 1,
    data = {type = "custom"},
  },
}, dashboard, colors)

for _, section in ipairs(allSections) do
  local header = section.rows[1]

  assert(
    header[#header - 1] == "SEEN"
      and header[#header] == "UP",
    "every dashboard section should end with SEEN and UP"
  )

  for _, row in ipairs(section.rows) do
    assert(
      #row == #section.columns,
      "every dashboard row should match its column definition"
    )
  end

  if section.title == "PRODUCTION LINES" then
    assert(
      header[4] == "KEEP-UP",
      "production-line efficiency should use an operational label"
    )
  end
end

package.loaded["lib.components.grid"] = previousGrid
package.loaded["app.dashboard.presenter"] = previousPresenter

print("dashboard presenter: OK")
