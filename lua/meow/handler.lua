local Utils = require("meow.utils")

---@class MeoEventHandler
---@field private _manager MeoPluginManager
---@field private _by_module table<string,MeoPlugin[]>
---@field private _by_event table<string,MeoPlugin[]>
---@field private _by_ft table<string,MeoPlugin[]>
local Handler = {}

---@param manager MeoPluginManager
function Handler.new(manager)
    return setmetatable({
        _manager = manager,
        _by_module = {},
        _by_event = {},
        _by_ft = {},
    }, { __index = Handler })
end

---@param plugin MeoPlugin
function Handler:add(plugin)
    -- Lazy-loading on requiring.
    if not plugin.module then
        -- Find modules to trigger the loading of the given plugin.
        plugin.module = { plugin.name }
        if plugin.path then
            Utils.scan_dirmods(plugin.path .. "/lua", true, function(mod)
                table.insert(plugin.module, mod)
            end)
        end
    end
    if plugin.module then
        for _, mod in ipairs(plugin.module) do
            local mods = self._by_module[mod] or {}
            self._by_module[mod] = mods
            table.insert(mods, plugin)
        end
    end

    -- Lazy-loading on events.
    if plugin.event then
        for _, ev in ipairs(plugin.event) do
            self._by_event[ev] = self._by_event[ev] or {}
            table.insert(self._by_event[ev], plugin)
        end
    end

    -- Lazy-loading on filetypes.
    if plugin.ft then
        for _, ft in ipairs(plugin.ft) do
            self._by_ft[ft] = self._by_ft[ft] or {}
            table.insert(self._by_ft[ft], plugin)
        end
    end
end

function Handler:setup()
    -- Set up module handlers.
    local remaining_modules = vim.tbl_count(self._by_module)
    table.insert(package.loaders, 1, function(mod)
        -- Fast path if all modules are loaded.
        if remaining_modules == 0 then
            return
        end

        local plugins = self._by_module[mod]
        if not plugins then
            mod = string.match(mod, "([^.]+)%.?")
            plugins = self._by_module[mod]
        end
        if plugins then
            for _, plugin in ipairs(plugins) do
                self._manager:load(plugin)
            end
            self._by_module[mod] = nil
            remaining_modules = remaining_modules - 1
        end
    end)

    local group = vim.api.nvim_create_augroup("MeoEventHandler", { clear = false })

    -- Set up event handlers.
    local by_very_lazy = self._by_event["VeryLazy"] -- Load them later
    self._by_event["VeryLazy"] = nil
    for key, plugins in pairs(self._by_event) do
        for _, ev in ipairs(self._manager.event_aliases[key] or { key }) do
            local name, pattern = string.match(ev, "(%w+) (%w+)")
            name = name or ev
            vim.api.nvim_create_autocmd(name, {
                group = group,
                once = true,
                pattern = pattern,
                callback = function()
                    if not plugins then
                        return
                    end
                    for _, plugin in ipairs(plugins) do
                        self._manager:load(plugin)
                    end
                    ---@diagnostic disable-next-line: cast-local-type
                    plugins = nil
                    self._by_event[key] = nil
                end,
            })
        end
    end

    -- Set up filetype handlers.
    for ft, plugins in pairs(self._by_ft) do
        vim.api.nvim_create_autocmd("FileType", {
            group = group,
            once = true,
            pattern = ft,
            callback = function()
                for _, plugin in ipairs(plugins) do
                    self._manager:load(plugin)
                end
                self._by_ft[ft] = nil
            end,
        })
    end

    -- Trigger the VeryLazy event.
    -- See <https://github.com/folke/lazy.nvim/blob/6c3bda4aca61a13a9c63f1c1d1b16b9d3be90d7a/lua/lazy/core/util.lua#L169>
    vim.api.nvim_create_autocmd("UIEnter", {
        group = group,
        once = true,
        callback = function()
            vim.schedule(function()
                if by_very_lazy then
                    for _, plugin in ipairs(by_very_lazy) do
                        self._manager:load(plugin)
                    end
                end
                vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
            end)
        end,
    })
end

return Handler
