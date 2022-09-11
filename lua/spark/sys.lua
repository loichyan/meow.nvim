local M = {}
local utils = require("spark.utils")
local log = require("spark.log")
local uv = vim.loop

---@param path string
---@return fun():string,string
function M.scandir(path)
  local fd, err = uv.fs_scandir(path)
  if fd == nil then
    log.error(err)
    return function() end
  end
  return function()
    while true do
      local name, type = uv.fs_scandir_next(fd)
      if name == nil then
        if type ~= nil then
          log.error(type)
        end
        return
      end
      return name, type
    end
  end
end

---@param path string
---@return boolean
function M.remove(path)
  local stat, err = uv.fs_lstat(path)
  if stat == nil then
    log.error(err)
    return false
  end
  if stat.type == "directory" then
    return M.remove_dir(path)
  else
    return M.remove_file(path)
  end
end

---@param path string
---@return boolean
function M.remove_file(path)
  local success, msg = uv.fs_unlink(path)
  if not success then
    log.error(msg)
    return false
  end
  return true
end

---@param path string
---@return boolean
function M.remove_dir(path)
  for name, type in M.scandir(path) do
    local new_path = utils.join_paths(path, name)
    if type == "directory" then
      if not M.remove_dir(new_path) then
        return false
      end
    else
      if not M.remove_file(new_path) then
        return false
      end
    end
  end
  local success, msg = uv.fs_rmdir(path)
  if not success then
    log.error(msg)
    return false
  end
  return true
end

---@param from string
---@param to string
---@return boolean
function M.rename(from, to)
  local success, msg = uv.fs_rename(from, to)
  if not success then
    log.error(msg)
    return false
  end
  return true
end

return M
