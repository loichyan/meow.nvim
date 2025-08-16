---@diagnostic disable: invisible

local Config = require("meow.internal.config")
local Constants = require("meow.internal.constants")
local Plugin = require("meow.internal.plugin")
local Utils = require("meow.internal.utils")
local PluginState = Constants.PluginState

---@class MeoPluginManager
local Manager = {}
local H = {}

---All registered plugins.
---@type MeoPlugin[]
H.plugins = {}
---A map of all plugins, indexed by their names.
---@type table<string,MeoPlugin>
H.plugin_map = {}
---The snapshot of registered plugins.
---@type  table<string,string>
H.snapshot = {}

---Activates all enabled plugins and sets up configured event handlers.
---
---CAVEAT: This function may only be called once, after which no modifications
---may be made to the instance or any added plugins.
function Manager.setup()
  if H.did_setup then return end
  H.did_setup = true

  local Handler = require("meow.internal.handler")
  ---@type MeoPlugin[], MeoPlugin[]
  local init_plugins, opt_plugins = {}, {}

  -- 1) Resolve imports and dependencies.
  local visited = 1
  while visited <= #H.plugins do
    -- Collect start plugins and then load them in appropriate order.
    ---@type MeoPlugin[]
    local start_plugins = {}
    repeat
      local plugin = H.plugins[visited]
      visited = visited + 1
      if not plugin:will_load() then goto continue end

      -- Import all dependency specs.
      H.import_dependencies(plugin)
      if plugin:is_lazy() then
        table.insert(opt_plugins, plugin)
      else
        table.insert(start_plugins, plugin)
      end

      ::continue::
    until visited > #H.plugins

    table.sort(start_plugins, H.plugin_ordering)
    for _, plugin in ipairs(start_plugins) do
      if plugin.init then table.insert(init_plugins, plugin) end
      -- Load the plugin before resolving its imports as the imports may not
      -- exist until the plugin is installed.
      Manager.load(plugin)
      if plugin.import then
        for _, mod in ipairs(plugin.import) do
          Manager.import(mod)
        end
      end
    end
  end
  -- Reject new plugins
  local freeze = function() error("new plugins are not allowed after setup") end
  setmetatable(H.plugins, { __newindex = freeze })
  setmetatable(H.plugin_map, { __newindex = freeze })

  -- 2) Run plugin initializors.
  for _, plugin in ipairs(init_plugins) do
    plugin:init()
  end

  -- 3) Lazy-load opt plugins.
  for _, plugin in ipairs(opt_plugins) do
    if plugin.import then
      Utils.notifyf("WARN", "imports of lazy plugin '%s' are not supported", plugin.name)
    end

    if plugin:is_shadow() or vim.uv.fs_stat(plugin:path()) then
      Handler.add(plugin)
    else
      -- If a plugin is not installed, defer the setup of handlers.
      MiniDeps.later(function()
        Manager.activate(plugin)
        Handler.add(plugin)
      end)
    end
  end

  -- 4) Setup lazy handlers
  Handler.setup(Manager.load)

  -- 5) Sync cache tokens if updated
  if H.cache_expired then MiniDeps.later(H.sync_cache_tokens) end
end

---Returns the plugin specified by name.
---@param name string
---@return MeoPlugin?
function Manager.get(name) return H.plugin_map[name] end

---Returns all registered plugins. The returned table MUST NOT be modified.
---@return MeoPlugin[]
function Manager.plugins() return vim.deepcopy(H.plugins) end

