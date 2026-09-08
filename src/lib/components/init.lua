local components = {}

local card = require("lib.components.card")
local button = require("lib.components.button")
local eventConsumer = require("lib.components.event_consumer")
local toggle = require("lib.components.toggle")
local dialog = require("lib.components.dialog")
local scaffold = require("lib.components.scaffold")
local topAppBar = require("lib.components.top_app_bar")
local commandBar = require("lib.components.command_bar")
local grid = require("lib.components.grid")
local entrypoint = require("lib.components.entrypoint")
local colorStyle = require("lib.components.color_style")
local accordion = require("lib.components.accordion")
local bufferView = require("lib.components.buffer_view")
local progress = require("lib.components.progress")
local barChart = require("lib.components.bar_chart")
local areaChart = require("lib.components.area_chart")
local section = require("lib.components.section")
local telemetryStatus = require("lib.components.telemetry_status")

components.Card =
    card.Card

components.Button =
    button.Button

components.ButtonStyles =
    button.styles

components.EventConsumer =
    eventConsumer.EventConsumer

components.Toggle =
    toggle.Toggle

components.ToggleStyles =
    toggle.styles

components.Dialog =
    dialog.Dialog

components.Scaffold =
    scaffold.Scaffold

components.TopAppBar =
    topAppBar.TopAppBar

components.CommandBar =
    commandBar.CommandBar

components.Grid =
    grid.Grid

components.GridCells =
    grid.GridCells

components.Entrypoint =
    entrypoint.Entrypoint

components.ColorStyle =
    colorStyle.ColorStyle

components.Accordion =
    accordion.Accordion

components.BufferView =
    bufferView.BufferView

components.Progress =
    progress.Progress

components.BarChart =
    barChart.BarChart

components.AreaChart =
    areaChart.AreaChart

components.Section =
    section.Section

components.TelemetryStatus =
    telemetryStatus.TelemetryStatus

return components
