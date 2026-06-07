local Constants = require('meow.internal.constants')
local PluginState = Constants.PluginState

---@class MeoPlugin
---@field name string
---@field source string
---@field version? string|vim.VersionRange
---@field build? MeoSpecHook
---@field checkout? nil -- deprecated
---@field monitor? nil -- deprecated
---@field hooks? nil -- deprecated
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
---The (non-nil) priority of this plugin.
---@field private _priority integer
---The level of this plugin in the dependency graph of a resolved plugin.
---@field private _level integer
---The loading state of this plugin.
---@field private _state MeoPluginState
local Plugin = {}
local H = setmetatable({}, { __index = require('meow.internal.utils') })

---Creates a new plugin instance.
---@param spec MeoSpec
---@param idx integer
---@return MeoPlugin
Plugin.new = function(spec, idx)
  local self = {
    name = assert(spec.name, 'MeoSpec[1] must not be nil'),
    source = assert(spec[1], 'MeoSpec.name must not be nil'),
    _idx = idx,
    _level = 0,
    _priority = spec.priority or 50,
  }

  -- Merge the value of each spec key.
  for key, val in pairs(spec) do
    local vtype = Constants.SPEC_VTYPES[key]
    if not vtype then
      -- Skip user-defined keys.
    elseif vtype == 'deprecated' then
      H.notifyf('ERROR', 'spec key "%s" is deprecated for plugin "%s"', key, spec.name)
    elseif vtype == 'list' then
      self[key] = type(val) ~= 'table' and { val } or val
    elseif vtype == 'primitive' then
      self[key] = val
    else
      error('unreable')
    end
  end

  return setmetatable(self, { __index = Plugin })
end

---Returns the installation location of this plugin.
---
---This function always returns a path, whether or not the plugin is a shadow
---plugin install. Therefore, the caller should perform necessary checks before
---asserting the existence of the returned path.
---@return string
Plugin.path = function(self)
  if not self._path then
    self._path = vim.fs.normalize(vim.fn.stdpath('data') .. '/pack/core/opt/' .. self.name)
  end
  return self._path
end

---Returns whether this plugin is loaded.
---@return boolean
Plugin.is_loaded = function(self) return self:_get_state() == PluginState.LOADED end

---Returns whether this plugin will be loaded.
Plugin.will_load = function(self) return self:_get_state() < PluginState.IGNORED end

---Returns `shadow == true`.
---@return boolean
Plugin.is_shadow = function(self) return self:_get_cond('shadow', false) end

---Returns `enabled == true`.
---@return boolean
Plugin.is_enabled = function(self) return self:_get_cond('enabled', true) end

---Returns `cond == false`.
---@return boolean
Plugin.is_ignored = function(self) return not self:_get_cond('cond', true) end

---Returns `lazy == true`.
Plugin.is_lazy = function(self) return self:_get_cond('lazy', Constants.default_spec_lazy) end

---Resolves the specified conditional field.
---@private
---@param key 'shadow'|'enabled'|'cond'|'lazy'
---@param default MeoSpecCond
---@return boolean
Plugin._get_cond = function(self, key, default)
  local val = self[key]
  if type(val) == 'boolean' then return val end
  if val == nil then val = default end
  if type(val) == 'function' then val = val(self) end
  self[key] = not not val
  return self[key]
end

---Infers the state of this plugin.
---@private
---@return MeoPluginState
Plugin._get_state = function(self)
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
