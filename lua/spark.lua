--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____shared = require("spark.shared")
local CONFIG = ____shared.CONFIG
local PLUGINS = ____shared.PLUGINS
local sys = require("spark.sys")
local ____utils = require("spark.utils")
local deep_merge = ____utils.deep_merge
local join_path = ____utils.join_path
local log = require("spark.log")
local ____spec = require("spark.spec")
local new_spec = ____spec.new_spec
local validate = ____spec.validate
local ____sequence = require("spark.sequence")
local resolve = ____sequence.resolve
local ____job = require("spark.job")
local Job = ____job.Job
local function plug_path(is_start, name)
    local dir = "opt"
    if is_start then
        dir = "start"
    end
    return join_path(CONFIG.root, dir, name)
end
local function local_plugin()
    local plugins = {}
    for name in sys.scandir(plug_path(true, "")) do
        plugins[name] = true
    end
    for name in sys.scandir(plug_path(false, "")) do
        plugins[name] = false
    end
    return plugins
end
function ____exports.setup(config)
    deep_merge("force", CONFIG, config or ({}))
    local installed = local_plugin()
    local plugins = {}
    CONFIG[1](function(orig)
        local spec, err = validate(orig)
        if spec == nil then
            log.error(err)
            return
        end
        local name = spec[1]
        if spec.__state == "NONE" then
            local is_start = installed[name]
            installed[name] = nil
            if is_start == nil then
                spec.__state = "CLONE"
            elseif is_start ~= spec.start then
                spec.__state = "MOVE"
            elseif is_start then
                spec.__state = "POST_LOAD"
            elseif not spec.disable then
                spec.__state = "LOAD"
            else
                spec.__state = "DISABLE"
            end
            spec.__path = plug_path(spec.start, name)
        end
        table.insert(plugins, spec)
    end)
    for name, start in pairs(installed) do
        local spec = new_spec({[1] = name, start = start})
        spec.__state = "REMOVE"
        table.insert(plugins, spec)
        spec.__path = plug_path(spec.start, name)
    end
    local resolved, msg = resolve(plugins)
    if resolved == nil then
        log.error(msg)
        return
    end
    for _, v in ipairs(resolved) do
        table.insert(PLUGINS, v)
    end
end
function ____exports.plugins()
    return PLUGINS
end
local function post_update(spec)
    local run = spec.run
    local name = spec[1]
    if run ~= nil then
        log.debug("post-update:run %s", spec[1])
        if type(run) == "function" then
            run()
        else
            Job.new({cmd = run, cwd = spec.__path}):run()
        end
    end
    local path = join_path(spec.__path, "doc")
    local ____sys_exists_result_type_0 = sys.exists(path)
    if ____sys_exists_result_type_0 ~= nil then
        ____sys_exists_result_type_0 = ____sys_exists_result_type_0.type
    end
    if ____sys_exists_result_type_0 == "directory" then
        log.debug("load:gendoc %s", name)
        vim.cmd("helptags " .. path)
    end
end
function ____exports.install()
    for _, spec in ipairs(PLUGINS) do
        local name = spec[1]
        if spec.__state == "CLONE" then
            log.debug("install:clone %s", name)
            local code = Job.new({cmd = {
                "git",
                "clone",
                spec.from,
                spec.__path,
                "--depth",
                "1",
                "--progress"
            }}):run()
            if code == 0 then
                spec.__state = "LOAD"
                post_update(spec)
            end
        elseif spec.__state == "MOVE" then
            log.debug("install:move %s", name)
            sys.rename(
                plug_path(not spec.start, name),
                spec.__path
            )
            spec.__state = "LOAD"
        end
    end
end
function ____exports.load()
    for _, spec in ipairs(PLUGINS) do
        local name = spec[1]
        if spec.__state == "LOAD" then
            log.debug("load %s", name)
            vim.cmd("packadd " .. name)
            spec.__state = "POST_LOAD"
        end
    end
end
function ____exports.post_load()
    local cfg_post_load = CONFIG.post_load
    for _, spec in ipairs(PLUGINS) do
        local name = spec[1]
        if spec.__state == "POST_LOAD" then
            local setup = spec.setup
            if setup ~= nil then
                log.debug("post-load:setup %s", name)
                setup()
            end
            if cfg_post_load ~= nil then
                log.debug("post-load:config %s", name)
                cfg_post_load(spec)
            end
            spec.__state = "LOADED"
        end
    end
end
function ____exports.clean()
    for _, spec in ipairs(PLUGINS) do
        if spec.__state == "REMOVE" then
            local name = spec[1]
            log.debug("remove %s", name)
            if sys.remove(spec.__path) then
                spec.__state = "NONE"
            end
        end
    end
end
return ____exports