---Imports all plugin specs from the direct submodules under the root module.
---
---A module may return a plugin spec or a list of plugin specs.
---@param root string
---@param opts? {cache_token?:string}
function Manager.import(root, opts)
  local cache_token = (opts or {}).cache_token or Config.import_cache
  if type(cache_token) == "function" then cache_token = cache_token() end
  cache_token = cache_token or ""

  -- Try load form cache
  local cache_name, cache_path
  if cache_token ~= "" then
    cache_name = root:gsub("%.", "_")
    cache_path = H.cache_dir .. "/" .. cache_name .. ".lua"
    if H.check_cache_token(cache_name, cache_token) then
      -- Cache hit, all modules should be imported
      dofile(cache_path)
      return
    end
  end

  -- Find all modules under the root module
  ---@type {[1]:string,[2]:string}[]
  local mods = {}
  Utils.scan_submods(root, function(mod, path) table.insert(mods, { mod, path }) end)
  if #mods == 0 then
    Utils.notifyf("WARN", "import root '%s' is empty", root)
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
      if type(specs) ~= "table" then
        error("invalid spec: " .. vim.inspect(specs))
      else
        Manager.add_many(specs)
      end
    end)
    -- Skip caching as error occurs.
    if not ok then
      cache_token = ""
      Utils.notifyf("ERROR", "failed to import module %s: %s", mod, err)
    end
  end

  if cache_token ~= "" then
    -- Defer cache rebuilding to speed up startup
    MiniDeps.later(function()
      vim.fn.mkdir(H.cache_dir, "p")
      local cache_file = assert(io.open(cache_path, "w"))

      -- Load modules sequentially
      assert(cache_file:write('local Manager = require("meow.internal.manager")'))
      for _, m in ipairs(mods) do
        local mod, path = m[1], m[2]
        local mod_name = vim.inspect(mod)
        local mod_source = assert(io.open(path, "r")):read("*a")
        assert(
          cache_file:write(
            ("package.preload[%s] = function()\n"):format(mod_name),
            mod_source,
            ("end\nManager.add_many(require(%s))\n"):format(mod_name)
          )
        )
      end

      -- Re-compile to bytecodes
      assert(cache_file:close())
      local bytes = string.dump(assert(loadfile(cache_path)))
      assert(assert(io.open(cache_path, "w")):write(bytes))
    end)
  end
end

---Adds one or more plugins from the given spec(s).
---@param specs MeoSpecImport
function Manager.add_many(specs)
  if type(specs[1]) ~= "table" then specs = { specs } end
  ---@cast specs MeoSpec[]
  for _, spec in ipairs(specs) do
    Manager.add(spec)
  end
end

