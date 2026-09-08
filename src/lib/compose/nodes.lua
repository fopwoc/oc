local nodes = {}

local function createNode(nodeType, modifier, props)
  return {
    type = nodeType,
    modifier = modifier,
    props = props or {},
  }
end

function nodes.Text(text, modifier)
  return createNode(
    "text",
    modifier,
    {
      text = tostring(text),
    }
  )
end

function nodes.Column(children, modifier)
  return createNode(
    "column",
    modifier,
    {
      children = children or {},
    }
  )
end

function nodes.Row(children, modifier)
  return createNode(
    "row",
    modifier,
    {
      children = children or {},
    }
  )
end

function nodes.Box(children, modifier)
  return createNode(
    "box",
    modifier,
    {
      children = children or {},
    }
  )
end

function nodes.Spacer(modifier)
  return createNode(
    "spacer",
    modifier
  )
end

return nodes
