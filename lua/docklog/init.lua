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
  vim.keymap.set("n", prefix .. km.compose, "<cmd>DocklogCompose<cr>",
    { silent = true, desc = "Docklog: Docker Compose services" })
  vim.keymap.set("n", prefix .. km.deployments, "<cmd>DocklogKubeDeploy<cr>",
    { silent = true, desc = "Docklog: K8s deployments" })
  vim.keymap.set("n", prefix .. km.label, "<cmd>DocklogKubeLabel<cr>",
    { silent = true, desc = "Docklog: K8s pods by label" })
  vim.keymap.set("n", prefix .. km.sessions, "<cmd>DocklogSessions<cr>",
    { silent = true, desc = "Docklog: active sessions picker" })

  -- Standalone shortcut (no prefix) for fast access
  vim.keymap.set("n", "<C-,>", "<cmd>DocklogSessions<cr>",
    { silent = true, desc = "Docklog: active sessions picker" })
end

return M
