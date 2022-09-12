local M = {}

---@vararg string
function M.join_paths(...)
  return table.concat({ ... }, "/")
end

---@param force boolean
---@param t1 table
---@vararg table
---@return table
function M.deep_merge(force, t1, ...)
  for _, t2 in ipairs({ ... }) do
    for k, v2 in pairs(t2) do
      local v1 = t1[k]
      if type(v1) == "table" and type(v2) == "table" then
        M.deep_merge(force, v1, v2)
      elseif force then
        t1[k] = v2
      elseif v1 == nil then
        t1[k] = v2
      end
    end
  end
  return t1
end

---@generic T
---@param list T[]
---@param cmp fun(t1:T,t2:T):number
---@return T[]
function M.merge_sort(list, cmp)
  local len = #list + 1
  local sorted = {}
  local seg = 1
  repeat
    for start = 1, len - 1, seg * 2 do
      local start1 = start
      local end1 = math.min(start + seg, len)
      local start2 = end1
      local end2 = math.min(start + seg * 2, len)
      while start1 < end1 and start2 < end2 do
        local t1 = list[start1]
        local t2 = list[start2]
        if cmp(t1, t2) <= 0 then
          start1 = start1 + 1
          table.insert(sorted, t1)
        else
          start2 = start2 + 1
          table.insert(sorted, t2)
        end
      end
      for i = start1, end1 - 1 do
        table.insert(sorted, list[i])
      end
      for i = start2, end2 - 1 do
        table.insert(sorted, list[i])
      end
    end
    list = sorted
    sorted = {}
    seg = seg * 2
  until seg >= len
  return list
end

return M
