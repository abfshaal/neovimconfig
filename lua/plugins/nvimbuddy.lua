-- ~/.config/nvim/lua/plugins/navbuddy.lua
return {
  -- Breadcrumbs (navic) – Navbuddy uses this
  {
    "SmiteshP/nvim-navic",
    opts = {
      highlight = true,
      lsp = { auto_attach = true }, -- attach navic automatically when LSP attaches
    },
  },

  -- Navbuddy UI
  {
    "SmiteshP/nvim-navbuddy",
    dependencies = {
      "neovim/nvim-lspconfig",
      "SmiteshP/nvim-navic",
      "MunifTanjim/nui.nvim",
      -- Optional deps:
      "nvim-telescope/telescope.nvim",
      -- "numToStr/Comment.nvim",
    },
    keys = {
      {
        "<leader>vn",
        function()
          require("nvim-navbuddy").open()
        end,
        desc = "Code Navigator (Navbuddy)",
      },
      {
        "<leader>vN",
        function()
          require("nvim-navbuddy").open(require("nvim-navbuddy").api).parents()
        end,
        desc = "Navbuddy: Parents",
      },

      -- <C-f> prefix variants
      {
        "<C-f>vn",
        function()
          require("nvim-navbuddy").open()
        end,
        desc = "Code Navigator (C-f)",
      },
      {
        "<C-f>vN",
        function()
          require("nvim-navbuddy").open(require("nvim-navbuddy").api).parents()
        end,
        desc = "Navbuddy: Parents (C-f)",
      },
    },
    opts = {
      window = { border = "rounded" },
      lsp = {
        auto_attach = true, -- auto-attach to any LSP buffer
        preference = nil, -- or e.g. { "tsserver", "pyright" }
      },
      source_buffer = {
        follow_node = true,
        highlight = true,
      },
      use_default_mappings = true, -- Navbuddy’s built-ins (hjkl, Enter, etc.)
    },
  },
}
