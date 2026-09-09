local query = {}

local function text(value)
  if value == nil then
    return nil
  end

  return string.lower(tostring(value))
end

local function fieldValues(value)
  return {
    {
      name = "name",
      value = value.name,
    },
    {
      name = "id",
      value = value.id,
    },
    {
      name = "label",
      value = value.label,
    },
    {
      name = "displayName",
      value = value.displayName,
    },
  }
end

local function substringScore(value, needle)
  local normalized = text(value)

  if not normalized then
    return nil
  end

  if normalized == needle then
    return 100000
  end

  if normalized:sub(1, #needle) == needle then
    return 90000 - (#normalized - #needle)
  end

  local position =
      normalized:find(needle, 1, true)

  if position then
    return 80000
      - position * 10
      - (#normalized - #needle)
  end

  local cursor = 1
  local gaps = 0

  for index = 1, #needle do
    local character = needle:sub(index, index)
    local found = normalized:find(character, cursor, true)

    if not found then
      return nil
    end

    gaps = gaps + found - cursor
    cursor = found + 1
  end

  return 50000 - gaps * 10 - cursor
end

local function identifier(value)
  return tostring(
    value.name
      or value.id
      or value.label
      or value.displayName
      or "?"
  )
end

function query.search(values, needle, limit)
  assert(
    type(values) == "table",
    "Search values must be a table"
  )

  assert(
    type(needle) == "string"
      and needle ~= "",
    "Search query must be a non-empty string"
  )

  local normalizedNeedle =
      string.lower(needle)
  local matches = {}

  for _, value in ipairs(values) do
    if type(value) == "table" then
      local bestScore
      local bestField

      for _, field in ipairs(fieldValues(value)) do
        local score =
            substringScore(field.value, normalizedNeedle)

        if score
            and (
              not bestScore
              or score > bestScore
            )
        then
          bestScore = score
          bestField = field.name
        end
      end

      if bestScore then
        matches[#matches + 1] = {
          value = value,
          score = bestScore,
          field = bestField,
        }
      end
    end
  end

  table.sort(
    matches,
    function(left, right)
      if left.score == right.score then
        return identifier(left.value) < identifier(right.value)
      end

      return left.score > right.score
    end
  )

  local maximum =
      tonumber(limit)

  if maximum
      and maximum >= 0
      and #matches > maximum
  then
    for index = #matches, maximum + 1, -1 do
      matches[index] = nil
    end
  end

  return matches
end

return query
