---@diagnostic disable: invisible

local Config = require('meow.internal.config')
local Constants = require('meow.internal.constants')
local Plugin = require('meow.internal.plugin')
local PluginState = Constants.PluginState

---@class MeoPluginManager
local Manager = {}
local H = setmetatable({}, { __index = require('meow.internal.utils') })

---All registered plugins.
---@type MeoPlugin[]
H.plugins = {}
---A map of all plugins, indexed by their names.
---@type table<string,MeoPlugin>
H.plugin_map = {}

---Activates all enabled plugins and sets up configured event handlers.
---
---CAVEAT: This function may only be called once, after which no modifications
---may be made to the instance or any added plugins.
Manager.setup = function()
  if H.did_setup then return end
  H.did_setup = true

  local Handler = require('meow.internal.handler')
  ---@type MeoPlugin[], MeoPlugin[]
  local start_plugins, opt_plugins = {}, {}

  -- 1) Resolve imports and dependencies.
  local visited = 1
  while visited <= #H.plugins do
    repeat
      local plugin = H.plugins[visited]
      visited = visited + 1
      if plugin:will_load() then
        -- Import all dependency specs.
        H.import_dependencies(plugin)
        if plugin:is_lazy() then
          table.insert(opt_plugins, plugin)
        else
          table.insert(start_plugins, plugin)
        end
      end
    until visited > #H.plugins

    -- Load the plugin before resolving its imports as the imports may not
    -- exist until the plugin is installed.
    Manager.activate_many(start_plugins)
    for _, plugin in ipairs(start_plugins) do
      if plugin.import then
        for _, mod in ipairs(plugin.import) do
          Manager.import(mod)
        end
      end
    end
  end
  -- Reject new plugins
  local freeze = function() error('new plugins are not allowed after setup') end
  setmetatable(H.plugins, { __newindex = freeze })
  setmetatable(H.plugin_map, { __newindex = freeze })

  -- 2) Initialize start plugins.
  table.sort(start_plugins, H.plugin_ordering) -- resolve loading order
  for _, plugin in ipairs(start_plugins) do
    H.plugin_call(plugin, 'init')
  end

  -- 3) Initialize lazy-load plugins.
  local unloaded_opt_plugins = {}
  for _, plugin in ipairs(opt_plugins) do
    if plugin.import then
      H.notifyf('WARN', 'imports of lazy plugin "%s" are not supported', plugin.name)
    end
    H.plugin_call(plugin, 'init')

    if plugin:is_shadow() or vim.uv.fs_stat(plugin:path()) then
      Handler.add(plugin)
    else
      -- If a plugin is not installed, install and load it directly.
      table.insert(unloaded_opt_plugins, plugin)
    end
  end

  -- 4) Setup lazy handlers
  Handler.setup(Manager.load_many) -- a start plugin must not depend on a lazy-load plugin

  -- 5) Load start plugins and install lazy plugins
  Manager.load_many(start_plugins)
  H.later(function() Manager.load_many(unloaded_opt_plugins) end)

  -- 5) Sync cache tokens if updated
  if H.cache_expired then H.later(H.sync_cache_tokens) end
end

---Returns the plugin specified by name.
---@param name string
---@return MeoPlugin?
Manager.get = function(name) return H.plugin_map[name] end

---Returns all registered plugins. The returned table MUST NOT be modified.
---@return MeoPlugin[]
Manager.plugins = function() return H.plugins end

---(debug) Get the internal state for debugging purpose.
Manager.debug = function()
  local packinfo_map = {}
  for _, data in ipairs(vim.pack.get()) do
    packinfo_map[data.spec.name] = data
  end

  local plugins = {}
  for _, plugin in ipairs(H.plugins) do
    local packinfo = packinfo_map[plugin.name] or {}
    table.insert(plugins, {
      name = plugin.name,
      source = plugin.source,
      path = plugin:path(),
      state = Constants.PluginStateNames[plugin:_get_state()],
      rev = packinfo.rev,
    })
  end

  return plugins
end

---Updates the specified plugins the pinned revision.
---@param names? string[]
Manager.sync = function(names) Manager.update(names, { target = 'lockfile' }) end

