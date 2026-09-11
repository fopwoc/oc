local series = {}

function series.resample(values, limit)
  assert(
    type(values) == "table",
    "series.resample requires a values table"
  )

  assert(
    type(limit) == "number"
      and limit >= 1
      and limit % 1 == 0,
    "series.resample requires a positive integer limit"
  )

  if #values <= limit then
    return values
  end

  local result = {}

  for index = 1, limit do
    local sourceIndex = math.floor(
      index * #values / limit
    )

    sourceIndex = math.max(1, sourceIndex)
    result[index] = values[sourceIndex]
  end

  return result
end

return series
