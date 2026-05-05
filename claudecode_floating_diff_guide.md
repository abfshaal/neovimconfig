# Guide: Converting `claudecode.nvim` Diff View to a Floating Window

This guide is designed so you can hand it directly to an AI assistant and have it automatically apply the required code changes. It includes precise steps, file paths, and integration details.

---

## Overview

`claudecode.nvim` currently displays proposed changes in a **vertical split diff view**.  
You want to change this so that **every edit request opens a floating diff window** instead, which disappears after either *Accept* or *Reject*.

This guide walks an AI assistant through:

1. Cloning the plugin locally  
2. Adding a floating-diff module  
3. Replacing the plugin’s built-in diff UI with your floating window  
4. Loading the patched plugin in Neovim  
5. Testing the behavior  

---

## 1. Clone/Fork the Plugin

### Option A: Fork then clone

```
# On GitHub: fork coder/claudecode.nvim first
git clone https://github.com/<your-username>/claudecode.nvim.git ~/code/claudecode.nvim
```

### Option B: Clone directly

```
git clone https://github.com/coder/claudecode.nvim.git ~/code/claudecode.nvim
```

From here, the path will be:

```
~/code/claudecode.nvim
```

---

## 2. Add a Floating Diff Module

Create:

```
~/code/claudecode.nvim/lua/claudecode/diff_float.lua
```

Add this content:

```lua
local M = {}
local state = {
  win = nil,
  buf = nil,
}

local function close_float(action)
  if action == "accept" then
    vim.cmd("ClaudeCodeDiffAccept")
  elseif action == "deny" then
    vim.cmd("ClaudeCodeDiffDeny")
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win, state.buf = nil, nil
end

function M.open(diff_lines)
  if type(diff_lines) == "string" then
    diff_lines = vim.split(diff_lines, "\n", { plain = true })
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "filetype", "diff")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local lines = { "# Claude diff (a=accept, q=reject)", "" }
  vim.list_extend(lines, diff_lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.8)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  state.win = win
  state.buf = buf

  local opts = { buffer = buf, nowait = true, noremap = true, silent = true }
  vim.keymap.set("n", "a", function() close_float("accept") end, opts)
  vim.keymap.set("n", "q", function() close_float("deny") end, opts)
  vim.keymap.set("n", "<Esc>", function() close_float("deny") end, opts)
end

return M
```

---

## 3. Replace the Existing Diff Logic

Search for the module that opens the diff view:

```
rg "vertical_split" lua
rg "diff_opts" lua
rg "diffthis" lua
```

In the file that creates the diff windows (usually `diff.lua`), replace the function responsible for opening the diff UI.

Example patch:

```lua
-- At the top:
local diff_float = require("claudecode.diff_float")

-- Find:
function M.show_diff(diff_text)
  -- old vertical split logic
end

-- Replace with:
function M.show_diff(diff_text)
  diff_float.open(diff_text)
end
```

This forces all incoming proposed changes to open in your floating diff window.

---

## 4. Load Your Local Version into Neovim (Lazy.nvim Example)

In your Neovim config:

```lua
{
  "coder/claudecode.nvim",
  dir = "~/code/claudecode.nvim",
  dev = true,
  dependencies = {
    "folke/snacks.nvim",
  },
  config = true,
}
```

Then:

```
:Lazy sync
```

Restart Neovim.

---

## 5. Test the Floating Diff

1. Open Neovim in a project that Claude can modify.
2. Trigger an edit:

```
:ClaudeCode
```

3. Ask Claude to modify the current file.
4. You should now see:

- A centered floating window
- Diff syntax
- `a` → accept changes  
- `q` / `<Esc>` → reject changes  
- The float disappears automatically

---

## 6. Optional: Keep Global Accept/Reject Shortcuts

Your float doesn’t break the built-in mappings:

- `<leader>aa` → accept changes  
- `<leader>ad` → reject changes  

They still call:

- `:ClaudeCodeDiffAccept`
- `:ClaudeCodeDiffDeny`

Which your float triggers as well.

---

## Done!

You can now hand this `.md` file to an AI assistant and it will know exactly what to modify and where.

