local Utils = require("meow.utils")
local Meow = {}

Meow.manager = require("meow.manager").new()
Meow.keyset = Utils.keyset

---@param opts MeoOptions
function Meow.setup(opts)
    _G.Meow = Meow
    if opts.specs then
        Meow.manager:add_many(opts.specs)
    end
    Meow.manager:setup()
end

return Meow
