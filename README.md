# 🐱 meow.nvim

meow.nvim lets you manage plugins in the
[lazy](https://github.com/folke/lazy.nvim) way with
[mini.deps](https://github.com/echasnovski/mini.deps).

## 🚗 Quick start

Put the following snippet to `~/.config/nvim/init.lua`:

```lua
-- mini.nvim, at least mini.deps, is required before going on
local pack_path = vim.fn.stdpath("data") .. "/site/"
local mini_path = pack_path .. "pack/deps/start/mini.nvim"
if not vim.uv.fs_stat(mini_path) then
    vim.cmd('echo "Installing `mini.nvim`" | redraw')
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/echasnovski/mini.nvim",
        mini_path,
    })
    vim.cmd("packadd mini.nvim | helptags ALL")
    vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

-- Setup mini.deps
local deps = require("mini.deps")
deps.setup({ path = { package = pack_path } })
-- Let mini.deps install meow.nvim for you
deps.add("loichyan/meow.nvim")
-- Then setup meow.nvim
deps.now(function()
    require("meow").setup({
        -- Import all plugin specs under `$RTP/lua/my/plugins/`
        specs = { import = "my.plugins" },
        -- Tell mini.deps what plugins are managed by meow.nvim
        patch_mini = true,
    })
end)
```

After that, restart Neovim, and you're ready to go!

For a real-world example, check out
[Meowim](https://github.com/loichyan/Meowim).

## ⚙️ Configuration

`Meow.setup()` accepts a table of the following definition:

```lua
---@class MeoOptions
---Root spec(s) to load. Imports of other modules are usually specified here.
---@field specs? MeoSpecs
---Perform a few patches on MiniDeps so that all enabled plugins can be
---recognized correctly during updating or cleaning.
---@field patch_mini? boolean
---Whether to enable automatic snapshot generation. The default set to false.
---@field enable_snapshot? boolean
```

meow.nvim supports only a subset of lazy.nvim's plugin specification. For the
complete list of supported keys, refer to [spec.lua](lua/meow/spec.lua).

## 🎯 Goals

meow.nvim offers a declarative way to manage plugins, including lazy-loading,
which is similar to lazy.nvim. It does not support plugin installation or
cleanup, as those are handled by mini.deps. Additionally, meow.nvim mainly
focuses on helping you build your own Neovim development environment (aka PDE,
or [Personalized Development Environment](https://youtu.be/QMVIJhC9Veg)).
Therefore, it will not support the full
[`LazySpec`](https://lazy.folke.io/spec), which includes many features for
creating extendable IDE distributions.

## ⚖️ License

Licensed under GNU General Public License, Version 3.0 ([LICENSE](LICENSE) or
<https://www.gnu.org/licenses/gpl-3.0>).
