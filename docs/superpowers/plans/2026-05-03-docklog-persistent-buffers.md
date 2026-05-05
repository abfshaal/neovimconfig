# Docklog Persistent Buffers & Session Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make docklog buffers persist when their window closes, name them after their targets, add a Telescope session picker to switch between them, and filter already-attached targets from the add picker.

**Architecture:** Change buffer lifecycle from wipe-on-hide to hide-on-hide. Name buffers with `docklog://` URI scheme. Add `DocklogSessions` Telescope picker that opens sessions in current window. Filter duplicates in `add_to_buffer`.

**Tech Stack:** Neovim Lua API, Telescope.nvim

---

### Task 1: Make Buffers Persistent and Named

**Files:**
- Modify: `lua/docklog/viewer.lua:10-18` (create_buffer)
- Modify: `lua/docklog/viewer.lua:290-332` (M.open)
- Modify: `lua/docklog/viewer.lua:334-352` (M.add_target)
- Modify: `lua/docklog/viewer.lua:423-435` (M.close)

- [ ] **Step 1: Update `create_buffer()` — make buffer listed and persistent**

In `lua/docklog/viewer.lua`, replace lines 10-18:

```lua
---Create a scratch buffer for log viewing.
---@return number buf
local function create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "docklog"
  return buf
end
```

With:

```lua
---Create a scratch buffer for log viewing.
---@return number buf
local function create_buffer()
  local buf = vim.api.nvim_create_buf(true, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "docklog"
  return buf
end
```

Two changes: first arg `true` (listed), `bufhidden = "hide"` (persist on window close).

- [ ] **Step 2: Add helper to build buffer name from targets**

In `lua/docklog/viewer.lua`, add after `create_buffer()` (after line 18):

```lua
---Build a docklog:// buffer name from session targets.
---@param targets table[]
---@param provider table
---@return string
local function build_buffer_name(targets, provider)
  local names = {}
  for _, target in ipairs(targets) do
    names[#names + 1] = provider.get_tag(target)
  end
  return "docklog://" .. table.concat(names, "+")
end

---Update the buffer name to reflect current session targets.
---@param buf number
local function update_buffer_name(buf)
  local session = State.get_session(buf)
  if not session then return end
  local names = {}
  for _, target in ipairs(session.targets) do
    names[#names + 1] = target.tag
  end
  local name = "docklog://" .. table.concat(names, "+")
  -- pcall because name might conflict with existing buffer
  pcall(vim.api.nvim_buf_set_name, buf, name)
end
```

- [ ] **Step 3: Set buffer name in `M.open()`**

In `lua/docklog/viewer.lua`, in the `M.open()` function, add buffer naming after targets are registered. After line 309 (end of the target registration loop), add:

```lua
  -- Set buffer name
  local buf_name = build_buffer_name(targets, provider)
  pcall(vim.api.nvim_buf_set_name, buf, buf_name)
```

- [ ] **Step 4: Update buffer name in `M.add_target()`**

In `lua/docklog/viewer.lua`, in `M.add_target()`, after line 350 (`update_winbar(buf)`), add:

```lua
  update_buffer_name(buf)
```

So the function becomes:

```lua
function M.add_target(buf, target, provider)
  local session = State.get_session(buf)
  if not session then return end

  local tag = provider.get_tag(target)
  session.targets[#session.targets + 1] = {
    name = target.name,
    tag = tag,
    provider_type = provider.type(),
    ended = false,
  }

  update_winbar(buf)
  update_buffer_name(buf)
  start_job(buf, target, provider)
end
```

- [ ] **Step 5: Update `M.close()` to wipe buffer permanently**

In `lua/docklog/viewer.lua`, replace the entire `M.close()` function (lines 425-435):

```lua
---Stop jobs and close the buffer.
---@param buf number
function M.close(buf)
  M.stop_jobs(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    -- Close windows showing this buffer
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_close(win, true)
      end
    end
  end
end
```

