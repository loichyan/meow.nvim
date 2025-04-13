---@diagnostic disable: invisible

local Utils = require("meow.utils")
local Plugin = require("meow.plugin")

---Denotes whether a plugin is activated or loaded.
---
---Possible values are:
---  * ACTIVATED : Added to MiniDeps, but not loaded.
---  * LOADING   : In the loading progress.
---  * LOADED    : Loaded and initialized.
---  * DISABLED  : Disabled and never to be loaded.
---@enum MeoPluginState
local PluginState = {
    NONE = 0,
    ACTIVATED = 1,
    LOADING = 2,
    LOADED = 3,
    DISABLED = 4,
}

---Returns true if plugin `a` should be loaded before plugin `b`.
---
---Plugins with a lower level are always loaded first. Otherwise, if two plugins
---have the same level, the one with the lower priority is loaded first. If both
---the levels and the priorities are equal, their names are taken into account
---to produce a deterministic loading sequence.
---@param a MeoPlugin
---@param b MeoPlugin
---@return boolean
local plugin_ordering = function(a, b)
    if a._level ~= b._level then
        return a._level < b._level
    end
    if a.priority ~= b.priority then
        return a.priority < b.priority
    end
    return a.name < b.name
end

---@class MeoPluginManager
---All registered plugins.
---@field private _plugins MeoPlugin[]
---A map of all plugins, indexed by their names.
---@field private _plugin_map table<string,MeoPlugin>
---@field private _did_setup? boolean
local Manager = {}

---Creates a new plugin manager.
---@return MeoPluginManager
function Manager.new()
    return setmetatable({
        _plugins = {},
        _plugin_map = {},
    }, { __index = Manager })
end

---Returns the plugin specified by name.
---@param name string
---@return MeoPlugin?
function Manager:get(name)
    return self._plugin_map[name]
end

---Imports all plugin specs from the direct submodules under the root module.
---
---A module may return a plugin spec or a list of plugin specs.
---@param root string
function Manager:import(root)
    ---@type string[]
    local mods = {}
    Utils.scan_submods(root, function(mod, path)
        if package.preload[mod] == nil then
            package.preload[mod] = function()
                return dofile(path)
            end
        end
        table.insert(mods, mod)
    end)

    if #mods == 0 then
        error("failed to determine path of import: " .. root)
    end

    -- Ensure that all modules are imported in alphabetical order.
    table.sort(mods)
    for _, mod in ipairs(mods) do
        local ok, err = pcall(function()
            ---@type MeoSpecs
            local specs = require(mod)
            if type(specs) ~= "table" then
                error("invalid spec: " .. vim.inspect(specs))
            else
                self:add_many(specs)
            end
        end)
        if not ok then
            error(("failed to import module %s: %s"):format(mod, err))
        end
    end
end

---Adds one or more plugins from the given spec(s).
---@param specs MeoSpecs
function Manager:add_many(specs)
    if #specs > 1 or type(specs[1]) == "table" then
        ---@cast specs MeoSpec[]
        for _, spec in ipairs(specs) do
            self:add(spec)
        end
    else
        self:add(specs)
    end
end

---Creates or updates a plugin from the given spec, returning the plugin
---instance if a name is specified.
---@param spec MeoSpec
---@return MeoPlugin?
function Manager:add(spec)
    if not spec[1] then
        -- If the spec contains only an imports field, resolve the imports
        -- immediately; otherwise, defer the resolution after this plugin is
        -- activated.
        if spec.imports then
            for _, mod in ipairs(spec.imports) do
                self:import(mod)
            end
        end
        return
    end

    local name, source = Utils.parse_plugin_name(spec[1])
    local plugin = self._plugin_map[name]
    if not plugin then
        plugin = Plugin.new(name)
        table.insert(self._plugins, plugin)
        self._plugin_map[name] = plugin
    end

    -- Update plugin properties.
    plugin:_update_spec(spec)

    -- Set the source to the possible URI if no alternative source is provided.
    if not plugin.source then
        plugin.source = source
    end

    -- Defer resolving dependency specs until the given plugin is determined to
    -- be enabled.
    if spec.dependencies then
        plugin._deps = plugin._deps or {}
        for _, dep_spec in ipairs(spec.dependencies) do
            local dep_name
            if type(dep_spec) == "string" then
                dep_name = dep_spec
            else
                local dep = self:add(dep_spec)
                if not dep then
                    error("dependency spec is not a valid plugin: " .. vim.inspect(dep_spec))
                end
                dep._is_dep = true
                dep_name = dep.name
            end
            plugin._deps[dep_name] = true
        end
    end

    return plugin
