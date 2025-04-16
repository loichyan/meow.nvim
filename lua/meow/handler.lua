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
    -- Find which plugins should be loaded before a module is required.
    Utils.scan_dirmods(plugin.path .. "/lua", true, function(mod)
        local mods = self._module_map[mod] or {}
        self._module_map[mod] = mods
        table.insert(mods, plugin)
    end)
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
end

return Handler
