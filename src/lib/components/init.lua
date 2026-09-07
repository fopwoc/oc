local components = {}

local card = require("lib.components.card")
local button = require("lib.components.button")
local toggle = require("lib.components.toggle")
local dialog = require("lib.components.dialog")
local scaffold = require("lib.components.scaffold")
local topAppBar = require("lib.components.top_app_bar")
local commandBar = require("lib.components.command_bar")
local grid = require("lib.components.grid")
local entrypoint = require("lib.components.entrypoint")
local accordion = require("lib.components.accordion")
local bufferView = require("lib.components.buffer_view")

components.Card =
    card.Card

components.Button =
    button.Button

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

components.Entrypoint =
    entrypoint.Entrypoint

components.Accordion =
    accordion.Accordion

components.BufferView =
    bufferView.BufferView

return components
