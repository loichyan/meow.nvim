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

## 📋 Requirements

- [Neovim](https://github.com/neovim/neovim) >= **0.11**
- [mini.nvim](https://github.com/echasnovski/mini.nvim) (may not work properly
  with partial modules)

## ⚙️ Configuration

### Setup

Call `require('meow').setup(<MeoOptions>)` to initialize the plugin. For all
supported options, refer to [options.lua](lua/meow/options.lua).

### Plugin spec

meow.nvim supports only a subset of lazy.nvim's plugin specification, along with
some fields defined in mini.deps. For the complete list of supported properties,
refer to [spec.lua](lua/meow/spec.lua).

### Shadow plugins

Shadow plugins are the core feature of this plugin compared to lazy.nvim. They
primarily address the issue described in
[folke/lazy.nvim#1610](https://github.com/folke/lazy.nvim/issues/1610). A shadow
plugin does not have a source on the disk and can therefore be considered a
configuration-only plugin. Apart from this, it is almost identical to normal
plugins—you can supply a `config` function, set lazy-loading events, specify
additional dependencies, and so on. This feature is designed to work with
mini.nvim: install the entire plugin and then load different modules as needed.

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
