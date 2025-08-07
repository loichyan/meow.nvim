---@diagnostic disable: invisible

local Config = require("meow.internal.config")
local Constants = require("meow.internal.constants")
local Plugin = require("meow.internal.plugin")
local Utils = require("meow.internal.utils")
local PluginState = Constants.PluginState

---Returns true if plugin `a` should be loaded before plugin `b`.
---
---Plugins with a higher level are always loaded first. Otherwise, if two
---plugins have the same level, the one with the lower priority is loaded first.
---If both the levels and the priorities are equal, their registration orders
---are taken into account to produce a deterministic loading sequence.
---@param a MeoPlugin
---@param b MeoPlugin
---@return boolean
local plugin_ordering = function(a, b)
  if a._level ~= b._level then return a._level < b._level end
  if a.priority ~= b.priority then return a.priority > b.priority end
  return a._idx < b._idx
end

---Parses the spec name and possible source URI from the given string.
---@param str string
---@return string,string?
local parse_plugin_name = function(str)
  local basename = string.match(str, ".*/(.*)")
  if not basename then
    return str, nil
  else
    return basename, str
  end
end

---@type table<string,string>|nil
local import_cache_tokens
local cache_dirty = false
local cache_dir = vim.fn.stdpath("cache") .. "/meow"

---@param name string
---@param token string
---@return boolean
local check_cache_token = function(name, token)
  if not import_cache_tokens then
    local cache_token_path = cache_dir .. "/cache"
    local ok, tokens = pcall(dofile, cache_token_path)
    import_cache_tokens = ok and tokens or {}
  end
  if import_cache_tokens[name] == token then
    return true
  else
    import_cache_tokens[name] = token
    cache_dirty = true
    return false
  end
end

local sync_cache_tokens = function()
  vim.fn.mkdir(cache_dir, "p")
  local cache_token_path = cache_dir .. "/cache"
  assert(assert(io.open(cache_token_path, "w")):write("return ", vim.inspect(import_cache_tokens)))
end

---@class MeoPluginManager
---All registered plugins.
---@field private _plugins MeoPlugin[]
---A map of all plugins, indexed by their names.
---@field private _plugin_map table<string,MeoPlugin>
---The snapshot of registered plugins.
---@field private _snapshot table<string,string>
---@field private _did_setup? boolean
local Manager = {}

---Creates a new plugin manager.
---@return MeoPluginManager
function Manager.new()
  return setmetatable({
    _plugins = {},
    _plugin_map = {},
    _snapshot = {},
  }, { __index = Manager })
end

---Activates all enabled plugins and sets up configured event handlers.
---
---CAVEAT: This function may only be called once, after which no modifications
---may be made to the instance or any added plugins.
function Manager:setup()
  if self._did_setup then
    Utils.notify("WARN", "PluginManager has been initialized")
    return
  end
  self:_really_setup()

  local freezed = function() error("PluginManager has been freezed") end
  setmetatable(self._plugins, { __newindex = freezed })
  setmetatable(self._plugin_map, { __newindex = freezed })

  self._did_setup = true
end

function Manager:_really_setup()
  local handler = require("meow.internal.handler").new(self)
  ---@type MeoPlugin[]
  local opt_plugins = {}

  -- 1) Resolve imports and dependencies.
  local visited = 1
  while visited <= #self._plugins do
    -- Collect start plugins to sort them so that they are loaded in the
    -- desired order.
    ---@type MeoPlugin[]
    local start_plugins = {}
    repeat
      local plugin = self._plugins[visited]
      visited = visited + 1

      if plugin._state ~= PluginState.NONE then
      elseif not plugin:is_enabled() then
        plugin._state = PluginState.DISABLED
      elseif plugin:is_ignored() then
        plugin._state = PluginState.IGNORED
      else
        if not plugin:is_shadow() then
          plugin.path =
            vim.fs.normalize(MiniDeps.config.path.package .. "/pack/deps/opt/" .. plugin.name)
        end

        if plugin.init then plugin:init() end
        -- Import all dependency specs.
        self:_import_dependencies(plugin)
        if plugin:is_lazy() then
          table.insert(opt_plugins, plugin)
        else
          table.insert(start_plugins, plugin)
        end
      end
    until visited > #self._plugins

    table.sort(start_plugins, plugin_ordering)
    for _, plugin in ipairs(start_plugins) do
      -- Load the plugin before resolving its imports as the import paths
      -- may not exist if the plugin not installed.
      self:load(plugin)
      if plugin.import then
        for _, mod in ipairs(plugin.import) do
          self:import(mod)
        end
      end
    end
  end

  -- 2) Lazy-load opt plugins.
  for _, plugin in ipairs(opt_plugins) do
    if plugin.import then
      Utils.notify("ERROR", "imports of lazy plugins are not supported: " .. plugin.name)
    end

    if not plugin.path or vim.uv.fs_stat(plugin.path) then
      handler:add(plugin)
    else
      -- If a plugin is not installed, defer the setup of handlers.
      MiniDeps.later(function()
        self:activate(plugin)
        handler:add(plugin)
      end)
    end
  end

  -- 3) Setup lazy handlers
  handler:setup()
  -- 4) Sync cache tokens if updated
  if cache_dirty then vim.schedule(sync_cache_tokens) end
