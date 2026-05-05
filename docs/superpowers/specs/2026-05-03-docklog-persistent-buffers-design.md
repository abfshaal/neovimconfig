# Docklog: Persistent Named Buffers & Session Picker

**Date:** 2026-05-03
**Status:** Approved

## Problem

1. Closing a docklog window destroys the buffer (`bufhidden = "wipe"`). Can't return to it.
2. Buffers are unnamed and unlisted — no way to distinguish or switch between multiple log sessions.
3. When adding targets to existing buffer, already-attached targets still appear in picker.

## Design

### 1. Persistent Named Buffers

**viewer.lua changes:**

- `nvim_create_buf(true, true)` — first arg `true` makes buffer listed (visible in `:ls`, `<C-T>` picker)
- `bufhidden = "hide"` — buffer survives when window closes, jobs keep streaming
- `buftype = "nofile"` — unchanged, still a scratch buffer
- Set buffer name via `nvim_buf_set_name(buf, "docklog://target-name")`:
  - Single target: `docklog://my-api-pod-abc123`
  - Multiple targets: `docklog://pod1+pod2`
  - Name updates when targets added via `add_target()` (append `+newname`)
- `BufWipeout` autocmd stays — handles cleanup if user does manual `:bwipeout`
- Explicit quit keymap (`<C-f>lq`) calls `vim.api.nvim_buf_delete(buf, {force = true})` which triggers BufWipeout cleanup (kills jobs, removes session)

**Behavior:**
- Navigate away from docklog buffer → buffer persists, jobs keep streaming, logs accumulate
- Navigate back (via session picker, `:b docklog://...`, or `<C-T>`) → see latest logs, follow mode resumes scroll
- Quit (`<C-f>lq`) → kills jobs, wipes buffer permanently

### 2. Session Picker (DocklogSessions)

**New command: `DocklogSessions`**

Telescope picker showing all active docklog sessions from `State.all_sessions()`.

**Display format per entry:**
```
docklog://pod-name    [STREAMING]  2 targets
docklog://nginx       [ENDED]      1 target
```

**Mappings:**
- `<CR>` — open in current window (swap buffer, no split)
- `<C-v>` — open in vertical split
- `<C-x>` — open in horizontal split

**New keymap:** `<C-f>ls` (configurable as `keymaps.sessions`)

**New config field:**
```lua
keymaps = {
  ...
  sessions = "s",  -- prefix + "s" = <C-f>ls
}
```

**Implementation location:** New function `M.docklog_sessions()` in `picker.lua`.

### 3. Target Deduplication in Add Picker

**picker.lua `add_to_buffer()` changes:**

Before displaying picker results, filter out targets already attached to current session:

```lua
-- Get names of already-attached targets
local session = State.get_session(buf)
local existing = {}
for _, t in ipairs(session.targets) do
  existing[t.name] = true
end

-- Filter results
local available = vim.tbl_filter(function(target)
  return not existing[target.name]
end, targets)
```

Applies to both Docker and Kubernetes providers in `add_to_buffer()`.

### 4. Provider Compatibility

All changes work identically for Docker and Kubernetes providers:
- Buffer naming uses `provider.get_tag(target)` which already exists for both providers
- Target dedup uses `target.name` which both providers supply
- Session picker is provider-agnostic (reads from State, not providers)

### Files Modified

| File | Changes |
|------|---------|
| `lua/docklog/viewer.lua` | `bufhidden="hide"`, listed buffer, buffer naming, quit = bwipeout |
| `lua/docklog/picker.lua` | New `docklog_sessions()`, dedup in `add_to_buffer()` |
| `lua/docklog/config.lua` | Add `keymaps.sessions` field |
| `lua/docklog/init.lua` | Register `<C-f>ls` global keymap |
| `plugin/docklog.lua` | Register `DocklogSessions` command |

### Files NOT Modified

| File | Reason |
|------|--------|
| `lua/docklog/state.lua` | Already has `all_sessions()`, no changes needed |
| `lua/docklog/filter.lua` | No relevance |
| `lua/docklog/highlights.lua` | No relevance |
| `lua/docklog/providers/*.lua` | Provider interface unchanged |
