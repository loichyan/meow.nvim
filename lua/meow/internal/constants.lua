local Constants = {}

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

return Constants