end

---Returns the plugin specified by name.
---@param name string
---@return MeoPlugin?
function Manager:get(name) return self._plugin_map[name] end

---Returns all registered plugins. The returned table MUST NOT be modified.
---@return MeoPlugin[]
function Manager:plugins() return self._plugins end

---Imports all plugin specs from the direct submodules under the root module.
---
---A module may return a plugin spec or a list of plugin specs.
---@param root string
---@param opts? {cache_token?:string}
function Manager:import(root, opts)
  opts = opts or {}
  local cache_token = opts.cache_token or Config.import_cache
  if type(cache_token) == "function" then cache_token = cache_token() end
  cache_token = cache_token or ""

  -- Try load form cache
  local cache_name, cache_path
  if cache_token ~= "" then
    cache_name = root:gsub("%.", "_")
    cache_path = cache_dir .. "/" .. cache_name .. ".lua"
    if check_cache_token(cache_name, cache_token) then
      -- Cache hit, all modules should be imported
      dofile(cache_path)(self)
      return
    end
  end

  -- Find all modules under the root module
  ---@type {[1]:string,[2]:string}[]
  local mods = {}
  Utils.scan_submods(root, function(mod, path) table.insert(mods, { mod, path }) end)
  if #mods == 0 then error("failed to find imports from: " .. root) end
  -- Ensure that all modules are imported in alphabetical order
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
        self:add_many(specs)
      end
    end)
    if not ok then Utils.notifyf("ERROR", "failed to import module %s: %s", mod, err) end
  end

  if cache_token ~= "" then
    -- Defer cache rebuilding to speed up startup
    vim.schedule(function()
      vim.fn.mkdir(cache_dir, "p")
      local cache_file = assert(io.open(cache_path, "w"))

      -- Load modules sequentially
      assert(cache_file:write("return function(manager)\n"))
      for _, m in ipairs(mods) do
        local mod, path = m[1], m[2]
        local mod_name = vim.inspect(mod)
        local mod_source = assert(io.open(path, "r")):read("*a")
        assert(
          cache_file:write(
            ("package.preload[%s] = function()\n"):format(mod_name),
            mod_source,
            ("end\nmanager:add_many(require(%s))\n"):format(mod_name)
          )
        )
      end
      assert(cache_file:write("end"))

      -- Re-compile to bytecodes
      assert(cache_file:close())
      local bytes = string.dump(assert(loadfile(cache_path)))
      assert(assert(io.open(cache_path, "w")):write(bytes))
    end)
  end
end

---Loads the snapshot from the specified path.
---@param path string
function Manager:load_snap_from(path)
  local ok, snap = pcall(dofile, path)
  if not ok then
    Utils.notifyf("ERROR", "failed to load snapshot from '%s': %s", path, snap)
  elseif type(snap) ~= "table" then
    Utils.notifyf("ERROR", "snapshot from '%s' is invalid")
  else
    self:load_snap(snap)
  end
end

---Loads a snapshot generated by MiniDeps.
---@param snap table<string,string>
function Manager:load_snap(snap)
  -- Defer loading snapshots until all imports are resolved.
  for k, v in pairs(snap) do
    self._snapshot[k] = v
  end
end

---Adds one or more plugins from the given spec(s).
---@param specs MeoSpecs
function Manager:add_many(specs)
  if #specs > 1 or type(specs[1]) == "table" then
    ---@cast specs MeoSpec[]
    for _, spec in ipairs(specs) do
      self:add(spec)
    end
  else
    self:add(specs)
  end
end

---Creates or updates a plugin from the given spec, returning the plugin
---instance if a name is specified.
---@param spec MeoSpec
---@return MeoPlugin?
function Manager:add(spec)
  if not spec[1] then
    -- If the spec contains only an import field, resolve the import
    -- immediately; otherwise, defer the resolution after this plugin is
    -- activated.
    local imports = spec.import
    if imports then
      local import_opts = { cache_token = spec.import_cache }
      if type(imports) == "table" then
        for _, mod in ipairs(imports) do
          self:import(mod, import_opts)
        end
      else
        self:import(imports, import_opts)
      end
    end
    return
  end

  local name, source = parse_plugin_name(spec[1])
  local plugin = self._plugin_map[name]
  if not plugin then
    plugin = Plugin.new(name)
    plugin._idx = #self._plugins
    table.insert(self._plugins, plugin)
    self._plugin_map[name] = plugin
  end

  -- Update plugin properties.
  plugin:_update_spec(spec)

  -- Set the source to the possible URI if no alternative source is provided.
  if not plugin.source then plugin.source = source end

  return plugin
