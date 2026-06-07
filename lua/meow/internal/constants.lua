local Constants = {}

---@diagnostic disable: invisible

---Denotes whether a plugin is activated or loaded.
---
---Possible values are:
---  * ACTIVATED : Added to vim.pack, but not loaded.
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

Constants.PluginStateNames = {}
for key, value in pairs(Constants.PluginState) do
  Constants.PluginStateNames[value] = key
end

-- stylua: ignore
---@type table<string,'deprecated'|'primitive'|'list'|'table'>
Constants.SPEC_VTYPES = {
  src          = 'primitive',
  version      = 'primitive',
  source       = 'deprecated',
  checkout     = 'deprecated',
  monitor      = 'deprecated',
  hooks        = 'deprecated',

  shadow       = 'primitive',
  enabled      = 'primitive',
  cond         = 'primitive',
  priority     = 'primitive',

  lazy         = 'primitive',
  event        = 'list',
  ft           = 'list',
  module       = 'list',

  init         = 'primitive',
  config       = 'primitive',

  dependencies = 'list',
  import       = 'list',
}

Constants.cache_version = 1

---@type MeoSpecCond
Constants.default_spec_lazy = function(plugin)
  return not not (plugin._is_dep or plugin.event or plugin.ft or plugin.module)
end

return Constants
