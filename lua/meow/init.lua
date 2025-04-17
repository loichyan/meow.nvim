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

    if opts.specs then
        Meow.manager:add_many(opts.specs)
    end
    Meow.manager:setup()
end

return Meow
