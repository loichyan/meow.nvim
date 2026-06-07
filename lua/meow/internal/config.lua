---@type MeoOptions
return {
  concurrency = 10,
  import_cache = nil,
  event_aliases = {},
  process_spec = function(spec)
    if spec.name == 'mini.nvim' then
      spec.lazy = false
    elseif vim.startswith(spec.name, 'mini.') then
      spec.shadow = vim.F.if_nil(spec.shadow, true)
      spec.module = vim.F.if_nil(spec.module, { spec.name })
    end
    return spec
  end,
}
