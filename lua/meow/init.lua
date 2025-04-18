local Utils = require("meow.utils")

---@class Meow
---@field config MeoOptions
---@field manager MeoPluginManager
local Meow = {}

-- Export useful utilities.
Meow.utils = Utils
Meow.keyset = Utils.keyset
Meow.notify = Utils.notify
Meow.notifyf = Utils.notifyf

local did_setup = false
---@param opts MeoOptions?
function Meow.setup(opts)
    if did_setup then
        return
    end
    did_setup = true
    opts = opts or {}

    _G.Meow = Meow
    Meow.config = opts
    Meow.manager = require("meow.manager").new()

    -- Register ourself.
    Meow.manager:add({ "meow.nvim", shadow = true, lazy = false, priority = math.huge })
    if opts.specs then
        Meow.manager:add_many(opts.specs)
    end
    if opts.enable_snapshot then
        Meow.manager:load_snap_from(MiniDeps.config.path.snapshot)
    end
    Meow.manager:setup()

    if opts.patch_mini then
        local get_session = MiniDeps.get_session
        ---@diagnostic disable-next-line: duplicate-set-field
        MiniDeps.get_session = function(...)
            Meow.manager:activate_all()
            return get_session(...)
        end
    end
end

---Loads the plugin specified by name.
function Meow.load(name)
    local plugin = Meow.manager:get(name)
    if not plugin then
        Utils.notify("ERROR", "attempted to load an undefined plugin " .. name)
    else
        Meow.manager:load(plugin)
    end
end

---Update plugins. See `:h MiniDeps.update()`.
function Meow.update(...)
    Meow.manager:activate_all()
    MiniDeps.update(...)
    if Meow.config.enable_snapshot then
        MiniDeps.snap_save(MiniDeps.config.path.snapshot)
    end
end

---Clean plugins. See `:h MiniDeps.clean()`.
function Meow.clean(...)
    Meow.manager:activate_all()
    MiniDeps.clean(...)
end

return Meow
