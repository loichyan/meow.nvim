--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
function ____exports.join_path(...)
    local paths = {...}
    return table.concat(paths, "/")
end
function ____exports.deep_merge(force, tbl1, ...)
    local tbls = {...}
    for _, tbl2 in ipairs(tbls) do
        for k, v2 in pairs(tbl2) do
            local v1 = tbl1[k]
            if type(v1) == "table" and type(v2) == "table" then
                ____exports.deep_merge(force, v1, v2)
            elseif force then
                tbl1[k] = v2
            elseif not v1 then
                tbl1[k] = v2
            end
        end
    end
    return tbl1
end
function ____exports.merge_sort(list, cmp)
    local len = #list
    local tmp = {}
    do
        local seg = 1
        while seg < len do
            do
                local start = 0
                while start < len do
                    local start1 = start
                    local end1 = math.min(start + seg, len)
                    local start2 = end1
                    local end2 = math.min(start + seg * 2, len)
                    while start1 < end1 and start2 < end2 do
                        local ____table_insert_6 = table.insert
                        local ____tmp_5 = tmp
                        local ____temp_4
                        if cmp(list[start1 + 1], list[start2 + 1]) <= 0 then
                            local ____list_1 = list
                            local ____start1_0 = start1
                            start1 = ____start1_0 + 1
                            ____temp_4 = ____list_1[____start1_0 + 1]
                        else
                            local ____list_3 = list
                            local ____start2_2 = start2
                            start2 = ____start2_2 + 1
                            ____temp_4 = ____list_3[____start2_2 + 1]
                        end
                        ____table_insert_6(____tmp_5, ____temp_4)
                    end
                    while start1 < end1 do
                        local ____table_insert_10 = table.insert
                        local ____tmp_9 = tmp
                        local ____list_8 = list
                        local ____start1_7 = start1
                        start1 = ____start1_7 + 1
                        ____table_insert_10(____tmp_9, ____list_8[____start1_7 + 1])
                    end
                    while start2 < end2 do
                        local ____table_insert_14 = table.insert
                        local ____tmp_13 = tmp
                        local ____list_12 = list
                        local ____start2_11 = start2
                        start2 = ____start2_11 + 1
                        ____table_insert_14(____tmp_13, ____list_12[____start2_11 + 1])
                    end
                    start = start + seg * 2
                end
            end
            list = tmp
            tmp = {}
            seg = seg + seg
        end
    end
    return list
end
return ____exports
