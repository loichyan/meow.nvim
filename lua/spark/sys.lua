--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local uv
local log = require("spark.log")
local ____utils = require("spark.utils")
local join_path = ____utils.join_path
function ____exports.scandir(path)
    local fs, err = uv.fs_scandir(path)
    if not fs then
        log.error(err)
        return function()
        end
    end
    local function iter(fs)
        local name, ____type = uv.fs_scandir_next(fs)
        if not name then
            if ____type ~= nil then
                log.error(____type)
            end
            return
        end
        return name, ____type
    end
    return iter, fs
end
function ____exports.remove_dir(path)
    for name, ____type in ____exports.scandir(path) do
        if ____type == "directory" then
            if not ____exports.remove_dir(join_path(path, name)) then
                return false
            end
        else
            if not ____exports.remove_file(join_path(path, name)) then
                return false
            end
        end
    end
    local ok, err = uv.fs_rmdir(path)
    if not ok then
        log.error(err)
        return false
    end
    return true
end
function ____exports.remove_file(path)
    local ok, err = uv.fs_unlink(path)
    if not ok then
        log.error(err)
        return false
    end
    return true
end
uv = vim.loop
function ____exports.remove(path)
    local stat, err = uv.fs_lstat(path)
    if not stat then
        log.error(err)
        return false
    end
    if stat.type == "directory" then
        return ____exports.remove_dir(path)
    end
    return ____exports.remove_file(path)
end
function ____exports.rename(path, newpath)
    local ok, err = uv.fs_rename(path, newpath)
    if not ok then
        log.error(err)
        return false
    end
    return true
end
return ____exports
