local series = {}

function series.downsample(values, limit)
  assert(
    type(values) == "table",
    "series.downsample requires a values table"
  )

  assert(
    type(limit) == "number"
      and limit >= 1
      and limit % 1 == 0,
    "series.downsample requires a positive integer limit"
  )

  if #values <= limit then
    return values
  end

  if limit == 1 then
    return {values[1]}
  end

  local result = {}
  local step = (#values - 1) / (limit - 1)

  for index = 0, limit - 1 do
    local sourceIndex = math.floor(index * step + 1.5)
    result[#result + 1] = values[sourceIndex]
  end

  return result
end

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
