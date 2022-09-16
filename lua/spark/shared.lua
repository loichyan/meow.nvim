--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____utils = require("spark.utils")
local join_path = ____utils.join_path
____exports.LogLevel = vim.log.levels
____exports.DEFAULT_SPEC = {
    [1] = "",
    from = "",
    start = false,
    disable = false,
    priority = 0,
    after = {},
    run = function()
    end,
    __state = "NONE",
    __path = ""
}
____exports.CONFIG = {
    [1] = function()
    end,
    root = join_path(
        vim.fn.stdpath("data"),
        "site/pack/spark"
    ),
    log = {level = ____exports.LogLevel.WARN},
    after_load = function()
    end
}
____exports.PLUGINS = {}
return ____exports
