return {
  "yetone/avante.nvim",
  build = vim.fn.has("win32") ~= 0 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
    or "make",
  event = "VeryLazy",
  version = false,
  keys = {
    { "<C-y>a", "<cmd>AvanteAsk<cr>", desc = "Avante: Ask", mode = { "n", "v" } },
    { "<C-y>c", "<cmd>AvanteChat<cr>", desc = "Avante: Chat", mode = { "n", "v" } },
    { "<C-y>e", "<cmd>AvanteEdit<cr>", desc = "Avante: Edit", mode = "v" },
    { "<C-y>r", "<cmd>AvanteRefresh<cr>", desc = "Avante: Refresh", mode = "n" },
    { "<C-y>t", "<cmd>AvanteToggle<cr>", desc = "Avante: Toggle", mode = "n" },
    { "<C-y>f", "<cmd>AvanteFocus<cr>", desc = "Avante: Focus", mode = "n" },
    { "<C-y>s", "<cmd>AvanteSwitchProvider<cr>", desc = "Avante: Switch Provider", mode = "n" },
  },
  opts = {
    -- use Claude Code via ACP
    provider = "claude-code",

    -- ✅ NOTE: no extra nesting here
    acp_providers = {
      ["claude-code"] = {
        command = "claude-code-acp",
        args = {},
        env = {
          NODE_NO_WARNINGS = "1",
          ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY"),
        },
      },
      -- you can add "gemini-cli" here too if you like
    },

    -- optional: keep everything else default for now
    -- instructions file located in ~/.config/nvim/
    instructions_file = "avante.md",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-mini/mini.pick",
    "nvim-telescope/telescope.nvim",
    "hrsh7th/nvim-cmp",
    "ibhagwan/fzf-lua",
    "stevearc/dressing.nvim",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
  },
}