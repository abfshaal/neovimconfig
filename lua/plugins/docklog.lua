return {
  {
    "local/docklog.nvim",
    dir = vim.fn.stdpath("config"),
    name = "docklog.nvim",
    lazy = false,
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("docklog").setup({})
    end,
  },
}
