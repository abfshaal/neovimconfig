local M = {}

---@class docklog.K8sConfig
---@field namespace? string
---@field kubeconfig? string

---@class docklog.DockerConfig
---@field host? string

---@class docklog.UIConfig
---@field split_direction "below"|"right"
---@field split_size number
---@field tag_colors string[]

---@class docklog.KeymapConfig
---@field prefix string
---@field follow string
---@field keyword string
---@field level string
---@field clear string
---@field quit string
---@field add string
---@field docker string
---@field compose string
---@field pods string
---@field namespace string
---@field deployments string
---@field label string

---@class docklog.Config
---@field max_lines number
---@field default_provider "docker"|"kubernetes"
---@field tail_lines number
---@field k8s docklog.K8sConfig
---@field docker docklog.DockerConfig
---@field ui docklog.UIConfig
---@field keymaps docklog.KeymapConfig

---@type docklog.Config
M.values = {
  max_lines = 10000,
  default_provider = "docker",
  tail_lines = 100,

  k8s = {
    namespace = nil,
    kubeconfig = nil,
  },

  docker = {
    host = nil,
  },

  ui = {
    split_direction = "below",
    split_size = 15,
    tag_colors = {
      "DiagnosticInfo",
      "DiagnosticWarn",
      "DiagnosticError",
      "DiagnosticHint",
    },
  },

  keymaps = {
    prefix = "<C-f>l",
    follow = "f",
    keyword = "k",
    level = "l",
    clear = "c",
    quit = "q",
    add = "a",
    docker = "d",
    compose = "D",
    pods = "p",
    namespace = "n",
    deployments = "e",
    label = "L",
  },
}

---@param opts? table
function M.setup(opts)
  if opts then
    M.values = vim.tbl_deep_extend("force", M.values, opts)
  end
end

return M
