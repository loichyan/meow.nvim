--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local ____utils = require("spark.utils")
local merge_sort = ____utils.merge_sort
function ____exports.resolve_after(specs)
    local nodes = {}
    for _, spec in ipairs(specs) do
        nodes[spec[1]] = {[1] = spec, visited = false, resolved = false}
    end
    local resolved = {}
    local function visit(spec)
        local name = spec[1]
        local node = nodes[name]
        if node.resolved then
            return spec.__state, nil
        end
        if node.visited then
            return nil, string.format("circular 'after' reference in '%s'", name)
        end
        node.visited = true
        local to_load = true
        for _, ref_name in ipairs(spec.after) do
            local ref_node = nodes[ref_name]
            if ref_node == nil then
                return nil, string.format("undefined 'after' reference '%s' in '%s'", ref_name, name)
            end
            local state, err = visit(ref_node[1])
            if state == nil then
                return nil, err
            elseif state ~= "LOAD" and state ~= "AFTER_LOAD" and state ~= "LOADED" then
                to_load = false
            end
        end
        if not to_load then
            spec.__state = "NONE"
        end
        node.resolved = true
        table.insert(resolved, spec)
        return spec.__state, nil
    end
    for _, spec in ipairs(specs) do
        local state, err = visit(spec)
        if state == nil then
            return nil, err
        end
    end
    return resolved, nil
end
function ____exports.resolve(specs)
    table.sort(
        specs,
        function(a, b) return a[1] < b[1] end
    )
    specs = merge_sort(
        specs,
        function(a, b) return a.priority - b.priority end
    )
    return ____exports.resolve_after(specs)
end
return ____exports
