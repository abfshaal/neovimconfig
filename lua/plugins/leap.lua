return {
  "ggandor/leap.nvim",
  dependencies = { "tpope/vim-repeat" },
  keys = {
    -- Basic leap motions
    { "S", "<Plug>(leap)", mode = { "n", "x", "o" }, desc = "Leap forward" },
    { "<leader>lS", "<Plug>(leap-from-window)", mode = "n", desc = "Leap across windows" },

    -- Remote operations
    {
      "<leader>lr",
      function()
        require("leap.remote").action()
      end,
      mode = { "n", "o" },
      desc = "Leap remote action",
    },

    -- Treesitter selection
    {
      "<leader>lt",
      function()
        require("leap.treesitter").select()
      end,
      mode = { "x", "o" },
      desc = "Leap treesitter select",
    },

    -- <C-f> prefix variants
    { "<C-f>lS", "<Plug>(leap-from-window)", mode = "n", desc = "Leap across windows (C-f)" },
    {
      "<C-f>lr",
      function()
        require("leap.remote").action()
      end,
      mode = { "n", "o" },
      desc = "Leap remote action (C-f)",
    },
    {
      "<C-f>lt",
      function()
        require("leap.treesitter").select()
      end,
      mode = { "x", "o" },
      desc = "Leap treesitter select (C-f)",
    },
  },
}
