return {
  "smoka7/hop.nvim",
  version = "*",
  opts = {
    keys = "etovxdygfblhckisurn",
  },
  keys = {
    -- Basic motions
    { "<leader>hS", "<cmd>HopChar2<cr>", desc = "Hop to bigram" },
    { "s", "<cmd>HopWord<cr>", desc = "Hop to word" },
    { "<leader>hc", "<cmd>HopCamelCase<cr>", desc = "Hop to camelCase" },
    { "<leader>hl", "<cmd>HopLine<cr>", desc = "Hop to line" },
    { "<leader>hL", "<cmd>HopLineStart<cr>", desc = "Hop to line start" },
    { "<leader>ha", "<cmd>HopAnywhere<cr>", desc = "Hop anywhere" },
    { "<leader>hs", "<cmd>HopPattern<cr>", desc = "Hop to pattern" },

    -- Directional motions
    { "<leader>hj", "<cmd>HopWordAC<cr>", desc = "Hop word after cursor" },
    { "<leader>hk", "<cmd>HopWordBC<cr>", desc = "Hop word before cursor" },

    -- Current line
    { "<leader>h/", "<cmd>HopWordCurrentLine<cr>", desc = "Hop word in line" },

    -- Treesitter nodes
    { "<leader>hn", "<cmd>HopNodes<cr>", desc = "Hop to nodes" },

    -- Yank and paste
    { "<leader>hy", "<cmd>HopYankChar1<cr>", desc = "Hop yank" },
    { "<leader>hP", "<cmd>HopPaste<cr>", desc = "Hop paste" },

    -- <C-f> prefix variants
    { "<C-f>hS", "<cmd>HopChar2<cr>", desc = "Hop to bigram (C-f)" },
    { "<C-f>hc", "<cmd>HopCamelCase<cr>", desc = "Hop to camelCase (C-f)" },
    { "<C-f>hl", "<cmd>HopLine<cr>", desc = "Hop to line (C-f)" },
    { "<C-f>hL", "<cmd>HopLineStart<cr>", desc = "Hop to line start (C-f)" },
    { "<C-f>ha", "<cmd>HopAnywhere<cr>", desc = "Hop anywhere (C-f)" },
    { "<C-f>hs", "<cmd>HopPattern<cr>", desc = "Hop to pattern (C-f)" },
    { "<C-f>hj", "<cmd>HopWordAC<cr>", desc = "Hop word after cursor (C-f)" },
    { "<C-f>hk", "<cmd>HopWordBC<cr>", desc = "Hop word before cursor (C-f)" },
    { "<C-f>h/", "<cmd>HopWordCurrentLine<cr>", desc = "Hop word in line (C-f)" },
    { "<C-f>hn", "<cmd>HopNodes<cr>", desc = "Hop to nodes (C-f)" },
    { "<C-f>hy", "<cmd>HopYankChar1<cr>", desc = "Hop yank (C-f)" },
    { "<C-f>hP", "<cmd>HopPaste<cr>", desc = "Hop paste (C-f)" },
  },
}
