local Utils = require("meow.utils")

---@class MeoHandler
---@field private _manager MeoPluginManager
---@field private _module_map table<string,MeoPlugin[]>
local Handler = {}

---@param manager MeoPluginManager
function Handler.new(manager)
    return setmetatable({
        _manager = manager,
        _module_map = {},
    }, { __index = Handler })
end

---@param plugin MeoPlugin
function Handler:add(plugin)
    -- Lazy-loading on requiring.
    if not plugin.module then
        -- Find modules to trigger the loading of the given plugin.
        plugin.module = {}
        Utils.scan_dirmods(plugin.path .. "/lua", true, function(mod)
            table.insert(plugin.module, mod)
        end)
    end
    for _, mod in ipairs(plugin.module) do
        local mods = self._module_map[mod] or {}
        self._module_map[mod] = mods
        table.insert(mods, plugin)
    end

    -- Lazy-loading on events.
    if plugin.event then
        for _, e in ipairs(plugin.event) do
            if e ~= "VeryLazy" then
                Utils.notifyf("ERROR", "event %s is not supported for plugin %s", e, plugin.name)
            end
        end
    end

    MiniDeps.later(function()
        self._manager:load(plugin)
    end)
end

function Handler:setup()
    -- Set module handlers.
    table.insert(package.loaders, 1, function(mod)
        local root = string.match(mod, "([^.]+)%.?")
        local plugins = self._module_map[root]
        if plugins then
            for _, plugin in ipairs(plugins) do
                self._manager:load(plugin)
            end
            self._module_map[root] = nil
        end
    end)
    MiniDeps.later(function()
        vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    end)
end

return Handler
