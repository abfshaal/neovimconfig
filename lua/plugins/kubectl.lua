return {
  "Ramilito/kubectl.nvim",
  version = "2.*",
  dependencies = { "saghen/blink.download" },
  opts = {},
  cmd = { "Kubectl", "Kubectx", "Kubens" },
  keys = {
    -- <C-e> as kubectl leader (overrides harpoon menu)
    { "<C-e>q", '<cmd>lua require("kubectl").toggle()<cr>', desc = "Kubectl: Toggle" },
    { "<C-e>Q", '<cmd>lua require("kubectl").toggle({ tab = true })<cr>', desc = "Kubectl: Toggle (tab)" },

    -- Views
    { "<C-e>p", "<Plug>(kubectl.view_pods)", ft = "k8s_*", desc = "Kubectl: Pods" },
    { "<C-e>d", "<Plug>(kubectl.view_deployments)", ft = "k8s_*", desc = "Kubectl: Deployments" },
    { "<C-e>s", "<Plug>(kubectl.view_services)", ft = "k8s_*", desc = "Kubectl: Services" },
    { "<C-e>i", "<Plug>(kubectl.view_ingresses)", ft = "k8s_*", desc = "Kubectl: Ingresses" },
    { "<C-e>c", "<Plug>(kubectl.view_configmaps)", ft = "k8s_*", desc = "Kubectl: ConfigMaps" },
    { "<C-e>S", "<Plug>(kubectl.view_secrets)", ft = "k8s_*", desc = "Kubectl: Secrets" },
    { "<C-e>n", "<Plug>(kubectl.view_nodes)", ft = "k8s_*", desc = "Kubectl: Nodes" },
    { "<C-e>o", "<Plug>(kubectl.view_overview)", ft = "k8s_*", desc = "Kubectl: Overview" },
    { "<C-e>j", "<Plug>(kubectl.view_cronjobs)", ft = "k8s_*", desc = "Kubectl: CronJobs" },
    { "<C-e>t", "<Plug>(kubectl.view_top)", ft = "k8s_*", desc = "Kubectl: Top" },

    -- Context/Namespace
    { "<C-e>x", "<Plug>(kubectl.contexts_view)", ft = "k8s_*", desc = "Kubectl: Contexts" },
    { "<C-e>N", "<Plug>(kubectl.namespace_view)", ft = "k8s_*", desc = "Kubectl: Namespaces" },
    { "<C-e>f", "<Plug>(kubectl.picker_view)", ft = "k8s_*", desc = "Kubectl: Picker" },
  },
}
