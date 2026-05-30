---@class MeoKeySpec: vim.keymap.set.Opts
---@field [1] string - lhs
---@field [2] string|(fun():string|nil) - rhs
---@field mode? string|string[]

---@class MeoAutocmdSpec: vim.api.keyset.create_autocmd
---@field event string|string[]
---@field debonce? integer -- ms to debounce callbacks

---@class MeoUtils
local Utils = {}
local H = {}

---@param cb fun()
function Utils.later(cb)
  if H.scheduled_later == nil then
    H.scheduled_later = {}
    vim.schedule(H.execute_later)
  end
  local trace = debug.traceback('', 2)
  table.insert(H.scheduled_later, { cb, trace })
end

---Display a notification.
---@param level 'TRACE'|'DEBUG'|'INFO'|'WARN'|'ERROR'
---@param msg string
function Utils.notify(level, msg)
  if H.pending_notif == nil and vim.v.vim_did_enter == 0 then
    H.pending_notif = {}
    vim.api.nvim_create_autocmd('UIEnter', {
      desc = 'Fire pending notifications',
      once = true,
      callback = function()
        for _, notif in ipairs(H.pending_notif) do
          vim.notify(unpack(notif))
        end
        H.pending_notif = false
      end,
    })
  end

  if H.pending_notif then
    table.insert(H.pending_notif, { msg, vim.log.levels[level] })
  else
    vim.notify(msg, vim.log.levels[level])
  end
end

---Display a notification with `string.format`.
---@param level 'TRACE'|'DEBUG'|'INFO'|'WARN'|'ERROR'
---@param msg string
function Utils.notifyf(level, msg, ...) Utils.notify(level, string.format(msg, ...)) end

---Traverses all direct submodules under the given module, including the root
---module if it exists.
---
---It accepts a callback that takes as arguments the name and path of a module.
---@param root string
---@param cb fun(mod:string,path:string)
function Utils.scan_submods(root, cb)
  local rootdir = string.gsub(root, '%.', '/')
  for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
    local dir = rtp .. '/lua/' .. rootdir
    if vim.uv.fs_stat(dir .. '.lua') then cb(root, dir .. '.lua') end
    Utils.scan_dirmods(dir, false, function(mod, path)
      if mod == 'init' then
        cb(root, path)
      else
        cb(root .. '.' .. mod, path)
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
    local path = dir .. '/' .. name

    if name:find('.+%.lua$') then
      name = name:sub(1, -5)
    elseif type == 'directory' and (allow_empty or vim.uv.fs_stat(path .. '/init.lua')) then
      path = path .. '/init.lua'
    else
      path = nil
    end

    if path then cb(name, path) end
  end
end

---Sets Neovim keymaps using declarative key tables.
---@overload fun(specs:MeoKeySpec[])
---@overload fun(bufnr:integer,specs:MeoKeySpec[])
function Utils.keymap(bufnr, specs)
  if specs == nil then
    specs = bufnr
    bufnr = nil
  end
  ---@cast bufnr integer?
  ---@cast specs MeoKeySpec[]

  local map = vim.keymap.set
  for _, spec in ipairs(specs) do
    local opts = vim.tbl_extend('keep', spec, { buffer = bufnr })
    local lhs, rhs, mode = opts[1], opts[2], opts.mode
    opts[1], opts[2], opts.mode = nil, nil, nil
    mode = mode or 'n'
    map(mode, lhs, rhs, opts)
  end
end

---Creates Neovim autocmds using declarative tables.
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

  local au = vim.api.nvim_create_autocmd
  for _, spec in ipairs(specs) do
    local opts = vim.tbl_extend('keep', spec, { group = group })
    local event = opts.event
    if opts.debounce and opts.callback then
      opts.callback = Utils.debounce(opts.debounce, opts.callback)
    end
    opts.event, opts.debounce = nil, nil
    au(event, opts)
  end
end

---Debounces the given function.
---@param ms integer
---@param f fun(...)
Utils.debounce = function(ms, f)
  local timer = vim.uv.new_timer() ---@cast timer -nil
  return function(...)
    timer:stop()
    local args = { ... }
    timer:start(ms, 0, function() f(unpack(args)) end)
  end
end

---Adapted from <https://github.com/nvim-mini/mini.nvim/blob/9d0b9b7188d5c24b5a87f0d8b383ec8bda7a0de4/lua/mini/misc.lua#L378>.
H.execute_later = function()
  local timer = assert(vim.loop.new_timer())
  local f
  f = vim.schedule_wrap(function()
    local later = H.scheduled_later[1]
    if later == nil then
      if not timer:is_closing() then timer:close() end
      H.scheduled_later = nil
      return
    end
    table.remove(H.scheduled_later, 1)

    local cb, trace = later[1], later[2]
    local ok, err = pcall(cb)
    if not ok then
      Utils.notifyf('ERROR', 'failed to execute later function: %s\n%s', err, trace)
    end
    timer:start(1, 0, f)
  end)
  -- Space out "later" executions to be sure that they don't block anything
  timer:start(1, 0, f)
end

return Utils