---Creates or updates a plugin from the given spec, returning the plugin
---instance if a name is specified.
---@param spec MeoSpec
---@return MeoPlugin?
function Manager.add(spec)
  if not spec[1] then
    -- If the spec contains only an import field, resolve the import
    -- immediately; otherwise, defer that until it is installed.
    local imports = spec.import
    if type(imports) ~= "table" then imports = { imports } end
    ---@cast imports string[]
    if #imports > 0 then
      local import_opts = { cache_token = spec.import_cache }
      for _, mod in ipairs(imports) do
        Manager.import(mod, import_opts)
      end
    end
    return
  end

  local name, source = H.parse_plugin_name(spec[1])
  if H.plugin_map[name] then
    Utils.notifyf("ERROR", "attempted to register a duplicate plugin", name)
    return
  end

  -- Register the plugin.
  local plugin = Plugin.new(name, #H.plugins)
  table.insert(H.plugins, plugin)
  H.plugin_map[name] = plugin

  -- Merge the value of each spec key.
  for key, val in pairs(spec) do
    local vtype = Constants.SPEC_VTYPES[key]
    if not vtype then
    elseif vtype == "list" then
      plugin[key] = type(val) ~= "table" and { val } or val
    else
      plugin[key] = val
    end
  end

  -- Resolve property aliases.
  if spec.build then
    plugin.hooks = plugin.hooks or {}
    plugin.hooks.post_checkout = spec.build
  end

  -- Update the source if not provided.
  if not plugin.source then plugin.source = source end

  return plugin
end

---Loads a plugin if it is not loaded or disabled.
---@param plugin string|MeoPlugin
function Manager.load(plugin)
  -- Resolve the plugin by name.
  if type(plugin) == "string" then
    local p = Manager.get(plugin)
    if not p then
      Utils.notifyf("ERROR", "attempted to load an undefined plugin '%s'", plugin)
      return
    end
    plugin = p
  end

  -- Ensure the plugin should be loaded.
  if plugin:_get_state() >= PluginState.LOADING then
    if not plugin:will_load() then
      Utils.notifyf("ERROR", "attempted to load a disabled plugin '%s'", plugin.name)
    end
    return
  end

  for _, dep in ipairs(H.resolve_dependencies(plugin)) do
    Manager.activate(dep)
    dep._state = PluginState.LOADING
    if dep.config then
      local ok, err = pcall(dep.config, dep)
      if not ok then Utils.notifyf("ERROR", "failed to setup '%s': %s", dep.name, err) end
    end
    dep._state = PluginState.LOADED
  end
end

---Adds the given to MiniDeps.
---@param plugin MeoPlugin
function Manager.activate(plugin)
  -- Install the plugin unless completely disabled.
  local state = plugin:_get_state()
  if state >= PluginState.ACTIVATED and state ~= PluginState.IGNORED then return end

  ---Convert the given plugin to a spec acceptable to MiniDeps.
  local minispec = {}
  for _, key in ipairs(Constants.MINI_SPEC_KEYS) do
    minispec[key] = plugin[key]
  end
  -- Ensure the snapped version if used.
  minispec.checkout = H.snapshot[plugin.name] or minispec.checkout

  -- Defer activations for plugins that must have been loaded already, as they
  -- can slightly slow down the startup.
  if vim.v.vim_did_enter == 0 and (plugin.name == "meow.nvim" or plugin.name == "mini.nvim") then
    MiniDeps.later(function() MiniDeps.add(minispec) end)
  else
    MiniDeps.add(minispec)
  end

  if state < PluginState.ACTIVATED then plugin._state = PluginState.ACTIVATED end
end

---Adds all plugins to MiniDeps, mainly used to to make MiniDeps recognize all
---registered lazy-loading plugins before updating or cleaning.
function Manager.activate_all()
  if H.activated_all then return end
  H.activated_all = true
  for _, plugin in ipairs(H.plugins) do
    Manager.activate(plugin)
  end
end

---Loads the snapshot from the specified path.
---@param path string
function Manager.load_snap_from(path)
  local ok, snap = pcall(dofile, path)
  if not ok then
    Utils.notifyf("ERROR", "failed to load snapshot from '%s': %s", path, snap)
  elseif type(snap) ~= "table" then
    Utils.notifyf("ERROR", "snapshot returned from '%s' is invalid: %s", path, vim.inspect(snap))
  else
    -- Defer loading snapshots until all imports are resolved.
    for k, v in pairs(snap) do
      H.snapshot[k] = v
    end
  end
end

---Imports the dependency specs of the given plugin.
---@param plugin MeoPlugin
function H.import_dependencies(plugin)
  if plugin.dependencies then
    plugin._deps = plugin._deps or {}
    for _, dep_spec in ipairs(plugin.dependencies) do
      local dep_name
      if type(dep_spec) == "string" then
        dep_name = dep_spec
      else
        local dep = Manager.add(dep_spec)
        if not dep then
          Utils.notifyf(
            "ERROR",
            "dependency spec for %s is not a valid plugin: %s",
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
---The returned list exlucdes any already loaded plugins and is sorted by
---appropriate order. It contains the given plugin itself as well.
---@param plugin MeoPlugin
---@return MeoPlugin[]
function H.resolve_dependencies(plugin)
  ---@type MeoPlugin[]
  local deps = {}
  H.collect_dependencies(deps, plugin)
  table.sort(deps, H.plugin_ordering)
  return deps
end

---Recursively collects all dependencies of the given plugin using DFS.
---@param result MeoPlugin[]
---@param plugin MeoPlugin
function H.collect_dependencies(result, plugin)
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
        if dep_name:find("/") then
          Utils.notifyf("ERROR", "dependency '%s' must be defined as a spec", dep_name)
        else
          Utils.notifyf("ERROR", "found undefined dependency: %s", dep_name)
        end
      elseif dep._level == -1 then
        Utils.notifyf("ERROR", "found circular dependency: %s and %s", plugin.name, dep_name)
      else
        H.collect_dependencies(result, dep)
        dep_level = math.max(dep_level, dep._level)
      end
    end
    plugin._level = dep_level + 1
  end

  table.insert(result, plugin)
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
function H.plugin_ordering(a, b)
  if a._level ~= b._level then return a._level < b._level end
  if a.priority ~= b.priority then return a.priority > b.priority end
  return a._idx < b._idx
end

---Parses the spec name and possible source URI from the given string.
---@param str string
---@return string,string?
function H.parse_plugin_name(str)
  local basename = string.match(str, ".*/(.*)")
  if not basename then
    return str, nil
  else
    return basename, str
  end
end

H.cache_dir = vim.fn.stdpath("cache") .. "/meow"

---@param name string
---@param token string
---@return boolean
function H.check_cache_token(name, token)
  -- Lazy-load cache manifest
  ---@type table<string,string>|{["$version"]:number}
  local tokens = H.cache_tokens
  if not tokens then
    local ok, cache_token_path = nil, H.cache_dir .. "/cache"
    ok, tokens = pcall(dofile, cache_token_path)
    tokens = ok and tokens or {}
    H.cache_tokens = tokens
  end
  -- Ensure both the version and the token match
  if tokens[name] == token and tokens["$version"] == Constants.cache_version then
    return true
  else
    tokens[name] = token
    tokens["$version"] = Constants.cache_version
    H.cache_expired = true
    return false
  end
end

function H.sync_cache_tokens()
  vim.fn.mkdir(H.cache_dir, "p")
  local cache_token_path = H.cache_dir .. "/cache"
  local cache_tbl = vim.inspect(H.cache_tokens)
  assert(assert(io.open(cache_token_path, "w")):write("return ", cache_tbl))
end

return Manager
