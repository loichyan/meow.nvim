local Meow = {}

Meow.manager = require("meow.manager").new()

---@param opts MeoOptions
function Meow.setup(opts)
    if opts.specs then
        Meow.manager:add_many(opts.specs)
    end
    Meow.manager:setup()
end

return Meow
