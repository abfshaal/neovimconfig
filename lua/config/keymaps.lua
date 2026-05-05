-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map({ "t" }, "<Esc><Esc>", vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true))

-- put this instead of your current jk mapping
map({ "i", "t" }, "kj", function()
  local ft = vim.bo.filetype
  if ft == "lazygit" or ft == "TelescopePrompt" or ft == "toggleterm" then
    return "kj" -- don't escape; just insert jk in those buffers
  end
  return vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true)
end, { expr = true, noremap = true, silent = true })

map({ "n", "v" }, "H", "^")
map({ "n", "v" }, "L", "$")

-- Telescope mappings

map({ "n" }, "<leader>fw", "<cmd>Telescope live_grep <cr>")
map({ "n" }, "<leader>fz", "<cmd> Telescope current_buffer_fuzzy_find <cr>")

map({ "v" }, "K", ":m '<-2<CR>gv=gv", { silent = true })
map({ "v" }, "J", ":m '>+1<CR>gv=gv", { silent = true })
map({ "n" }, "<leader>/", "gcc", { silent = true, remap = true })
map({ "v" }, "<leader>/", "gc", { silent = true, remap = true })

map({ "n" }, "<leader>tn", "<Cmd> tabnext<CR>", { silent = true, noremap = true })
map({ "n" }, "<leader>ft", "<Cmd>FloatermToggle --cmd='cd $(pwd)'<cr>", { noremap = true, silent = true })

map({ "n" }, "<leader>a", function()
  require("harpoon.mark").add_file()
end)
map({ "n" }, "<C-e>", function()
  require("harpoon.ui").toggle_quick_menu()
end)
map({ "n", "i", "t" }, "<C-t>", function()
  vim.cmd("stopinsert")
  Snacks.picker.buffers()
end, { desc = "Open buffer list" })
map({ "n" }, "<C-n>", function()
  require("harpoon.ui").nav_file(3)
end)
map({ "n" }, "<C-g>", function()
  require("harpoon.ui").nav_file(4)
end)

map({ "n" }, "<leader>cn", "i# %%<Esc>o<Esc>x")

map({ "n" }, "<leader>ghf", "<cmd>Gitsigns preview_hunk<cr>")

-- Lazygit integration
map({ "n" }, "<leader>gg", function()
  Snacks.lazygit()
end, { desc = "Lazygit" })

-- Terminal navigation: jump to previous/next user question
map({ "n" }, "[c", function()
  vim.fn.search("^> ", "b")
end, { desc = "Jump to previous question in terminal" })

map({ "n" }, "]c", function()
  vim.fn.search("^> ")
end, { desc = "Jump to next question in terminal" })

-- =====================================================
-- <C-f> prefix variants (mirror of <leader> bindings)
-- =====================================================

-- Explorer toggle
map({ "n", "i", "t" }, "<C-f>e", function()
  vim.cmd("stopinsert")
  Snacks.explorer()
end, { desc = "Toggle explorer (C-f)" })

-- File picker
map({ "n", "i", "t" }, "<C-f><C-f>", function()
  vim.cmd("stopinsert")
  Snacks.picker.files()
end, { desc = "Find files (C-f)" })

-- Telescope
map({ "n", "i", "t" }, "<C-f>w", function()
  vim.cmd("stopinsert")
  vim.cmd("Telescope live_grep")
end, { desc = "Live grep (C-f)" })
map({ "n", "i", "t" }, "<C-f>z", function()
  vim.cmd("stopinsert")
  vim.cmd("Telescope current_buffer_fuzzy_find")
end, { desc = "Buffer fuzzy find (C-f)" })

-- Comment toggle
map({ "n", "i", "t" }, "<C-f>/", function()
  vim.cmd("stopinsert")
  vim.cmd("normal gcc")
end, { silent = true, desc = "Toggle comment (C-f)" })
map({ "v" }, "<C-f>/", function()
  vim.cmd("normal gc")
end, { silent = true, desc = "Toggle comment visual (C-f)" })

-- Tab next
map({ "n", "i", "t" }, "<C-f>tn", function()
  vim.cmd("stopinsert")
  vim.cmd("tabnext")
end, { silent = true, noremap = true, desc = "Tab next (C-f)" })

-- Floaterm
map({ "n", "i", "t" }, "<C-f><C-t>", function()
  vim.cmd("stopinsert")
  vim.cmd("FloatermToggle --cmd='cd " .. vim.fn.getcwd() .. "'")
end, { noremap = true, silent = true, desc = "Float term (C-f C-t)" })

-- Harpoon add
map({ "n", "i", "t" }, "<C-f>a", function()
  vim.cmd("stopinsert")
  require("harpoon.mark").add_file()
end, { desc = "Harpoon add file (C-f)" })

-- Notebook cell
map({ "n", "i", "t" }, "<C-f>cn", function()
  vim.cmd("stopinsert")
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i# %%<Esc>o<Esc>x", true, false, true), "n", false)
end, { desc = "New cell (C-f)" })

-- Gitsigns
map({ "n", "i", "t" }, "<C-f>ghf", function()
  vim.cmd("stopinsert")
  vim.cmd("Gitsigns preview_hunk")
end, { desc = "Preview hunk (C-f)" })

-- Mini files
map({ "n", "i", "t" }, "<C-f>m", function()
  vim.cmd("stopinsert")
  require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
end, { desc = "Mini Files (current file) (C-f)" })
map({ "n", "i", "t" }, "<C-f>M", function()
  vim.cmd("stopinsert")
  require("mini.files").open(vim.uv.cwd(), true)
end, { desc = "Mini Files (cwd) (C-f)" })

-- Previous buffer
map({ "n", "i", "t" }, "<C-f>bb", function()
  vim.cmd("stopinsert")
  vim.cmd("b#")
end, { desc = "Previous buffer (C-f)" })

-- Lazygit
map({ "n", "i", "t" }, "<C-f>gg", function()
  vim.cmd("stopinsert")
  Snacks.lazygit()
end, { desc = "Lazygit (C-f)" })
