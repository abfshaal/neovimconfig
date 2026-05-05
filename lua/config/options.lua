-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Prioritize Tree-sitter over LSP semantic highlighting
vim.g.semantic_tokens_enabled = false
vim.highlight.priorities.semantic_tokens = 95

-- Increase timeout for key sequences (default 300ms from LazyVim is too fast for <C-f> prefix)
vim.opt.timeoutlen = 1000
