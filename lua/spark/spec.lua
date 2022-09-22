--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____utils = require("spark.utils")
local deep_merge = ____utils.deep_merge
local DEFAULT_SPEC = {
    [1] = "",
    from = "",
    start = false,
    disable = false,
    priority = 0,
    after = {},
    __state = "NONE",
    __path = ""
}
function ____exports.new_spec(spec)
    return deep_merge("keep", {__state = "NONE", __path = ""}, spec, DEFAULT_SPEC)
end
function ____exports.validate(orig)
    local spec2 = ____exports.new_spec(orig)
    local name = spec2[1]
    if name == "" then
        return nil, string.format(
            "plugin name must be specified for '%s'",
            vim.inspect(orig)
        )
    elseif string.sub(name, 1, 1) == "$" then
        spec2.__state = "POST_LOAD"
    else
        if spec2.from == "" then
            return nil, string.format("'from' is missed in '%s'", name)
        else
            spec2.from = "https://github.com/" .. spec2.from
        end
    end
    if spec2.start and spec2.disable then
        return nil, string.format("start plugin '%s' cannot be disabled", name)
    end
    return spec2, nil
end
return ____exports