---Update plugins. See `:h vim.pack.update`.
---@param names? string[]
---@param opts? vim.pack.keyset.update
Manager.update = function(names, opts)
  Manager.activate_all()
  vim.pack.update(names, opts)
end

---Remove all inactive plugins.
---@param opts? vim.pack.keyset.del
Manager.clean = function(opts)
  Manager.activate_all()
  local inactive = vim
    .iter(vim.pack.get())
    :filter(function(x) return not x.active end)
    :map(function(x) return x.spec.name end)
    :totable()
  vim.pack.del(inactive, opts)
end

---Loads a plugin if it is not loaded or disabled.
---@param plugin string|MeoPlugin
Manager.load = function(plugin)
  -- Resolve the plugin by name.
  if type(plugin) == 'string' then
    local p = Manager.get(plugin)
    if not p then
      H.notifyf('ERROR', 'attempted to load an undefined plugin "%s"', plugin)
      return
    end
    plugin = p
  end
  Manager.load_many({ plugin })
end

---Imports all plugin specs from the direct submodules under the root module.
---
---A module may return a plugin spec or a list of plugin specs.
---@param root string
---@param opts? {cache_token?:string}
Manager.import = function(root, opts)
  local cache_token = (opts or {}).cache_token or Config.import_cache
  if type(cache_token) == 'function' then cache_token = cache_token() end
  cache_token = cache_token or '' ---@cast cache_token string

  -- Try loading form cache
  local cache_name, cache_path
  if cache_token ~= '' then
    cache_name = root:gsub('%.', '_')
    cache_path = H.cache_dir .. '/' .. cache_name .. '.lua'
    if H.check_cache_token(cache_name, cache_token) then
      -- Cache hit, all modules should be imported
      dofile(cache_path)
      return
    end
  end

  -- Find all modules under the root module
  ---@type {[1]:string,[2]:string}[]
  local mods = {}
  H.scan_submods(root, function(mod, path) table.insert(mods, { mod, path }) end)
  if #mods == 0 then
    H.notifyf('WARN', 'import root "%s" is empty', root)
    return
  end

  -- Load each module in alphabetical order
  table.sort(mods, function(a, b) return a[1] < b[1] end)
  for _, m in ipairs(mods) do
    local mod, path = m[1], m[2]
    ---Import specs from a module, reporting errors if failed
    local ok, err = pcall(function()
      local chunk, err = loadfile(path)
      if not chunk then error(err) end
      package.preload[mod] = chunk

      local specs = require(mod)
      if type(specs) ~= 'table' then
        error('invalid spec: ' .. vim.inspect(specs))
      else
        Manager.add_many(specs)
      end
    end)
    -- Skip caching as error occurs.
    if not ok then
      cache_token = ''
      H.notifyf('ERROR', 'failed to import module %s: %s', mod, err)
    end
  end

  if cache_token ~= '' then
    -- Defer cache rebuilding to speed up startup
    H.later(function()
      vim.fn.mkdir(H.cache_dir, 'p')
      local cache_file = assert(io.open(cache_path, 'w'))

      -- Load modules sequentially
      assert(cache_file:write("local Manager = require('meow.internal.manager')\n"))
      for _, m in ipairs(mods) do
        local mod, path = m[1], m[2]
        local mod_name = vim.inspect(mod)
        local mod_source = assert(io.open(path, 'r')):read('*a')
        assert(
          cache_file:write(
            ('package.preload[%s] = function()\n'):format(mod_name),
            ('-- BEGIN:%s\n'):format(path),
            mod_source,
            ('-- END:%s\n'):format(path),
            ('end\nManager.add_many(require(%s))\n'):format(mod_name)
          )
        )
      end
    end)
  end
end

---Adds one or more plugins from the given spec(s).
---@param specs MeoSpecImport
Manager.add_many = function(specs)
  if type(specs[1]) ~= 'table' then specs = { specs } end
  ---@cast specs MeoSpec[]
  for _, spec in ipairs(specs) do
    Manager.add(spec)
  end
end

