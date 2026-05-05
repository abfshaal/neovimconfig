return {
  "ThePrimeagen/99",
  config = function()
    local _99 = require("99")
    _99.setup({
      provider = _99.OpenCodeProvider,
      model = "gpt-5.3-codex",
    })

    vim.keymap.set("v", "<leader>9v", function()
      _99.visual()
    end, { desc = "99: AI visual request" })

    vim.keymap.set("v", "<leader>9s", function()
      _99.stop_all_requests()
    end, { desc = "99: Stop all requests" })

    -- <C-f> prefix variants
    vim.keymap.set("v", "<C-f>9v", function()
      _99.visual()
    end, { desc = "99: AI visual request (C-f)" })
    vim.keymap.set("v", "<C-f>9s", function()
      _99.stop_all_requests()
    end, { desc = "99: Stop all requests (C-f)" })
  end,
}
