---@alias Spark.Use fun(spec:Spark.Spec)

local M = {}
local utils = require("spark.utils")
local levels = vim.log.levels

---@enum Spark.Log.Level
M.LogLevel = {
  Debug = levels.DEBUG,
  Info = levels.INFO,
  Warn = levels.WARN,
  Error = levels.ERROR,
}

---@enum Spark.Spec.State
M.SpecState = {
  Move = "MOVE",
  Clone = "CLONE",
  Remove = "REMOVE",
  Load = "LOAD",
  Loaded = "LOADED",
}

---@class Spark.Config
M.CONFIG = {
  ---@type fun(use:Spark.Use)
  [1] = function() end,
  ---@type string
  root = utils.join_paths(vim.fn.stdpath("data"), "site/pack/spark"),
  ---@type fun(spec:Spark.Spec)
  after_load = function() end,
  log = {
    ---@type Spark.Log.Level
    level = M.LogLevel.Warn,
  },
}

---@type Spark.Spec[]
M.PLUGINS = {}

---@class Spark.Spec
M.DEFAULT_SPEC = {
  ---@type string
  [1] = "",
  ---@type string|nil
  from = nil,
  ---@type boolean
  start = false,
  ---@type boolean
  disable = false,
  ---@type number
  priority = 0,
  ---@type string[]
  after = {},
  ---@type Spark.Spec.State|nil
  _state = nil,
}

return M