With:

```lua
---Stop jobs, destroy session, and wipe the buffer permanently.
---@param buf number
function M.close(buf)
  M.stop_jobs(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end
```

`nvim_buf_delete` with `force = true` wipes buffer, which triggers the `BufWipeout` autocmd that calls `State.remove_session(buf)`.

- [ ] **Step 6: Verify manually**

1. Open Neovim, run `:DocklogDocker` (or `:DocklogKube`), pick a target
2. Check `:ls` — should see `docklog://container-name` listed
3. Switch to another buffer (`:b#` or `<C-T>`) — log buffer should stay in `:ls`, jobs keep streaming
4. Switch back to docklog buffer (`:b docklog://...`) — should see accumulated logs
5. Press `<C-f>lq` — buffer should disappear from `:ls` completely
6. Repeat with K8s pods to verify both providers work

- [ ] **Step 7: Commit**

```bash
git add lua/docklog/viewer.lua
git commit -m "feat(docklog): persistent named buffers that survive window close"
```

---

### Task 2: Add Session Picker

**Files:**
- Modify: `lua/docklog/picker.lua` (add `docklog_sessions()` function)
- Modify: `lua/docklog/config.lua:28,79` (add `sessions` keymap field)
- Modify: `lua/docklog/init.lua:24-25` (register global keymap)
- Modify: `plugin/docklog.lua` (register `DocklogSessions` command)

- [ ] **Step 1: Add `sessions` to keymap config**

In `lua/docklog/config.lua`, add `sessions` field to the `KeymapConfig` class annotation. Replace line 28:

```lua
---@field label string
```

With:

```lua
---@field label string
---@field sessions string
```

Then in the keymaps table, add after line 78 (`label = "L",`):

```lua
    sessions = "s",
```

So the keymaps block becomes:

```lua
  keymaps = {
    prefix = "<C-f>l",
    follow = "f",
    keyword = "k",
    level = "l",
    clear = "c",
    quit = "q",
    add = "a",
    docker = "d",
    compose = "D",
    pods = "p",
    namespace = "n",
    deployments = "e",
    label = "L",
    sessions = "s",
  },
```

- [ ] **Step 2: Add `docklog_sessions()` to picker.lua**

In `lua/docklog/picker.lua`, add the State require at the top. After line 9 (`local Viewer = require("docklog.viewer")`), add:

```lua
local State = require("docklog.state")
```

Then add the new function before `return M` (before line 486):

```lua
---Create a Telescope picker for active docklog sessions.
function M.docklog_sessions()
  local sessions = State.all_sessions()

  -- Build list of session entries
  local entries = {}
  for buf_id, session in pairs(sessions) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      -- Determine status
      local streaming = false
      for _ in pairs(session.jobs) do
        streaming = true
        break
      end
      local status = streaming and "STREAMING" or "ENDED"

      -- Build name from targets
      local names = {}
      for _, target in ipairs(session.targets) do
        names[#names + 1] = target.tag
      end
      local buf_name = table.concat(names, "+")

      entries[#entries + 1] = {
        buf_id = buf_id,
        name = buf_name,
        status = status,
        target_count = #session.targets,
      }
    end
  end

  if #entries == 0 then
    vim.notify("No active docklog sessions", vim.log.levels.INFO)
    return
  end

  pickers.new({}, {
    prompt_title = "Docklog Sessions",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("docklog://%-30s [%-9s]  %d target(s)",
            entry.name, entry.status, entry.target_count),
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          vim.api.nvim_win_set_buf(0, entry.value.buf_id)
        end
      end)

      -- Vertical split
      map("i", "<C-v>", function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          vim.cmd("vsplit")
          vim.api.nvim_win_set_buf(0, entry.value.buf_id)
        end
      end)

      -- Horizontal split
      map("i", "<C-x>", function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          vim.cmd("split")
          vim.api.nvim_win_set_buf(0, entry.value.buf_id)
        end
      end)

      return true
    end,
  }):find()
end
```

