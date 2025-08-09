local Constants = require("meow.internal.constants")
local PluginState = Constants.PluginState

---@class MeoPlugin
---@field name string
---@field source? string
---@field checkout? string
---@field monitor? string
---@field hooks? MeoSpecHooks
---@field shadow? MeoSpecCond
---@field enabled? MeoSpecCond
---@field cond? MeoSpecCond
---@field priority integer
---@field lazy? MeoSpecCond
---@field event? string[]
---@field ft? string[]
---@field module? string[]
---@field init fun(self:MeoPlugin)|nil
---@field config fun(self:MeoPlugin)|nil
---@field dependencies? (string|MeoSpec)[]
---@field import? string[]
---The installation location of this plugin.
---@field private _path string
---Whether added as a dependency.
---@field private _is_dep? boolean
---A set of dependency names.
---@field private _deps? table<string,true>
---The registration index of this plugin.
---@field private _idx integer
---The level of this plugin in the dependency graph of a resolved plugin.
---@field private _level integer
---The loading state of this plugin.
---@field private _state MeoPluginState
local Plugin = {}

---Creates a new plugin instance.
---@param name string
---@param idx integer
---@return MeoPlugin
function Plugin.new(name, idx)
  return setmetatable({
    name = name,
    priority = 50,
    _idx = idx,
    _level = 0,
  }, { __index = Plugin })
end

---Returns the installation location of this plugin.
---
---This function always returns a path, whether or not the plugin is a shadow
---plugin install. Therefore, the caller should perform necessary checks before
---asserting the existence of the returned path.
---@return string
function Plugin:path()
  if not self._path then
    self._path = vim.fs.normalize(MiniDeps.config.path.package .. "/pack/deps/opt/" .. self.name)
  end
  return self._path
end

---Returns whether this plugin is loaded.
---@return boolean
function Plugin:is_loaded() return self._state == PluginState.LOADED end

---Returns whether this plugin will be loaded.
function Plugin:will_load() return self:_get_state() < PluginState.IGNORED end

---Returns `shadow == true`.
---@return boolean
function Plugin:is_shadow() return self:_get_cond("shadow", Constants.default_spec_shadow) end

---Returns `enabled == true`.
---@return boolean
function Plugin:is_enabled() return self:_get_cond("enabled", true) end

---Returns `cond == false`.
---@return boolean
function Plugin:is_ignored() return not self:_get_cond("cond", true) end

---Returns `lazy == true`.
function Plugin:is_lazy() return self:_get_cond("lazy", Constants.default_spec_lazy) end

---Resolves the specified conditional field.
---@private
---@param key "shadow"|"enabled"|"cond"|"lazy"
---@param default MeoSpecCond
---@return boolean
function Plugin:_get_cond(key, default)
  local val = self[key]
  if type(val) == "boolean" then return val end
  if val == nil then val = default end
  if type(val) == "function" then val = val(self) end
  self[key] = not not val
  return self[key]
end

---Infers the state of this plugin.
---@private
---@return MeoPluginState
function Plugin:_get_state()
  if self._state then
  elseif not self:is_enabled() then
    self._state = PluginState.DISABLED
  elseif self:is_ignored() then
    self._state = PluginState.IGNORED
  -- Skip unnecessary activations.
  elseif self:is_shadow() then
    self._state = PluginState.ACTIVATED
  else
    self._state = PluginState.NONE
  end
  return self._state
end

return Plugin
