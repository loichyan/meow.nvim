local M = {}
local shared = require("spark.shared")
local utils = require("spark.utils")
local DEFAULT = shared.DEFAULT_RESOLVER_SPEC
local State = shared.SpecState

---@param specs Spark.Spec[]
---@return Spark.Spec[]|nil,nil|string
local function resovle_after(specs)
  local nodes = {}
  for _, spec in ipairs(specs) do
    nodes[spec[1]] = {
      spec,
      visited = false,
      resolved = false,
    }
  end

  local resolved = {}
  ---@param spec Spark.Spec
  ---@return Spark.Spec.State|nil,nil|string
  local function visit(spec)
    local name = spec[1]
    local node = nodes[name]
    -- Reference to a resolved node, skip.
    if node.resolved then
      return spec._state
    end
    -- If a node is visited twice, there's a cycle.
    if node.visited then
      return nil, string.format("circular 'after' reference in '%s'", name)
    end
    node.visited = true
    -- Visit all ancestors and mark as resolved.
    local to_load = true
    for _, parent_name in ipairs(spec.after) do
      local parent = nodes[parent_name]
      if parent == nil then
        return nil,
          string.format(
            "undefined 'after' reference '%s' in '%s'",
            parent_name,
            name
          )
      end
      local state, msg = visit(parent[1])
      if state == nil then
        return nil, msg
      elseif state ~= State.Load and state ~= State.Loaded then
        -- Only load when all dependences are loaded.
        to_load = false
      end
    end
    if not to_load then
      spec._state = nil
    end
    node.resolved = true
    table.insert(resolved, spec)
    return spec._state
  end

  for _, spec in ipairs(specs) do
    local state, msg = visit(spec)
    if state == nil then
      return nil, msg
    end
  end
  return resolved
end

---@param specs Spark.Spec[]
---@return Spark.Spec[]|nil,nil|string
function M.resolve(specs)
  local orig = specs
  specs = {}
  for _, spec in ipairs(orig) do
    table.insert(specs, utils.deep_merge(false, {}, spec, DEFAULT))
  end
  specs = utils.merge_sort(specs, function(t1, t2)
    return t1.priority - t2.priority
  end)
  return resovle_after(specs)
end

return M
