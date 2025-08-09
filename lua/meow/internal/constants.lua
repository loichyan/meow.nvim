local Constants = {}

---@diagnostic disable: invisible

---Denotes whether a plugin is activated or loaded.
---
---Possible values are:
---  * ACTIVATED : Added to MiniDeps, but not loaded.
---  * LOADING   : In the loading progress.
---  * LOADED    : Loaded and initialized.
---  * DISABLED  : Disabled and never to be loaded.
---@enum MeoPluginState
Constants.PluginState = {
  NONE = 0,
  ACTIVATED = 1,
  LOADING = 2,
  LOADED = 3,
  IGNORED = 4,
  DISABLED = 5,
}

---@type table<string,"primitive"|"list"|"table">
Constants.SPEC_VTYPES = {
  source = "primitive",
  checkout = "primitive",
  monitor = "primitive",
  hooks = "table",

  shadow = "primitive",
  enabled = "primitive",
  cond = "primitive",
  priority = "primitive",

  lazy = "primitive",
  event = "list",
  ft = "list",
  module = "list",

  init = "primitive",
  config = "primitive",

  dependencies = "list",
  import = "list",
}

---@type string[]
Constants.MINI_SPEC_KEYS = {
  "name",
  "source",
  "checkout",
  "monitor",
  "hooks",
}

Constants.cache_version = 1

Constants.is_mini = function(string) return vim.startswith(string, "mini.") end

---@type MeoSpecCond
Constants.default_spec_shadow = function(plugin)
  return Constants.is_mini(plugin.name) and plugin.name ~= "mini.nvim"
end

---@type MeoSpecCond
Constants.default_spec_lazy = function(plugin)
  return not not (plugin._is_dep or plugin.event or plugin.ft or plugin.module)
end

return Constants
