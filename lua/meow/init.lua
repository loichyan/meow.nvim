local Utils = require("meow.internal.utils")
local Manager = require("meow.internal.manager")

---@module "mini.deps"

---@class Meow
local Meow = {}

local did_setup = false
---@param opts MeoOptions?
function Meow.setup(opts)
  if did_setup then return end
  did_setup = true
  opts = opts or {}

  _G.Meow = Meow
  Meow.config = require("meow.internal.config")
  for k, v in pairs(opts) do
    Meow.config[k] = v
  end

  if opts.specs then Manager.add_many(opts.specs) end
  if opts.enable_snapshot then Manager.load_snap_from(MiniDeps.config.path.snapshot) end
  Manager.setup()

  if opts.patch_mini then
    local orig_get_session = MiniDeps.get_session
    ---@diagnostic disable-next-line: duplicate-set-field
    MiniDeps.get_session = function(...)
      Manager.activate_all()
      return orig_get_session(...)
    end
  end
end

-----------------------------------
-- Methods for Plugin Management --
-----------------------------------

---Update plugins. See `:h MiniDeps.update`.
---
---It's not necessary to use this unless `MeoOptions.patch_mini` is disabled.
function Meow.update(...)
  Manager.activate_all()
  MiniDeps.update(...)
end

---Clean plugins. See `:h MiniDeps.clean`.
---
---It's not necessary to use this unless `MeoOptions.patch_mini` is disabled.
function Meow.clean(...)
  Manager.activate_all()
  MiniDeps.clean(...)
end

Meow.get = Manager.get
Meow.plugins = Manager.plugins
Meow.import = Manager.import
Meow.add = Manager.add
Meow.load = Manager.load

----------------------
-- Useful Utilities --
----------------------

Meow.keymap = Utils.keymap
Meow.autocmd = Utils.autocmd
Meow.notify = Utils.notify
Meow.notifyf = Utils.notifyf

return Meow
