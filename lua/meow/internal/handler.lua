local Config = require("meow.internal.config")
local Utils = require("meow.internal.utils")

---@class MeoEventHandler
local Handler = {}
local H = {}

---@type table<string,MeoPlugin[]|{_loaded:true}>
H.by_module = {}
---@type table<string,MeoPlugin[]|{_loaded:true}>
H.by_event = {}
---@type table<string,MeoPlugin[]|{_loaded:true}>
H.by_ft = {}

---@param plugin MeoPlugin
Handler.add = function(plugin)
  -- Lazy-loading on requiring.
  if not plugin.module then
    -- Find modules to trigger the loading of the given plugin.
    plugin.module = { plugin.name }
    if plugin.path then
      Utils.scan_dirmods(
        plugin.path .. "/lua",
        true,
        function(mod) table.insert(plugin.module, mod) end
      )
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
end

---@param loader fun(plugin:MeoPlugin)
Handler.setup = function(loader)
  -- Set up module handlers.
  local remaining_modules = vim.tbl_count(H.by_module)
  table.insert(package.loaders, 1, function(mod)
    -- Fast path if all modules are loaded.
    if remaining_modules == 0 then return end

    local plugins = H.by_module[mod] or H.by_module[string.match(mod, "([^.]+)%.?")]
    if not plugins or plugins._loaded then return end

    for _, plugin in ipairs(plugins) do
      loader(plugin)
    end
    plugins._loaded = true
    remaining_modules = remaining_modules - 1

    -- The module may have been loaded during its setup.
    local loaded = package.loaded[mod]
    if loaded then
      return function() return loaded end
    end
  end)

  local group = vim.api.nvim_create_augroup("MeoEventHandler", { clear = false })

  -- Set up event handlers.
  local by_very_lazy = H.by_event["VeryLazy"] -- Load them later
  H.by_event["VeryLazy"] = nil

  local event_aliases = Config.event_aliases or {}
  for key, plugins in pairs(H.by_event) do
    for _, ev in ipairs(event_aliases[key] or { key }) do
      local name, pattern = string.match(ev, "(%w+) (%w+)")
      name = name or ev
      vim.api.nvim_create_autocmd(name, {
        group = group,
        once = true,
        pattern = pattern,
        callback = function()
          if plugins._loaded then return end
          for _, plugin in ipairs(plugins) do
            loader(plugin)
          end
          plugins._loaded = true
        end,
      })
    end
  end

  -- Set up filetype handlers.
  for ft, plugins in pairs(H.by_ft) do
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      once = true,
      pattern = ft,
      callback = function()
        if plugins._loaded then return end
        for _, plugin in ipairs(plugins) do
          loader(plugin)
        end
        plugins._loaded = true
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
            loader(plugin)
          end
        end
        vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
      end)
    end,
  })
end

return Handler
