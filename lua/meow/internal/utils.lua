---@class MeoKeySpec: vim.keymap.set.Opts
---@field [1] string - lhs
---@field [2] string|(fun():string|nil) - rhs
---@field mode? string|string[]

---@class MeoAutocmdSpec: vim.api.keyset.create_autocmd
---@field event string|string[]

---@class MeoUtils
local Utils = {}

---Display a notification.
---@param level "TRACE"|"DEBUG"|"INFO"|"WARN"|"ERROR"
---@param msg string
function Utils.notify(level, msg) vim.notify(msg, vim.log.levels[level]) end

---Display a notification with `string.format`.
---@param level "TRACE"|"DEBUG"|"INFO"|"WARN"|"ERROR"
---@param msg string
function Utils.notifyf(level, msg, ...) vim.notify(string.format(msg, ...), vim.log.levels[level]) end

---Traverses all direct submodules under the given module, including the root
---module if it exists.
---
---It accepts a callback that takes as arguments the name and path of a module.
---@param root string
---@param cb fun(mod:string,path:string)
function Utils.scan_submods(root, cb)
  local rootdir = string.gsub(root, "%.", "/")
  for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
    local dir = rtp .. "/lua/" .. rootdir
    if vim.uv.fs_stat(dir .. ".lua") then cb(root, dir .. ".lua") end
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
---It accepts a callback that takes as arguments the name and path of a module.
---@param dir string
---@param allow_empty boolean whether to return empty directory modules
---@param cb fun(mod:string,path:string)
function Utils.scan_dirmods(dir, allow_empty, cb)
  local f = vim.uv.fs_scandir(dir)
  if not f then return end
  while true do
    local name, type = vim.uv.fs_scandir_next(f)
    if not name then break end
    ---@type string?
    local path = dir .. "/" .. name

    if name:find(".+%.lua$") then
      name = name:sub(1, -5)
    elseif type == "directory" and (allow_empty or vim.uv.fs_stat(path .. "/init.lua")) then
      path = path .. "/init.lua"
    else
      path = nil
    end

    if path then cb(name, path) end
  end
end

---@deprecated use `Utils.keymap` instead
function Utils.keyset(...)
  Utils.notify("WARN", "`Utils.keyset` is deprecated, use `Utils.keymap` instead")
  Utils.keymap(...)
end

---Sets Neovim keymaps using delcarative key tables.
---@overload fun(specs:MeoKeySpec[])
---@overload fun(bufnr:integer,specs:MeoKeySpec[])
function Utils.keymap(bufnr, specs)
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

---Creates Neovim autocmds using delcarative tables.
---@overload fun(specs:MeoAutocmdSpec[])
---@overload fun(group:string,specs:MeoAutocmdSpec[])
function Utils.autocmd(group, specs)
  if specs == nil then
    specs = group
    group = nil
  else
    ---@cast group string
    group = vim.api.nvim_create_augroup(group, { clear = true })
  end
  ---@cast specs MeoAutocmdSpec[]

  for _, spec in ipairs(specs) do
    local opts = vim.tbl_extend("keep", spec, { group = group })
    local event = opts.event
    opts.event = nil
    vim.api.nvim_create_autocmd(event, opts)
  end
end

return Utils