- [ ] **Step 3: Register `DocklogSessions` command**

In `plugin/docklog.lua`, add after the `DocklogAdd` command (after line 130):

```lua
vim.api.nvim_create_user_command("DocklogSessions", function()
  require("docklog.picker").docklog_sessions()
end, { desc = "Docklog: pick from active log sessions" })
```

- [ ] **Step 4: Register global keymap for sessions**

In `lua/docklog/init.lua`, add after line 24 (the label keymap):

```lua
  vim.keymap.set("n", prefix .. km.sessions, "<cmd>DocklogSessions<cr>",
    { silent = true, desc = "Docklog: active sessions picker" })
```

- [ ] **Step 5: Verify manually**

1. Open two separate docklog sessions (e.g. two different Docker containers via `:DocklogDocker`)
2. Run `:DocklogSessions` or press `<C-f>ls`
3. Should see both sessions listed with names and status
4. Press `<CR>` on one — current window should swap to that buffer (no new split)
5. Press `<C-v>` on one — should open in vertical split
6. Close a session window (`:q`), run `:DocklogSessions` — session should still appear (buffer persisted)
7. Repeat with K8s pods

- [ ] **Step 6: Commit**

```bash
git add lua/docklog/picker.lua lua/docklog/config.lua lua/docklog/init.lua plugin/docklog.lua
git commit -m "feat(docklog): add DocklogSessions telescope picker for switching between log buffers"
```

---

### Task 3: Deduplicate Targets in Add Picker

**Files:**
- Modify: `lua/docklog/picker.lua:377-484` (add_to_buffer)

- [ ] **Step 1: Add dedup filtering to Docker branch of `add_to_buffer()`**

In `lua/docklog/picker.lua`, in the `add_to_buffer()` function, inside the Docker branch. After line 382 (`docker.list_targets(function(targets)`), before the empty check on line 383, add the dedup logic:

Replace:

```lua
    docker.list_targets(function(targets)
      if #targets == 0 then
        vim.notify("No running Docker containers found", vim.log.levels.INFO)
        return
      end
```

With:

```lua
    docker.list_targets(function(targets)
      -- Filter out already-attached targets
      local session = State.get_session(buf)
      if session then
        local existing = {}
        for _, t in ipairs(session.targets) do
          existing[t.name] = true
        end
        targets = vim.tbl_filter(function(target)
          return not existing[target.name]
        end, targets)
      end

      if #targets == 0 then
        vim.notify("No additional Docker containers available", vim.log.levels.INFO)
        return
      end
```

- [ ] **Step 2: Add dedup filtering to Kubernetes branch of `add_to_buffer()`**

In the same function, inside the `do_add()` closure for Kubernetes. Replace:

```lua
      k8s.list_targets(target_ns, function(targets)
        if #targets == 0 then
          vim.notify("No pods found in namespace: " .. target_ns, vim.log.levels.INFO)
          return
        end
```

With:

```lua
      k8s.list_targets(target_ns, function(targets)
        -- Filter out already-attached targets
        local session = State.get_session(buf)
        if session then
          local existing = {}
          for _, t in ipairs(session.targets) do
            existing[t.name] = true
          end
          targets = vim.tbl_filter(function(target)
            return not existing[target.name]
          end, targets)
        end

        if #targets == 0 then
          vim.notify("No additional pods available in namespace: " .. target_ns, vim.log.levels.INFO)
          return
        end
```

- [ ] **Step 3: Verify manually**

1. Open docklog with one container/pod
2. Press `<C-f>la` to add another target
3. Already-attached target should NOT appear in picker
4. Add a second target
5. Press `<C-f>la` again — both should be filtered out
6. Repeat with K8s pods

- [ ] **Step 4: Commit**

```bash
git add lua/docklog/picker.lua
git commit -m "feat(docklog): filter already-attached targets from add picker"
```