end

---Imports the dependency specs of the given plugin.
---@private
---@param plugin MeoPlugin
function Manager:_import_dependencies(plugin)
  if plugin.dependencies then
    plugin._deps = plugin._deps or {}
    for _, dep_spec in ipairs(plugin.dependencies) do
      local dep_name
      if type(dep_spec) == "string" then
        dep_name = dep_spec
      else
        local dep = self:add(dep_spec)
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

---Loads a plugin if it is not loaded or disabled.
---@param plugin string|MeoPlugin
function Manager:load(plugin)
  if type(plugin) == "string" then
    local p = self:get(plugin)
    if not p then
      Utils.notify("ERROR", "attempted to load an undefined plugin " .. plugin)
      return
    end
    plugin = p
  end

  if plugin._state >= PluginState.IGNORED then
    Utils.notifyf("ERROR", "attempted to load a disabled plugin '%s'", plugin.name)
  elseif plugin._state >= PluginState.LOADING then
    return
  end

  for _, dep in ipairs(self:_resolve_dependencies(plugin)) do
    self:activate(dep)
    dep._state = PluginState.LOADING
    if dep.config then
      local ok, err = pcall(dep.config, dep)
      if not ok then Utils.notifyf("ERROR", "failed to setup '%s': %s", dep.name, err) end
    end
    dep._state = PluginState.LOADED
  end
end

---Adds all plugins to MiniDeps, mainly used to to make MiniDeps recognize all
---registered lazy-loading plugins before updating or cleaning.
function Manager:activate_all()
  for _, plugin in ipairs(self._plugins) do
    self:activate(plugin)
  end
end

---Adds the given to MiniDeps.
---@param plugin MeoPlugin
function Manager:activate(plugin)
  if plugin._state >= PluginState.ACTIVATED and plugin._state ~= PluginState.IGNORED then return end
  -- Apply snapshot.
  plugin.checkout = self._snapshot[plugin.name] or plugin.checkout
  if not plugin:is_shadow() then MiniDeps.add(plugin:to_mini()) end

  if plugin._state < PluginState.ACTIVATED then plugin._state = PluginState.ACTIVATED end
end

---Resolves dependencies that are not loaded and required by the given plugin.
---
---The returned list contains the plugin itself at the end and is sorted in an
---appropriate loading order.
---@private
---@param plugin MeoPlugin
---@return MeoPlugin[]
function Manager:_resolve_dependencies(plugin)
  ---@type MeoPlugin[]
  local deps = {}
  self:_collect_dependencies(deps, plugin)
  table.sort(deps, plugin_ordering)
  return deps
end

---Recursively collects all dependencies of the given plugin using DFS.
---@private
---@param result MeoPlugin[]
---@param plugin MeoPlugin
function Manager:_collect_dependencies(result, plugin)
  -- Skip if resolved, loaded or disabled.
  if plugin._level ~= 0 or plugin._state >= PluginState.LOADING then return end

  if not plugin._deps then
    plugin._level = 1
  else
    plugin._level = -1 -- Set a temporary mark to detect circular references.
    local dep_level = 0
    for dep_name, _ in pairs(plugin._deps) do
      local dep = self._plugin_map[dep_name]
      if not dep then
        error(("found undefined dependency: %s"):format(dep_name))
      elseif dep._level == -1 then
        error(("found circular dependencies: %s and %s"):format(plugin.name, dep_name))
      else
        self:_collect_dependencies(result, dep)
        dep_level = math.max(dep_level, dep._level)
      end
    end
    plugin._level = dep_level + 1
  end

  table.insert(result, plugin)
end

-- TODO: migrate to mini.test
function Manager.test_add_plugin()
  MiniDeps = {
    add = function(p) vim.print(p) end,
  }
  local m = Manager.new()
  m:add({ "a", dependencies = { "b", "d" } })
  m:add({ "b", dependencies = { "c" } })
  m:add({ "c" })
  m:add({ "d", dependencies = { "e" } })
  m:add({ "e", dependencies = { "c" } })
  m:add({ "f", priority = 100 })
  m:add({ "g", priority = 1 })
  m:add({ "h" })
  m:add({
    "a",
    priority = 999,
    config = function(self) vim.print("SETUP(A)", self) end,
  })
  vim.print("LOAD(A)")
  m:load(assert(m:get("a")))
  vim.print("LOAD(F)")
  m:load(assert(m:get("f")))
end

return Manager
