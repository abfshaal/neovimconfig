return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        replace_netrw = false,
      },
    },
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "moon",
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
      },
      on_highlights = function(hl, c)
        -- Ensure tree-sitter highlights are visible
        hl["@variable"] = { fg = c.fg }
        hl["@variable.builtin"] = { fg = c.red }
        hl["@variable.parameter"] = { fg = c.orange }
        hl["@variable.member"] = { fg = c.green1 }
        hl["@function"] = { fg = c.blue }
        hl["@function.builtin"] = { fg = c.cyan }
        hl["@function.call"] = { fg = c.blue }
        hl["@function.method"] = { fg = c.blue }
        hl["@function.method.call"] = { fg = c.blue }
        hl["@keyword"] = { fg = c.purple }
        hl["@keyword.function"] = { fg = c.magenta }
        hl["@keyword.return"] = { fg = c.magenta }
        hl["@string"] = { fg = c.green }
        hl["@number"] = { fg = c.orange }
        hl["@boolean"] = { fg = c.orange }
        hl["@constant"] = { fg = c.orange }
        hl["@constant.builtin"] = { fg = c.orange }
        hl["@type"] = { fg = c.blue1 }
        hl["@type.builtin"] = { fg = c.cyan }
        hl["@operator"] = { fg = c.blue5 }
        hl["@punctuation.bracket"] = { fg = c.fg_dark }
        hl["@punctuation.delimiter"] = { fg = c.blue5 }
        hl["@constructor"] = { fg = c.blue1 }
        hl["@comment"] = { fg = c.comment, italic = true }
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd([[colorscheme tokyonight-moon]])
    end,
  },
}