---Creates or updates a plugin from the given spec, returning the plugin
---instance if a name is specified.
---@param spec MeoSpec
---@return MeoPlugin?
Manager.add = function(spec)
  if not spec[1] then
    -- If the spec contains only an import field, resolve the import
    -- immediately; otherwise, defer that until it is installed.
    local imports = spec.import
    if type(imports) ~= 'table' then imports = { imports } end
    ---@cast imports string[]
    if #imports > 0 then
      local import_opts = { cache_token = spec.import_cache }
      for _, mod in ipairs(imports) do
        Manager.import(mod, import_opts)
      end
    end
    return
  end

  local name, source = string.match(spec[1], '.*/([%w-_.]+)$'), spec[1]
  name = name or spec[1]
  if H.plugin_map[name] then
    H.notifyf('ERROR', 'attempted to register a duplicate plugin "%s"', name)
    return
  end
  if string.find(source, '^[%w-]+/[%w-_.]+$') ~= nil then
    source = 'https://github.com/' .. source
  end

  -- Register the plugin.
  local plugin = Plugin.new(name, #H.plugins)
  plugin.source = source
  table.insert(H.plugins, plugin)
  H.plugin_map[name] = plugin

  -- Merge the value of each spec key.
  for key, val in pairs(spec) do
    local vtype = Constants.SPEC_VTYPES[key]
    if not vtype then
      -- Skip user-defined keys.
    elseif vtype == 'deprecated' then
      H.notifyf('ERROR', 'spec key "%s" is deprecated for plugin "%s"', key, name)
    elseif vtype == 'list' then
      plugin[key] = type(val) ~= 'table' and { val } or val
    elseif vtype == 'primitive' then
      plugin[key] = val
    else
      error('unreable')
    end
  end

  return plugin
end

---Loads all given plugins.
---@param plugins MeoPlugin[]
Manager.load_many = function(plugins)
  local pending_set = {} ---@type table<string,true>
  local pending_list = {} ---@type MeoPlugin[]
  for _, plugin in ipairs(plugins) do
    if plugin:_get_state() < PluginState.LOADING then
      for _, dep in ipairs(H.resolve_dependencies(plugin)) do
        if not pending_set[dep.name] then
          pending_set[dep.name] = true
          table.insert(pending_list, dep)
        end
      end
    elseif not plugin:will_load() then
      H.notifyf('ERROR', 'attempted to load a disabled plugin "%s"', plugin.name)
    end
  end

  Manager.activate_many(pending_list)
  for _, plugin in ipairs(pending_list) do
    plugin._state = PluginState.LOADING
    H.plugin_call(plugin, 'config')
    plugin._state = PluginState.LOADED
  end
end

---Adds all given plugins to vim.pack.
---@param plugins MeoPlugin[]
Manager.activate_many = function(plugins)
  local pending = {}
  for _, plugin in ipairs(plugins) do
    -- An ignored plugin can still be manually activated.
    local state = plugin:_get_state()
    if state < PluginState.ACTIVATED or state == PluginState.IGNORED then
      ---Convert the given plugin to a spec acceptable to vim.pack.
      ---@type vim.pack.Spec
      local vimspec = {
        name = plugin.name,
        src = plugin.source,
        -- Prefer the pinned version if snapshot is loaded.
        version = plugin.version,
        data = plugin,
      }
      table.insert(pending, vimspec)
    end
  end

  vim.pack.add(pending, { confirm = false })
  for _, spec in ipairs(pending) do
    local plugin = spec.data
    if plugin:_get_state() < PluginState.ACTIVATED then plugin._state = PluginState.ACTIVATED end
  end
end

---Adds all plugins to vim.pack, mainly used to make vim.pack recognize all
---registered lazy-loading plugins before updating or cleaning.
Manager.activate_all = function()
  if H.activated_all then return end
  H.activated_all = true
  Manager.activate_many(H.plugins)
end

---Imports the dependency specs of the given plugin.
---@param plugin MeoPlugin
H.import_dependencies = function(plugin)
  if plugin.dependencies then
    plugin._deps = plugin._deps or {}
    for _, dep_spec in ipairs(plugin.dependencies) do
      local dep_name
      if type(dep_spec) == 'string' then
        dep_name = dep_spec
      else
        local dep = Manager.add(dep_spec)
        if not dep then
          H.notifyf(
            'ERROR',
            'dependency spec for %s is not a valid plugin: %s',
            plugin.name,
            vim.inspect(dep_spec)
          )
        else
          dep._is_dep = true
          dep_name = dep.name
        end
      end
      plugin._deps[dep_name] = true
    end
  end
end

---Resolves dependencies that are required by the given plugin.
---
---The returned list excludes any already loaded plugins and is sorted by
---appropriate order. It contains the given plugin itself as well.
---@param plugin MeoPlugin
---@return MeoPlugin[]
H.resolve_dependencies = function(plugin)
  ---@type MeoPlugin[]
  local deps = {}
  H.collect_dependencies(deps, plugin)
  table.sort(deps, H.plugin_ordering)
  return deps
end

---Recursively collects all dependencies of the given plugin using DFS.
---@param result MeoPlugin[]
---@param plugin MeoPlugin
H.collect_dependencies = function(result, plugin)
  -- Skip if resolved, loaded or disabled.
  if plugin._level ~= 0 or plugin:_get_state() >= PluginState.LOADING then return end

  if not plugin._deps then
    plugin._level = 1
  else
    plugin._level = -1 -- Set a temporary mark to detect circular references.
    local dep_level = 0
    for dep_name, _ in pairs(plugin._deps) do
      local dep = H.plugin_map[dep_name]
      if not dep then
        if dep_name:find('/') then
          H.notifyf('ERROR', 'dependency "%s" must be defined as a spec', dep_name)
        else
          H.notifyf('ERROR', 'dependency "%s" is undefined', dep_name)
        end
      elseif dep._level == -1 then
        H.notifyf('ERROR', 'found circular dependency: "%s" and "%s"', plugin.name, dep_name)
      else
        H.collect_dependencies(result, dep)
        dep_level = math.max(dep_level, dep._level)
      end
    end
    plugin._level = dep_level + 1
  end

  table.insert(result, plugin)
end

---@param plugin MeoPlugin
---@param fname string
H.plugin_call = function(plugin, fname)
  local f = plugin[fname]
  if f == nil then return end
  if not vim.is_callable(f) then
    H.notifyf('ERROR', 'field %s must be a callable for plugin "%s"', fname, plugin.name)
    return
  end
  local ok, err = pcall(f, plugin)
  if not ok then
    H.notifyf('ERROR', 'failed to call field %s of plugin "%s": %s', fname, plugin.name, err)
  end
end

---Returns true if plugin `a` should be loaded before plugin `b`.
---
---Plugins with a higher level are always loaded first. Otherwise, if two
---plugins have the same level, the one with the lower priority is loaded first.
---If both the levels and the priorities are equal, their registration orders
---are taken into account to produce a deterministic loading sequence.
---@param a MeoPlugin
---@param b MeoPlugin
---@return boolean
H.plugin_ordering = function(a, b)
  if a._level ~= b._level then return a._level < b._level end
  if a.priority ~= b.priority then return a.priority > b.priority end
  return a._idx < b._idx
end

H.cache_dir = vim.fn.stdpath('cache') .. '/meow'

---@param name string
---@param token string
---@return boolean
H.check_cache_token = function(name, token)
  -- Lazy-load cache manifest
  ---@type table<string,string>|{['$version']:number}
  local tokens = H.cache_tokens
  if not tokens then
    local ok, cache_token_path = nil, H.cache_dir .. '/cache'
    ok, tokens = pcall(dofile, cache_token_path)
    tokens = ok and tokens or {}
    H.cache_tokens = tokens
  end
  -- Ensure both the version and the token match
  if tokens[name] == token and tokens['$version'] == Constants.cache_version then
    return true
  else
    tokens[name] = token
    tokens['$version'] = Constants.cache_version
    H.cache_expired = true
    return false
  end
end

H.sync_cache_tokens = function()
  vim.fn.mkdir(H.cache_dir, 'p')
  local cache_token_path = H.cache_dir .. '/cache'
  local cache_tbl = vim.inspect(H.cache_tokens)
  assert(assert(io.open(cache_token_path, 'w')):write('return ', cache_tbl))
end

return Manager
