---@class MeoKeySpec
---@field [1] string - lhs
---@field [2] string|fun() - rhs
---@field mode? string|string[]
---@field buffer? integer
---@field desc? string
---@field expr? boolean
---@field noremap? boolean
---@field nowait? boolean
---@field remap? boolean
---@field silent? boolean

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
    for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
        local dir = rtp .. "/lua/" .. rootdir
        if vim.uv.fs_stat(dir .. ".lua") then
            cb(root, dir .. ".lua")
        end
        Utils.scan_dirmods(dir, false, function(mod, path)
            if mod == "init" then
                cb(root, path)
            else
                cb(root .. "." .. mod, path)
            end
        end)
    end
end

---Finds all available Lua modules in the given directory.
---
---It accepts a callback function that takes the name and path of a module.
---@param dir string
---@param allow_empty boolean whether to return empty directory modules
---@param cb fun(mod:string,path:string)
function Utils.scan_dirmods(dir, allow_empty, cb)
    local f = vim.uv.fs_scandir(dir)
    if not f then
        return
    end
    while true do
        local name, type = vim.uv.fs_scandir_next(f)
        if not name then
            break
        end
        ---@type string?
        local path = dir .. "/" .. name

        if name:find(".+%.lua$") then
            name = name:sub(1, -5)
        elseif type == "directory" and (allow_empty or vim.uv.fs_stat(path .. "/init.lua")) then
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

---Sets Neovim keymaps using delcarative key tables.
---@overload fun(specs:MeoKeySpec[])
---@overload fun(bufnr:integer,specs:MeoKeySpec[])
function Utils.keyset(bufnr, specs)
    if specs == nil then
        specs = bufnr
        bufnr = nil
    end
    ---@cast bufnr integer?
    ---@cast specs MeoKeySpec[]

    for _, spec in ipairs(specs) do
        local opts = vim.tbl_extend("keep", spec, { buffer = bufnr })
        local lhs, rhs, mode = opts[1], opts[2], opts.mode
        opts[1], opts[2], opts.mode = nil, nil, nil
        mode = mode or "n"
        vim.keymap.set(mode, lhs, rhs, opts)
    end
end

return Utils
