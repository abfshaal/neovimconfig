return {
  "carlos-algms/agentic.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    provider = "claude-acp",
    windows = {
      position = "right",
      width = "40%",
    },
  },
  keys = {
    {
      "<C-a>v",
      function()
        require("agentic").toggle()
      end,
      mode = { "n", "v", "i" },
      desc = "Toggle Claude Chat View",
    },
    {
      "<C-a>'",
      function()
        require("agentic").add_selection_or_file_to_context()
      end,
      mode = { "n", "v" },
      desc = "Add file/selection to Claude context",
    },
    {
      "<C-a>N",
      function()
        require("agentic").new_session()
      end,
      mode = { "n", "v", "i" },
      desc = "New Claude Chat Session",
    },
    {
      "<C-a>R",
      function()
        require("agentic").restore_session()
      end,
      mode = { "n", "v", "i" },
      desc = "Restore Claude session",
    },
  },
}
