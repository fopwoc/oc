local components = {}

local card = require("../lib/components/card")
local button = require("../lib/components/button")
local toggle = require("../lib/components/toggle")
local dialog = require("../lib/components/dialog")

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

return components
