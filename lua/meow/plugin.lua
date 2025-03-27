---@diagnostic disable: invisible

---@type table<string,"primitive"|"list"|"table">
local SPEC_VTYPES = {
    source = "primitive",
    checkout = "primitive",
    monitor = "primitive",
    shadow = "primitive",
    disabled = "primitive",
    lazy = "primitive",
    priority = "primitive",
    config = "primitive",

    hooks = "table",
}
local MINI_SPEC_KEYS = {
    "name",
    "source",
    "checkout",
    "monitor",
    "hooks",
}

---@type MeoSpecCond
local infer_shadow_state = function(plugin)
    return vim.startswith(plugin.name, "mini.")
end

---@type MeoSpecCond
local infer_lazy_state = function(plugin)
    return plugin._is_dep == true
end

---@class MeoPlugin
---@field name string
---@field source string?
---@field checkout string?
---@field monitor string?
---@field hooks MeoSpecHooks
---@field shadow MeoSpecCond?
---@field disabled MeoSpecCond?
---@field lazy MeoSpecCond?
---@field priority integer
---@field config fun(self:MeoPlugin)|nil
---A set of dependency names.
---@field dependencies table<string,true>
---Whether added as a dependency.
---@field private _is_dep boolean?
---The level of this plugin in the dependency graph of a resolved plugin.
---@field private _level integer
---@field private _state MeoPluginState
local Plugin = {}

---@param name string
---@return MeoPlugin
function Plugin.new(name)
    return setmetatable({
        name = name,
        hooks = {},
        priority = 50,
        dependencies = {},
        _level = 0,
        _state = 0,
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
            self[key] = vim.tbl_extend("force", self[key], val)
        elseif vtype == "table" then
            self[key] = vim.list_extend(self[key], val)
        else
            self[key] = val
        end
    end

    -- Apply property aliases.
    if spec.build then
        self.hooks.post_checkout = spec.build
    end
end

---@return boolean
function Plugin:is_shadow()
    return self:_get_cond("shadow", infer_shadow_state)
end

---@return boolean
function Plugin:is_disabled()
    return self:_get_cond("disabled", false)
end

function Plugin:is_lazy()
    return self:_get_cond("lazy", infer_lazy_state)
end

---@param key "shadow"|"disabled"|"lazy"
---@param default MeoSpecCond
---@return boolean
function Plugin:_get_cond(key, default)
    if self[key] == nil then
        self[key] = default
    end
    if type(self[key]) == "function" then
        self[key] = self[key](self)
    end
    return self[key]
end

---Converts the given plugin to a spec acceptable to mini.deps.
---@return table
function Plugin:to_mini()
    local spec = {}
    for _, key in ipairs(MINI_SPEC_KEYS) do
        spec[key] = self[key]
    end
    return spec
end

return Plugin
