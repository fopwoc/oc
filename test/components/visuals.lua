package.path = "src/?.lua;" .. package.path

local nodes = require("lib.compose.nodes")
local modifier = require("lib.compose.modifier")

local previousCompose = package.loaded["lib.compose.init"]
local previousGrid = package.loaded["lib.components.grid"]
local previousCard = package.loaded["lib.components.card"]
local previousSection = package.loaded["lib.components.section"]

package.loaded["lib.compose.init"] = {
  Modifier = modifier.Modifier,
  Text = nodes.Text,
  Column = nodes.Column,
  Row = nodes.Row,
  Box = nodes.Box,
  Spacer = nodes.Spacer,
}
package.loaded["lib.components.grid"] = nil
package.loaded["lib.components.card"] = nil
package.loaded["lib.components.section"] = nil

local grid = require("lib.components.grid")
local section = require("lib.components.section")

local tableNode = grid.Grid({
  rows = {{"VALUE"}},
  horizontalCellPadding = 1,
})
local cell = tableNode.props.children[1].props.children[1]
local padding

for _, element in ipairs(cell.modifier.elements) do
  if element.type == "padding" then
    padding = element
  end
end

assert(
  padding
    and padding.left == 1
    and padding.right == 1
    and padding.top == 0
    and padding.bottom == 0,
  "compact grids should separate columns without increasing row height"
)

local panel = section.Section("STATUS", {
  nodes.Text("healthy"),
})
local panelContent = panel.props.children[1]
local panelPadding

for _, element in ipairs(panel.modifier.elements) do
  if element.type == "padding" then
    panelPadding = element
  end
end

assert(
  panelPadding
    and panelPadding.left == 0
    and #panelContent.props.children == 2
    and panelContent.props.children[1].type == "row"
    and panelContent.props.children[2].type == "column",
  "sections should use an integrated heading row and compact body"
)

package.loaded["lib.compose.init"] = previousCompose
package.loaded["lib.components.grid"] = previousGrid
package.loaded["lib.components.card"] = previousCard
package.loaded["lib.components.section"] = previousSection

print("visual components: OK")
