return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-python",
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-python")({
          -- Use pytest as the runner (supports unittest too)
          runner = "pytest",
          -- Use the Python from the current conda environment
          python = function()
            local conda_prefix = vim.env.CONDA_PREFIX
            if conda_prefix then
              return conda_prefix .. "/bin/python"
            end
            return "python3"
          end,
          -- Enable debugging with nvim-dap
          dap = { justMyCode = false },
          -- pytest arguments
          args = { "--log-level", "INFO", "-v" },
        }),
      },
      -- Configure output display
      output = {
        enabled = true,
        open_on_run = "short",
      },
      -- Configure quickfix list
      quickfix = {
        enabled = true,
        open = false,
      },
      -- Status signs
      status = {
        enabled = true,
        signs = true,
        virtual_text = true,
      },
      -- Icons for test status
      icons = {
        child_indent = "│",
        child_prefix = "├",
        collapsed = "─",
        expanded = "╮",
        failed = "✖",
        final_child_indent = " ",
        final_child_prefix = "╰",
        non_collapsible = "─",
        passed = "✓",
        running = "🗘",
        running_animated = { "/", "|", "\\", "-", "/", "|", "\\", "-" },
        skipped = "○",
        unknown = "?"
      },
    })

    -- Keymaps
    local neotest = require("neotest")
    
    -- Run tests
    vim.keymap.set("n", "<leader>tr", function() neotest.run.run() end, { desc = "Run nearest test" })
    vim.keymap.set("n", "<leader>tf", function() neotest.run.run(vim.fn.expand("%")) end, { desc = "Run current file tests" })
    vim.keymap.set("n", "<leader>td", function() neotest.run.run({strategy = "dap"}) end, { desc = "Debug nearest test" })
    vim.keymap.set("n", "<leader>ts", function() neotest.run.stop() end, { desc = "Stop test" })
    vim.keymap.set("n", "<leader>ta", function() neotest.run.attach() end, { desc = "Attach to test" })
    
    -- Test navigation
    vim.keymap.set("n", "]t", function() neotest.jump.next({ status = "failed" }) end, { desc = "Next failed test" })
    vim.keymap.set("n", "[t", function() neotest.jump.prev({ status = "failed" }) end, { desc = "Previous failed test" })
    
    -- Test output and summary
    vim.keymap.set("n", "<leader>to", function() neotest.output.open({ enter = true }) end, { desc = "Open test output" })
    vim.keymap.set("n", "<leader>tt", function() neotest.summary.toggle() end, { desc = "Toggle test summary" })
    vim.keymap.set("n", "<leader>tp", function() neotest.output_panel.toggle() end, { desc = "Toggle output panel" })

    -- <C-f> prefix variants
    vim.keymap.set("n", "<C-f>tr", function() neotest.run.run() end, { desc = "Run nearest test (C-f)" })
    vim.keymap.set("n", "<C-f>tf", function() neotest.run.run(vim.fn.expand("%")) end, { desc = "Run current file tests (C-f)" })
    vim.keymap.set("n", "<C-f>td", function() neotest.run.run({strategy = "dap"}) end, { desc = "Debug nearest test (C-f)" })
    vim.keymap.set("n", "<C-f>ts", function() neotest.run.stop() end, { desc = "Stop test (C-f)" })
    vim.keymap.set("n", "<C-f>ta", function() neotest.run.attach() end, { desc = "Attach to test (C-f)" })
    vim.keymap.set("n", "<C-f>to", function() neotest.output.open({ enter = true }) end, { desc = "Open test output (C-f)" })
    vim.keymap.set("n", "<C-f>tt", function() neotest.summary.toggle() end, { desc = "Toggle test summary (C-f)" })
    vim.keymap.set("n", "<C-f>tp", function() neotest.output_panel.toggle() end, { desc = "Toggle output panel (C-f)" })
  end,
}