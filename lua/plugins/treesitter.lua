-- Test comment added by Claude to verify edit permissions
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    version = false,
    build = function()
      local TS = require("nvim-treesitter")
      if not TS.get_installed then
        LazyVim.error("Please restart Neovim and run `:TSUpdate` to use the `nvim-treesitter` **main** branch.")
        return
      end
      LazyVim.treesitter.ensure_treesitter_cli(function()
        TS.update(nil, { summary = true })
      end)
    end,
    lazy = vim.fn.argc(-1) == 0,
    event = { "LazyFile", "VeryLazy" },
    cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
    opts_extend = { "ensure_installed" },
    opts = {
      indent = { enable = true },
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
        disable = function(lang)
          -- Temporarily skip vimscript to avoid parser/query mismatch errors
          return lang == "vim"
        end,
      },
      folds = { enable = true },
      ensure_installed = {
        "bash",
        "c",
        "diff",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "jsonc",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "printf",
        "python",
        "query",
        "regex",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
      },
    },
    config = function(_, opts)
      local TS = require("nvim-treesitter")

      setmetatable(require("nvim-treesitter.install"), {
        __newindex = function(_, k)
          if k == "compilers" then
            vim.schedule(function()
              LazyVim.error({
                "Setting custom compilers for `nvim-treesitter` is no longer supported.",
                "",
                "For more info, see:",
                "- [compilers](https://docs.rs/cc/latest/cc/#compile-time-requirements)",
              })
            end)
          end
        end,
      })

      TS.setup(opts)

      local install = vim.tbl_filter(function(lang)
        return not LazyVim.treesitter.have(lang)
      end, opts.ensure_installed or {})

      if #install > 0 then
        LazyVim.treesitter.ensure_treesitter_cli(function()
          TS.install(install, { summary = true }):await(function()
            LazyVim.treesitter.get_installed(true)
          end)
        end)
      end
    end,
  },
}
