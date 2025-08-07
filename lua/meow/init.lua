local Utils = require("meow.utils")

---@class Meow
---@field config MeoOptions
---@field manager MeoPluginManager
local Meow = {}

local did_setup = false
---@param opts MeoOptions?
function Meow.setup(opts)
  if did_setup then return end
  did_setup = true
  opts = opts or {}

  _G.Meow = Meow
  Meow.config = require("meow.config")
  for k, v in pairs(opts) do
    Meow.config[k] = v
  end
  Meow.manager = require("meow.manager").new()

  -- Register ourself.
  if opts.specs then Meow.manager:add_many(opts.specs) end
  if opts.enable_snapshot then Meow.manager:load_snap_from(MiniDeps.config.path.snapshot) end
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

-----------------------------------
-- Methods for Plugin Management --
-----------------------------------

---Update plugins. See `:h MiniDeps.update()`.
function Meow.update(...)
  Meow.manager:activate_all()
  MiniDeps.update(...)
  if Meow.config.enable_snapshot then MiniDeps.snap_save(MiniDeps.config.path.snapshot) end
end

---Clean plugins. See `:h MiniDeps.clean()`.
function Meow.clean(...)
  Meow.manager:activate_all()
  MiniDeps.clean(...)
end

---Returns the plugin specified by name.
---@param name string
---@return MeoPlugin?
function Meow.get(name) return Meow.manager:get(name) end

---Returns all registered plugins.
---@return MeoPlugin[]
function Meow.plugins() return Meow.manager:plugins() end

---Returns all registered plugins.
---@param root string
---@param opts? {cache_token?:string}
function Meow.import(root, opts) return Meow.manager:import(root, opts) end

---Adds plugins from the given spec(s).
---@param specs MeoSpecs
function Meow.add(specs) return Meow.manager:add_many(specs) end

---Loads a plugin if it is not loaded or disabled.
---@param plugin string|MeoPlugin
function Meow.load(plugin) return Meow.manager:load(plugin) end

----------------------
-- Useful Utilities --
----------------------

Meow.utils = Utils
---@diagnostic disable-next-line: deprecated
Meow.keyset = Utils.keyset
Meow.keymap = Utils.keymap
Meow.autocmd = Utils.autocmd
Meow.notify = Utils.notify
Meow.notifyf = Utils.notifyf

return Meow
