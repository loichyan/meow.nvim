--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____utils = require("spark.utils")
local join_path = ____utils.join_path
____exports.CONFIG = {
    [1] = function()
    end,
    root = join_path(
        vim.fn.stdpath("data"),
        "site/pack/spark"
    ),
    log = {level = "WARN"}
}
____exports.PLUGINS = {}
return ____exports
