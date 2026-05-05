return {
  "jpalardy/vim-slime",
  config = function()
    vim.g.slime_target = "neovim"
    vim.g.slime_neovim_ignore_unlisted = 1
    vim.g.slime_python_ipython = 1

    -- Cell utilities
    local function create_cell_above()
      vim.api.nvim_put({ "# %%", "" }, "l", false, true)
      vim.cmd("normal! k")
    end

    local function create_cell_below()
      vim.api.nvim_put({ "", "# %%" }, "l", true, true)
      vim.cmd("normal! j")
    end

    local function go_to_next_cell()
      vim.cmd("silent! /^# %%")
      vim.cmd("nohlsearch")
    end

    local function go_to_prev_cell()
      vim.cmd("silent! ?^# %%")
      vim.cmd("nohlsearch")
    end

    -- Set up keymaps
    vim.keymap.set("n", "<leader>cA", create_cell_above, { desc = "Create cell above", buffer = true })
    vim.keymap.set("n", "<leader>cb", create_cell_below, { desc = "Create cell below", buffer = true })
    vim.keymap.set("n", "]j", go_to_next_cell, { desc = "Go to next cell", buffer = true })
    vim.keymap.set("n", "[j", go_to_prev_cell, { desc = "Go to previous cell", buffer = true })

    -- <C-f> prefix variants
    vim.keymap.set("n", "<C-f>cA", create_cell_above, { desc = "Create cell above (C-f)", buffer = true })
    vim.keymap.set("n", "<C-f>cb", create_cell_below, { desc = "Create cell below (C-f)", buffer = true })
  end,
  ft = { "python" },
  keys = {
    { "<C-c><C-c>", "<Plug>SlimeSendCell", mode = { "n", "v" }, desc = "Send code to REPL" },
    { "<C-c>v", "<Plug>SlimeConfig", desc = "Configure REPL target" },
  },
}

