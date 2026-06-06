local Utils = require('meow.internal.utils')
local Manager = require('meow.internal.manager')

---@module 'mini.deps'

---@class Meow
local Meow = {}

local did_setup = false
---@param opts MeoOptions?
Meow.setup = function(opts)
  if did_setup then return end
  did_setup = true
  opts = opts or {}

  if not vim.fn.has('nvim-0.12') then
    Utils.notify('ERROR', 'meow.nvim requires Neovim >= 0.12')
    return
  end

  _G.Meow = Meow

  Meow.config = require('meow.internal.config')
  for k, v in pairs(opts) do
    Meow.config[k] = v
  end

  if opts.specs then Manager.add_many(opts.specs) end
  Manager.setup()

  for _, key in ipairs({ 'enable_snapshot', 'patch_mini' }) do
    if opts[key] ~= nil then Utils.notifyf('ERROR', '`MeoOptions.%s` is deprecated', key) end
  end
end

-- Methods for Plugin Management -----------------------------------------------
Meow.add = Manager.add
Meow.clean = Manager.clean
Meow.debug = Manager.debug
Meow.get = Manager.get
Meow.import = Manager.import
Meow.load = Manager.load
Meow.plugins = Manager.plugins
Meow.sync = Manager.sync
Meow.update = Manager.update

-- Useful Utilities ------------------------------------------------------------
Meow.autocmd = Utils.autocmd
Meow.debounce = Utils.debounce
Meow.keymap = Utils.keymap
Meow.later = Utils.later
Meow.notify = Utils.notify
Meow.notifyf = Utils.notifyf

return Meow
