--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____shared = require("spark.shared")
local CONFIG = ____shared.CONFIG
local levels = vim.log.levels
local function level2vim(level)
    repeat
        local ____switch3 = level
        local ____cond3 = ____switch3 == "DEBUG"
        if ____cond3 then
            return levels.DEBUG
        end
        ____cond3 = ____cond3 or ____switch3 == "INFO"
        if ____cond3 then
            return levels.INFO
        end
        ____cond3 = ____cond3 or ____switch3 == "WARN"
        if ____cond3 then
            return levels.WARN
        end
        ____cond3 = ____cond3 or ____switch3 == "ERROR"
        if ____cond3 then
            return levels.ERROR
        end
    until true
end
local function factory(level)
    local lv = level2vim(level)
    return function(fmt, ...)
        if lv >= level2vim(CONFIG.log.level) then
            vim.notify(
                string.format(fmt, ...),
                lv
            )
        end
    end
end
____exports.debug = factory("DEBUG")
____exports.info = factory("INFO")
____exports.warn = factory("WARN")
____exports.error = factory("ERROR")
return ____exports
