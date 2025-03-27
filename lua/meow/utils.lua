---@class MeoUtils
local Utils = {}

---Traverses all direct submodules under the given module, including the root
---module if it exists.
---
---It accepts a callback function that takes the name and path of a module.
---@param root string
---@param cb fun(mod:string,path:string)
function Utils.scan_submods(root, cb)
    local rootdir = string.gsub(root, "%.", "/")
    local rootpath
    for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
        local dir = rtp .. "/lua/" .. rootdir
        if vim.uv.fs_stat(dir .. ".lua") then
            rootpath = dir .. ".lua"
            cb(root, rootpath)
        end
        Utils.scan_dirmods(dir, function(mod, path)
            if mod ~= "init" then
                cb(root .. "." .. mod, path)
            elseif not rootpath then
                rootpath = path
                cb(root, rootpath)
            end
        end)
    end
end

---Finds all available Lua modules in the given directory.
---
---It accepts a callback function that takes the name and path of a module.
---@param dir string
---@param cb fun(mod:string,path:string)
function Utils.scan_dirmods(dir, cb)
    local f = vim.uv.fs_scandir(dir)
    if not f then
        return
    end
    while true do
        local name, type = vim.uv.fs_scandir_next(f)
        if not name then
            break
        end
        local path = dir .. "/" .. name ---@type string?

        if name:find(".+%.lua$") then
            name = name:sub(1, -5)
        elseif type == "directory" and vim.uv.fs_stat(path .. "/init.lua") then
            path = path .. "/init.lua"
        else
            path = nil
        end

        if path then
            cb(name, path)
        end
    end
end

---Parses the spec name and possible source URI from the given string.
---@param str string
---@return string,string?
function Utils.parse_plugin_name(str)
    local basename = string.match(str, ".*/(.*)")
    if not basename then
        return str, nil
    else
        return basename, str
    end
end

return Utils
