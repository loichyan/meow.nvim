local M = {}
local shared = require("spark.shared")
local Level = shared.LogLevel
local CONFIG = shared.CONFIG

---@param msg string
---@param level Spark.Log.Level
local function log(msg, level)
  if level >= CONFIG.log.level then
    vim.notify(msg, level)
  end
end

---@param msg string
function M.info(msg)
  log(msg, Level.Info)
end

---@param msg string
function M.warn(msg)
  log(msg, Level.Warn)
end

---@param msg string
function M.error(msg)
  log(msg, Level.Error)
end

---@param msg string
function M.debug(msg)
  log(msg, Level.Debug)
end

return M
