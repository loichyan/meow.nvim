---@diagnostic disable: invisible

---Denotes whether a plugin is activated or loaded.
---
---Possible values are:
---  * ACTIVATED : Added to MiniDeps, but not loaded.
---  * LOADING   : In the loading progress.
---  * LOADED    : Loaded and initialized.
---  * DISABLED  : Disabled and never to be loaded.
---@private
---@enum MeoPluginState
local PluginState = {
    NONE = 0,
    ACTIVATED = 1,
    LOADING = 2,
    LOADED = 3,
    DISABLED = 4,
}

---@type table<string,"primitive"|"list"|"table">
local SPEC_VTYPES = {
    source = "primitive",
    checkout = "primitive",
    monitor = "primitive",
    hooks = "table",

    shadow = "primitive",
    enabled = "primitive",
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
local MINI_SPEC_KEYS = {
    "name",
    "source",
    "checkout",
    "monitor",
    "hooks",
}

---@type MeoSpecCond
local infer_shadow_state = function(plugin)
    return plugin.name ~= "mini.nvim" and vim.startswith(plugin.name, "mini.")
end

---@type MeoSpecCond
local infer_lazy_state = function(plugin)
    return not not (plugin._is_dep or plugin.event or plugin.ft or plugin.module)
end

---@class MeoPlugin
---@field name string
---@field source? string
---@field checkout? string
---@field monitor? string
---@field hooks? MeoSpecHooks
---@field shadow? MeoSpecCond
---@field enabled? MeoSpecCond
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
---@field path? string
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

---@private
Plugin._State = PluginState

---Creates a new plugin instance.
---@param name string
---@return MeoPlugin
function Plugin.new(name)
    return setmetatable({
        name = name,
        priority = 50,
        _level = 0,
        _state = PluginState.NONE,
    }, { __index = Plugin })
end

---Updates the properties of the given plugin from a spec table.
---@private
---@param spec MeoSpec
function Plugin:_update_spec(spec)
    -- Merge values of spec keys.
    for key, val in pairs(spec) do
        local vtype = SPEC_VTYPES[key]
        if not vtype then
        elseif vtype == "list" then
            if type(val) ~= "table" then
                val = { val }
            end
            self[key] = vim.list_extend(self[key] or {}, val)
        elseif vtype == "table" then
            self[key] = vim.tbl_extend("force", self[key] or {}, val)
        else
            self[key] = val
        end
    end

    -- Apply property aliases.
    if spec.build then
        self.hooks = self.hooks or {}
        self.hooks.post_checkout = spec.build
    end
end

---Returns whether this plugin is loaded.
---@return boolean
function Plugin:is_loaded()
    return self._state == PluginState.LOADING
end

---@return boolean
function Plugin:is_shadow()
    return self:_get_cond("shadow", infer_shadow_state)
end

---@return boolean
function Plugin:is_enabled()
    return self:_get_cond("enabled", true)
end

function Plugin:is_lazy()
    return self:_get_cond("lazy", infer_lazy_state)
end

---Resolves the specified conditional field.
---@param key "shadow"|"enabled"|"lazy"
---@param default MeoSpecCond
---@return boolean
function Plugin:_get_cond(key, default)
    local val = self[key]
    if type(val) == "boolean" then
        return val
    end
    if val == nil then
        val = default
    end
    if type(val) == "function" then
        val = val(self)
    end
    self[key] = not not val
    return self[key]
end

---Converts the given plugin to a spec acceptable to MiniDeps.
---@return table
function Plugin:to_mini()
    local spec = {}
    for _, key in ipairs(MINI_SPEC_KEYS) do
        spec[key] = self[key]
    end
    return spec
end

return Plugin
