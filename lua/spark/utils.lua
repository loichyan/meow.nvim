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

return M
