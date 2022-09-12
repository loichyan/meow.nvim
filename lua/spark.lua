local M = {}
local utils = require("spark.utils")
local sys = require("spark.sys")
local log = require("spark.log")
local spec_utils = require("spark.spec")
local shared = require("spark.shared")
local sequence = require("spark.sequence")
local State = shared.SpecState
local CONFIG = shared.CONFIG
local PLUGINS = shared.PLUGINS

---@param is_start boolean
---@param name string
---@return string
local function plug_path(is_start, name)
  local dir = "opt"
  if is_start then
    dir = "start"
  end
  return utils.join_paths(CONFIG.root, dir, name)
end

---@return table<string,boolean>
local function local_plugins()
  local plugins = {}
  for name in sys.scandir(plug_path(true, "")) do
    plugins[name] = true
  end
  for name in sys.scandir(plug_path(false, "")) do
    plugins[name] = false
  end
  return plugins
end

---@param spec Spark.Spec
local function load_plugin(spec)
  local name = spec[1]
  log.debug("load " .. name)
  vim.cmd("packadd " .. name)
  CONFIG.after_load(spec)
end

---@param config? Spark.Config
function M.setup(config)
  utils.deep_merge(true, CONFIG, config or {})
  local installed = local_plugins()
  local plugins = {}
  CONFIG[1](function(spec)
    -- Validate specification.
    spec = spec_utils.validate(spec)
    if type(spec) == "string" then
      log.error(spec)
      return
    end

    -- Figure out which State should be set.
    local name = spec[1]
    local is_start = installed[name]
    installed[name] = nil
    if is_start == nil then
      -- Clone from repo
      spec._state = State.Clone
    elseif is_start ~= spec.start then
      -- Move from start or opt
      spec._state = State.Move
    elseif is_start then
      spec._state = State.Loaded
    elseif not spec.disable then
      -- Load from opt
      spec._state = State.Load
    end

    table.insert(plugins, spec)
  end)

  -- Insert unused plugins to be removed.
  for name, opt in pairs(installed) do
    table.insert(plugins, { name, opt = opt, _state = State.Remove })
  end

  -- Resolve load sequence.
  local resolved, msg = sequence.resolve(plugins)
  if resolved == nil then
    ---@diagnostic disable-next-line: param-type-mismatch
    log.error(msg)
    return
  end

  -- Insert all plugins.
  for _, v in ipairs(resolved) do
    table.insert(PLUGINS, v)
  end
end

---@return Spark.Spec[]
function M.plugins()
  return PLUGINS
end

function M.install()
  for _, spec in ipairs(PLUGINS) do
    local name = spec[1]
    local installed = false
    if spec._state == State.Clone then
      if spec.from == nil then
        log.error(string.format("spec.from '%s' should be provided", name))
      end
      log.debug("clone " .. name)
      local path = plug_path(spec.start, name)
      vim.fn.system(
        string.format("git clone %s %s --depth 1 --progress", spec.from, path)
      )
      installed = true
    elseif spec._state == State.Move then
      log.debug("move " .. name)
      sys.rename(plug_path(not spec.start, name), plug_path(spec.start, name))
      installed = true
    end

    if installed then
      spec._state = State.Load
    end
  end
end

function M.load()
  for _, spec in ipairs(PLUGINS) do
    if spec._state == State.Load then
      load_plugin(spec)
      spec._state = State.Loaded
    end
  end
end

function M.clean()
  for _, spec in ipairs(PLUGINS) do
    if spec._state == State.Remove then
      local name = spec[1]
      local path = plug_path(spec.start, name)
      log.debug("remove " .. name)
      if sys.remove(path) then
        spec._state = nil
      end
    end
  end
end

return M
