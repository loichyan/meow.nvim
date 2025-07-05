---@meta

---@class MeoOptions
---Root spec(s) to load. Imports of other modules are usually specified here.
---@field specs? MeoSpecs
---Perform a few patches on MiniDeps so that all enabled plugins can be
---recognized correctly during updating or cleaning.
---@field patch_mini? boolean
---Whether to enable automatic snapshot generation. The default set to false.
---@field enable_snapshot? boolean
