local M = {}

local Config = require("docklog.config")

---@param opts? table
function M.setup(opts)
  Config.setup(opts)

  -- Register global keymaps
  local km = Config.values.keymaps
  local prefix = km.prefix

  vim.keymap.set("n", prefix .. km.docker, "<cmd>DocklogDocker<cr>",
    { silent = true, desc = "Docklog: Docker containers" })
  vim.keymap.set("n", prefix .. km.pods, "<cmd>DocklogKube<cr>",
    { silent = true, desc = "Docklog: K8s pods" })
  vim.keymap.set("n", prefix .. km.namespace, "<cmd>DocklogKubeNs<cr>",
    { silent = true, desc = "Docklog: K8s namespace picker" })
end

return M