end

---Activates all enabled plugins and sets up configured event handlers.
---
---CAVEAT: This function may only be called once, after which no modifications
---may be made to the instance or any added plugins.
function Manager:setup()
    if self._did_setup then
        vim.notify("PluginManager has already been initialized", vim.log.levels.WARN)
        return
    end
    MiniDeps.now(function()
        self:_really_setup()
    end)
    self._did_setup = true
end

function Manager:_really_setup()
    local count = 1
    while count <= #self._plugins do
        -- Collect and sort start plugins so as to ensure they are loaded in the
        -- desired order.
        ---@type MeoPlugin[]
        local enabled_plugins = {}
        repeat
            local plugin = self._plugins[count]
            count = count + 1
            if plugin._state ~= PluginState.NONE then
            elseif plugin:is_disabled() then
                plugin._state = PluginState.DISABLED
            else
                table.insert(enabled_plugins, plugin)
            end
        until count > #self._plugins

        table.sort(enabled_plugins, plugin_ordering)
        for _, plugin in ipairs(enabled_plugins) do
            if plugin:is_lazy() then
                if plugin.imports then
                    error("imports of lazy plugins are not supported: " .. plugin.name)
                end
                MiniDeps.later(function()
                    -- TODO: set up event handlers
                    self:_load(plugin)
                end)
            else
                self:_load(plugin)
                if plugin.imports then
                    for _, mod in ipairs(plugin.imports) do
                        self:import(mod)
                    end
                end
            end
        end
    end
end

---Loads a plugin if it is not loaded or disabled.
---@param plugin MeoPlugin
function Manager:_load(plugin)
    if plugin._state >= PluginState.LOADING then
        return
    end

    for _, dep in ipairs(self:_resolve_dependencies(plugin)) do
        self:_activate(dep)
        dep._state = PluginState.LOADING
        if dep.config then
            dep:config()
        end
        dep._state = PluginState.LOADED
    end
end

---Adds the given to MiniDeps.
---@private
---@param plugin MeoPlugin
function Manager:_activate(plugin)
    if plugin:is_shadow() or plugin._state >= PluginState.ACTIVATED then
        return
    end
    MiniDeps.add(plugin:to_mini())
    plugin._state = PluginState.ACTIVATED
end

---Resolves dependencies that are not loaded and required by the given plugin.
---
---The returned list contains the plugin itself at the end and is sorted in an
---appropriate loading order.
---@private
---@param plugin MeoPlugin
---@return MeoPlugin[]
function Manager:_resolve_dependencies(plugin)
    ---@type MeoPlugin[]
    local deps = {}
    self:_collect_dependencies(deps, plugin)
    table.sort(deps, plugin_ordering)
    return deps
end

---Recursively collects all dependencies of the given plugin using DFS.
---@private
---@param result MeoPlugin[]
---@param plugin MeoPlugin
function Manager:_collect_dependencies(result, plugin)
    -- Skip if resolved or loaded.
    if plugin._level ~= 0 or plugin._level >= PluginState.LOADING then
        return
    end

    if not plugin._deps then
        plugin._level = 1
    else
        plugin._level = -1 -- Set a temporary mark to detect circular references.
        local dep_level = 0
        for dep_name, _ in pairs(plugin._deps) do
            local dep = self._plugin_map[dep_name]
            if not dep then
                error(("found undefined dependency: %s"):format(dep_name))
            elseif dep._level == -1 then
                error(("found circular dependencies: %s and %s"):format(plugin.name, dep_name))
            else
                self:_collect_dependencies(result, dep)
                dep_level = math.max(dep_level, dep._level)
            end
        end
        plugin._level = dep_level + 1
    end

    table.insert(result, plugin)
end

function Manager.test_add_plugin()
    MiniDeps = {
        add = function(p)
            vim.print(p)
        end,
    }
    local m = Manager.new()
    m:add({ "a", dependencies = { "b", "d" } })
    m:add({ "b", dependencies = { "c" } })
    m:add({ "c" })
    m:add({ "d", dependencies = { "e" } })
    m:add({ "e", dependencies = { "c" } })
    m:add({ "f", priority = 100 })
    m:add({ "g", priority = 1 })
    m:add({ "h" })
    m:add({
        "a",
        priority = 999,
        config = function(self)
            vim.print("SETUP(A)", self)
        end,
    })
    vim.print("LOAD(A)")
    m:_load(m:get("a"))
    vim.print("LOAD(F)")
    m:_load(m:get("f"))
end

return Manager
