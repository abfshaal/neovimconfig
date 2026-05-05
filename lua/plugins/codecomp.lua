return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    { "<C-c>c", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle CodeCompanion" },
    { "<C-c>n", "<cmd>CodeCompanionChat New<cr>", desc = "Start New Chat" },
    { "<C-c>p", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle Side Panel" },
    { "<C-c>a", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion Actions" },
    { "<C-c>s", "<cmd>CodeCompanionChat<cr>", mode = "v", desc = "Send to CodeCompanion" },
    { "<C-c>i", "<cmd>CodeCompanion ", mode = { "n", "v" }, desc = "Inline Assistant" },
  },
  config = function()
    require("codecompanion").setup({
      adapters = {
        acp = {
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              defaults = {
                model = "opus",
              },
              env = {
                ACP_PERMISSION_MODE = "bypassPermissions",
              },
            })
          end,
          -- Codex ACP adapter (OpenAI codex-acp binary)
          codex = function()
            local codex_env = {}
            if os.getenv("OPENAI_API_KEY") then
              codex_env.OPENAI_API_KEY = "OPENAI_API_KEY"
            end
            if os.getenv("CODEX_API_KEY") then
              codex_env.CODEX_API_KEY = "CODEX_API_KEY"
            end

            return require("codecompanion.adapters").extend("codex", {
              env = codex_env,
            })
          end,
          -- OpenCode adapter (default model). Use `ga` in chat to switch models
          -- via ACP session/set_model, or start a chat with a specific adapter below.
          opencode = function()
            return require("codecompanion.adapters").extend("opencode", {})
          end,
          -- Named OpenCode adapters for specific models.
          -- Use these in interactions.chat.adapter or start a chat with :CodeCompanionChat adapter=opencode_codex
          opencode_codex = function()
            return require("codecompanion.adapters").extend("opencode", {
              name = "opencode_codex",
              formatted_name = "OpenCode (GPT-5.2 Codex)",
              defaults = { model = "openai/gpt-5.2-codex" },
            })
          end,
          opencode_gpt52 = function()
            return require("codecompanion.adapters").extend("opencode", {
              name = "opencode_gpt52",
              formatted_name = "OpenCode (GPT-5.2)",
              defaults = { model = "openai/gpt-5.2" },
            })
          end,
          opencode_copilot_opus = function()
            return require("codecompanion.adapters").extend("opencode", {
              name = "opencode_copilot_opus",
              formatted_name = "OpenCode (Copilot Opus)",
              defaults = { model = "github-copilot/claude-opus-4.5" },
            })
          end,
          opencode_copilot_sonnet = function()
            return require("codecompanion.adapters").extend("opencode", {
              name = "opencode_copilot_sonnet",
              formatted_name = "OpenCode (Copilot Sonnet)",
              defaults = { model = "github-copilot/claude-sonnet-4.5" },
            })
          end,
          opencode_cursor_opus_thinking = function()
            return require("codecompanion.adapters").extend("opencode", {
              name = "opencode_cursor_opus_thinking",
              formatted_name = "OpenCode (Cursor Opus Thinking)",
              defaults = { model = "cursor/opus-4.5-thinking" },
            })
          end,
          opencode_gemini = function()
            return require("codecompanion.adapters").extend("opencode", {
              name = "opencode_gemini",
              formatted_name = "OpenCode (Gemini 3 Pro)",
              defaults = { model = "google/gemini-3-pro-preview" },
            })
          end,
        },
      },
      interactions = {
        chat = {
          adapter = {
            name = "claude_code",
            model = "opus",
          },
        },
        inline = {
          adapter = "claude_code",
          keymaps = {
            accept_change = {
              modes = { n = "gda" },
              index = 1,
              callback = "keymaps.accept_change",
              description = "Accept the inline change",
            },
            reject_change = {
              modes = { n = "gdr" },
              index = 2,
              callback = "keymaps.reject_change",
              description = "Reject the inline change",
            },
          },
        },
      },
      display = {
        chat = {
          window = {
            layout = "buffer",
          },
          show_token_count = true,
        },
        diff = {
          provider = "mini_diff",
        },
      },
      opts = {
        log_level = "DEBUG",
      },
    })

    -- Estimate token count for ACP adapters (which don't report usage stats).
    -- Uses the built-in heuristic (1 token ~ 4 chars) on all messages.
    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("codecompanion_acp_token_count", { clear = true }),
      pattern = "CodeCompanionChatDone",
      callback = function(args)
        local bufnr = args.data and args.data.bufnr
        if not bufnr then
          return
        end
        local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
        if not chat or not chat.adapter or chat.adapter.type ~= "acp" then
          return
        end
        local tokens = require("codecompanion.utils.tokens")
        chat.ui.tokens = tokens.get_tokens(chat.messages)
        chat.ui:display_tokens(chat.chat_parser, chat.header_line)
      end,
      desc = "CodeCompanion: estimate token count for ACP adapters",
    })

    -- Force Claude Code ACP sessions into bypassPermissions mode so CodeCompanion
    -- never shows ACP permission prompts.
    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("codecompanion_claude_code_acp_mode", { clear = true }),
      pattern = "CodeCompanionChatCreated",
      callback = function(args)
        local bufnr = args.data and args.data.bufnr
        if not bufnr then
          return
        end

        local chat = require("codecompanion.interactions.chat").buf_get_chat(bufnr)
        if not chat or not chat.adapter or chat.adapter.type ~= "acp" or chat.adapter.name ~= "claude_code" then
          return
        end

        -- Ensure ACP connection exists (Chat schedules this, but we want it immediately).
        require("codecompanion.interactions.chat.helpers").create_acp_connection(chat)

        if chat.acp_connection and chat.acp_connection.set_mode then
          chat.acp_connection:set_mode("bypassPermissions")
        end
      end,
      desc = "CodeCompanion: set Claude Code ACP mode to bypassPermissions",
    })
  end,
}
