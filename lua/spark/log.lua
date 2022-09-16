--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____shared = require("spark.shared")
local CONFIG = ____shared.CONFIG
local LogLevel = ____shared.LogLevel
local function factory(level)
    return function(fmt, ...)
        if level >= CONFIG.log.level then
            vim.notify(
                string.format(fmt, ...),
                level
            )
        end
    end
end
____exports.debug = factory(LogLevel.DEBUG)
____exports.info = factory(LogLevel.INFO)
____exports.warn = factory(LogLevel.WARN)
____exports.error = factory(LogLevel.ERROR)
return ____exports
