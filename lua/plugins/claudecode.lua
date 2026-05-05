local claudecode_dir = vim.fs.normalize(vim.fn.stdpath("config") .. "/opencode/claudecode.nvim")

return {
  "coder/claudecode.nvim",
  dir = claudecode_dir,
  name = "claudecode.nvim",
  dev = true,
  dependencies = { "folke/snacks.nvim" },
  opts = {
    -- Server Configuration
    port_range = { min = 10000, max = 65535 },
    auto_start = true,
    log_level = "debug", -- Options: "trace", "debug", "info", "warn", "error"
    max_retries = 3, -- NEW: Testing edit feature
    terminal_cmd = nil, -- Custom terminal command (default: "claude")
    -- For local installations: "~/.claude/local/claude"
    -- For native binary: use output from 'which claude'

    -- Send/Focus Behavior
    -- When true, successful sends will focus the Claude terminal if already connected
    focus_after_send = true,

    -- Selection Tracking
    track_selection = true,
    visual_demotion_delay_ms = 50,

    -- Terminal Configuration
    terminal = {
      split_side = "right", -- "left" or "right"
      split_width_percentage = 0.30,
      provider = "auto", -- "auto", "snacks", "native", "external", "none", or custom provider table
      auto_close = true,
      snacks_win_opts = {}, -- Opts to pass to `Snacks.terminal.open()` - see Floating Window section below

      -- Provider-specific options
      provider_opts = {
        -- Command for external terminal provider. Can be:
        -- 1. String with %s placeholder: "alacritty -e %s" (backward compatible)
        -- 2. String with two %s placeholders: "alacritty --working-directory %s -e %s" (cwd, command)
        -- 3. Function returning command: function(cmd, env) return "alacritty -e " .. cmd end
        external_terminal_cmd = nil,
      },
    },

    -- Diff Integration
    diff_opts = {
      floating = true,
      auto_close_on_accept = true,
      open_in_current_tab = true,
      keep_terminal_focus = true, -- If true, moves focus back to terminal after diff opens
      test_diff_feature = true, -- Testing the diff feature
    },
  },
  keys = {
    { "<C-a>c", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<C-a>f", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<C-a>r", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<C-a>C", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<C-a>m", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<C-a>b", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<C-a>s", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    {
      "<C-a>a",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
    },
    -- Diff management
    { "<C-a>y", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<C-a>n", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    { "<C-a>h", "<cmd>ClaudeCodeDiffHide<cr>", desc = "Hide Claude diff" },
    { "<C-a>t", "<cmd>ClaudeCodeDiffShow<cr>", desc = "Show Claude diff" },
  },
}
