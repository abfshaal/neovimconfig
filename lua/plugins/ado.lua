return {
  {
    "local/ado.nvim",
    dir = vim.fn.stdpath("config"),
    name = "ado.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- Optional, used when available
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("ado").setup({})
    end,
    keys = {
      { "<leader>ad", "<cmd>Ado<cr>", desc = "Azure DevOps" },
      { "<leader>ap", "<cmd>AdoPrs<cr>", desc = "ADO PRs" },
      { "<leader>aw", "<cmd>AdoMyWork<cr>", desc = "ADO My Work" },
      { "<leader>as", "<cmd>AdoSprints<cr>", desc = "ADO Sprints" },
      { "<leader>ab", "<cmd>AdoBacklogs<cr>", desc = "ADO Backlogs" },

      -- <C-f> prefix variants
      { "<C-f>ad", "<cmd>Ado<cr>", desc = "Azure DevOps (C-f)" },
      { "<C-f>ap", "<cmd>AdoPrs<cr>", desc = "ADO PRs (C-f)" },
      { "<C-f>aw", "<cmd>AdoMyWork<cr>", desc = "ADO My Work (C-f)" },
      { "<C-f>as", "<cmd>AdoSprints<cr>", desc = "ADO Sprints (C-f)" },
      { "<C-f>ab", "<cmd>AdoBacklogs<cr>", desc = "ADO Backlogs (C-f)" },
    },
  },
}
