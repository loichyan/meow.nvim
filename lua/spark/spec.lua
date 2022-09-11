local M = {}
local shared = require("spark.shared")
local utils = require("spark.utils")
local DEFAULT = shared.DEFAULT_SPEC

---@param spec Spark.Spec
---@return string|Spark.Spec
function M.validate(spec)
  local orig = spec
  -- Merge with default values.
  spec = utils.deep_merge(false, {}, spec, DEFAULT)

  local name = spec[1]
  if name == "" then
    return string.format(
      "plugin name must be specified for %s",
      vim.inspect(orig)
    )
  end
  local prefix = string.format("(%s) ", name)
  --TODO: validate path
  if spec.from ~= nil then
    spec.from = "https://github.com/" .. spec.from
  end
  if spec.start and spec.disable then
    return prefix .. "a start plugin must be enabled"
  end
  return spec
end

return M
