local Config = require('meow.internal.config')
local Constants = require('meow.internal.constants')

---@class MeoEventHandler
local Handler = {}
local H = setmetatable({}, { __index = require('meow.internal.utils') })

---@type table<string,MeoPlugin[]|{_loaded:true}>
H.by_module = {}
---@type table<string,MeoPlugin[]|{_loaded:true}>
H.by_event = {}
---@type table<string,MeoPlugin[]|{_loaded:true}>
H.by_ft = {}

---@type table<string,MeoPlugin>
H.hook_on_changed = {}

---@param plugin MeoPlugin
Handler.add = function(plugin)
  -- Lazy-loading on requiring.
  if not plugin.module then
    -- Find modules to trigger the loading of the given plugin.
    if Constants.is_mini(plugin.name) then
      plugin.module = { plugin.name }
    else
      plugin.module = {}
      if not plugin:is_shadow() then
        H.scan_dirmods(
          plugin:path() .. '/lua',
          true,
          function(mod) table.insert(plugin.module, mod) end
        )
      end
    end
  end
  if plugin.module then
    for _, mod in ipairs(plugin.module) do
      local mods = H.by_module[mod] or {}
      H.by_module[mod] = mods
      table.insert(mods, plugin)
    end
  end

  -- Lazy-loading on events.
  if plugin.event then
    for _, ev in ipairs(plugin.event) do
      H.by_event[ev] = H.by_event[ev] or {}
      table.insert(H.by_event[ev], plugin)
    end
  end

  -- Lazy-loading on filetypes.
  if plugin.ft then
    for _, ft in ipairs(plugin.ft) do
      H.by_ft[ft] = H.by_ft[ft] or {}
      table.insert(H.by_ft[ft], plugin)
    end
  end

  if plugin.build then H.hook_on_changed[plugin.name] = plugin end
end

---@param loader fun(plugin:MeoPlugin[])
Handler.setup = function(loader)
  H.loader = loader

  -- Set up module handlers.
  local remaining_modules = vim.tbl_count(H.by_module)
  table.insert(package.loaders, 1, function(mod)
    -- Fast path if all modules are loaded.
    if remaining_modules == 0 then return end

    local plugins = H.by_module[mod] or H.by_module[string.match(mod, '([^.]+)%.?')]
    if not plugins or plugins._loaded then return end
    H.loader(plugins)
    plugins._loaded = true
    remaining_modules = remaining_modules - 1

    -- The module may have been loaded during its setup.
    local loaded = package.loaded[mod]
    if loaded then
      return function() return loaded end
    end
  end)

  local group = vim.api.nvim_create_augroup('MeoEventHandler', { clear = false })
  local au = vim.api.nvim_create_autocmd

  -- Set up event handlers.
  local by_very_lazy = H.by_event['VeryLazy'] -- Load them later
  H.by_event['VeryLazy'] = nil

  local event_aliases = Config.event_aliases or {}
  for key, plugins in pairs(H.by_event) do
    for _, ev in ipairs(event_aliases[key] or { key }) do
      local name, pattern = string.match(ev, '(%w+) (%w+)')
      name = name or ev
      au(name, {
        group = group,
        once = true,
        pattern = pattern,
        callback = function()
          if plugins._loaded then return end
          H.loader(plugins)
          plugins._loaded = true
        end,
      })
    end
  end

  -- Set up filetype handlers.
  for ft, plugins in pairs(H.by_ft) do
    au('FileType', {
      group = group,
      once = true,
      pattern = ft,
      callback = function()
        if plugins._loaded then return end
        H.loader(plugins)
        plugins._loaded = true
      end,
    })
  end

  -- Trigger the VeryLazy event.
  -- See <https://github.com/folke/lazy.nvim/blob/6c3bda4aca61a13a9c63f1c1d1b16b9d3be90d7a/lua/lazy/core/util.lua#L169>
  au('UIEnter', {
    group = group,
    once = true,
    callback = function()
      vim.schedule(function()
        if by_very_lazy then H.loader(by_very_lazy) end
        vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy', modeline = false })
      end)
    end,
  })

  -- Set up plugin hooks.
  au('PackChanged', {
    group = group,
    callback = function(ev)
      local name = ev.data.spec.name
      local plugin = H.hook_on_changed[name]
      if plugin == nil or plugin.build == nil then return end
      if not ev.data.active then vim.cmd.packadd(name) end
      local ok, err = pcall(plugin.build, plugin)
      if not ok then
        H.notifyf('ERROR', 'failed to run the build hook for plugin "%s": %s', name, err)
      end
    end,
  })
end

return Handler
