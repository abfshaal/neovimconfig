local M = {}

local Config = require("docklog.config")
local State = require("docklog.state")
local Filter = require("docklog.filter")
local Highlights = require("docklog.highlights")

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

---Open a split window for the buffer.
---@param buf number
---@return number win
local function open_split(buf)
  local direction = Config.values.ui.split_direction
  local size = Config.values.ui.split_size

  if direction == "right" then
    vim.cmd("vertical rightbelow " .. size .. "split")
  else
    vim.cmd("rightbelow " .. size .. "split")
  end

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  return win
end

---Update the winbar for a log buffer.
---@param buf number
local function update_winbar(buf)
  local session = State.get_session(buf)
  if not session then return end

  -- Build tags section
  local tag_parts = {}
  for _, target in ipairs(session.targets) do
    tag_parts[#tag_parts + 1] = target.tag
  end
  local tags_str = table.concat(tag_parts, " | ")

  -- Build mode section
  local mode_str = session.follow_mode and "%#DiagnosticInfo#FOLLOW%*" or "%#DiagnosticWarn#PAUSED%*"

  -- Build filter section
  local filter_parts = {}
  if session.filters.level then
    filter_parts[#filter_parts + 1] = session.filters.level
  end
  if session.filters.keyword then
    filter_parts[#filter_parts + 1] = '"' .. session.filters.keyword .. '"'
  end
  local filter_str = #filter_parts > 0 and ("FILTER: " .. table.concat(filter_parts, " + ")) or ""

  -- Assemble winbar
  local winbar = string.format(" [%s] [%s]", tags_str, mode_str)
  if filter_str ~= "" then
    winbar = winbar .. string.format(" [%s]", filter_str)
  end

  -- Set winbar on all windows showing this buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      vim.wo[win].winbar = winbar
    end
  end
end

---Render filtered lines to the buffer, replacing all content.
---@param buf number
local function render_buffer(buf)
  local session = State.get_session(buf)
  if not session then return end

  local display_lines = Filter.get_filtered_lines(session.raw_lines, session.filters)

  vim.bo[buf].modifiable = true

  if #display_lines == 0 and (session.filters.keyword or session.filters.level) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "--- No lines match current filter ---" })
  else
    local lines = {}
    for _, dl in ipairs(display_lines) do
      lines[#lines + 1] = dl.display
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Apply highlights
    for i, dl in ipairs(display_lines) do
      local color_idx = Highlights.get_tag_color_index(dl.tag, session.targets)
      Highlights.highlight_line(buf, i - 1, dl.tag, color_idx)
    end
  end

  -- Auto-scroll if follow mode
  if session.follow_mode then
    local line_count = vim.api.nvim_buf_line_count(buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_set_cursor(win, { line_count, 0 })
      end
    end
  end
end

---Append a single line to the buffer (used during streaming for efficiency).
---@param buf number
---@param tag string
---@param text string
local function append_line(buf, tag, text)
  local session = State.get_session(buf)
  if not session then return end

  -- Check filter
  if not Filter.matches(text, session.filters) then
    return
  end

  local display = Filter.build_display_line(tag, text)

  vim.bo[buf].modifiable = true

  -- If buffer only has the "no match" placeholder, clear it first
  local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if first_line == "--- No lines match current filter ---" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { display })
  else
    local line_count = vim.api.nvim_buf_line_count(buf)
    -- If buffer is empty (single empty line), replace it
    if line_count == 1 and first_line == "" then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { display })
    else
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { display })
    end
  end

  -- Highlight the new line
  local new_line_idx = vim.api.nvim_buf_line_count(buf) - 1
  local color_idx = Highlights.get_tag_color_index(tag, session.targets)
  Highlights.highlight_line(buf, new_line_idx, tag, color_idx)

  -- Trim buffer if over max_lines
  local max = Config.values.max_lines
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count > max then
    local overflow = line_count - max
    vim.api.nvim_buf_set_lines(buf, 0, overflow, false, {})
  end

  -- Auto-scroll if follow mode
  if session.follow_mode then
    local final_count = vim.api.nvim_buf_line_count(buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_set_cursor(win, { final_count, 0 })
      end
    end
  end
end

---Start a log streaming job for a target.
---@param buf number
---@param target table
---@param provider table
local function start_job(buf, target, provider)
  local tag = provider.get_tag(target)
  local cmd = provider.build_log_cmd(target)

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        for _, line in ipairs(data) do
          if line ~= "" then
            State.add_line(buf, tag, line)
            append_line(buf, tag, line)
          end
        end
      end)
    end,
    on_stderr = function(_, data)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        for _, line in ipairs(data) do
          if line ~= "" then
            State.add_line(buf, tag, "[stderr] " .. line)
            append_line(buf, tag, "[stderr] " .. line)
          end
        end
      end)
    end,
    on_exit = function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        local end_msg = "--- STREAM ENDED ---"
        State.add_line(buf, tag, end_msg)
        append_line(buf, tag, end_msg)

        -- Mark target as ended
        local session = State.get_session(buf)
        if session then
          for _, t in ipairs(session.targets) do
            if t.tag == tag then
              t.ended = true
              break
            end
          end
        end
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start log stream for " .. tag, vim.log.levels.ERROR)
    return
  end

  local session = State.get_session(buf)
  if session then
    session.jobs[job_id] = tag
  end
end

---Set buffer-local keymaps for a log buffer.
---@param buf number
---@param provider table
local function set_keymaps(buf, provider)
  local km = Config.values.keymaps
  local prefix = km.prefix

  local function map(suffix, fn, desc)
    vim.keymap.set("n", prefix .. suffix, fn, { buffer = buf, silent = true, desc = "Docklog: " .. desc })
  end

  map(km.follow, function()
    M.toggle_follow(buf)
  end, "Toggle follow/pause")

  map(km.keyword, function()
    vim.ui.input({ prompt = "Filter keyword: " }, function(input)
      if input and input ~= "" then
        M.set_keyword_filter(buf, input)
      end
    end)
  end, "Set keyword filter")

  map(km.level, function()
    vim.ui.select(
      { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "CRITICAL" },
      { prompt = "Minimum log level:" },
      function(choice)
        if choice then
          M.set_level_filter(buf, choice)
        end
      end
    )
  end, "Set level filter")

  map(km.clear, function()
    M.clear_filters(buf)
  end, "Clear all filters")

  map(km.quit, function()
    M.close(buf)
  end, "Stop streams and close")

  map(km.add, function()
    -- Re-open picker to add more targets to this buffer
    local picker = require("docklog.picker")
    picker.add_to_buffer(buf, provider)
  end, "Add another target")
end

---Open a new log viewer with the given targets.
---@param targets table[] List of targets from provider
---@param provider table The provider module (docker or kubernetes)
function M.open(targets, provider)
  if #targets == 0 then
    vim.notify("No targets selected", vim.log.levels.WARN)
    return
  end

  local buf = create_buffer()
  local win = open_split(buf)
  local session = State.create_session(buf)

  -- Register targets
  for _, target in ipairs(targets) do
    local tag = provider.get_tag(target)
    session.targets[#session.targets + 1] = {
      name = target.name,
      tag = tag,
      provider_type = provider.type(),
      ended = false,
    }
  end

  -- Set keymaps
  set_keymaps(buf, provider)

  -- Update winbar
  update_winbar(buf)

  -- Start jobs
  for _, target in ipairs(targets) do
    start_job(buf, target, provider)
  end

  -- Auto-cleanup on buffer wipe
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      M.stop_jobs(buf)
      State.remove_session(buf)
    end,
  })

  return buf
end

---Add a target to an existing log buffer.
---@param buf number
---@param target table
---@param provider table
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
  start_job(buf, target, provider)
end

---Toggle follow/pause mode for a buffer.
---@param buf number
function M.toggle_follow(buf)
  local session = State.get_session(buf)
  if not session then return end

  session.follow_mode = not session.follow_mode

  if session.follow_mode then
    -- Jump to bottom
    local line_count = vim.api.nvim_buf_line_count(buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_set_cursor(win, { line_count, 0 })
      end
    end
  end

  update_winbar(buf)
end

---Set keyword filter and re-render buffer.
---@param buf number
---@param keyword string
function M.set_keyword_filter(buf, keyword)
  local session = State.get_session(buf)
  if not session then return end

  session.filters.keyword = keyword
  render_buffer(buf)
  update_winbar(buf)
end

---Set log level filter and re-render buffer.
---@param buf number
---@param level string
function M.set_level_filter(buf, level)
  local session = State.get_session(buf)
  if not session then return end

  session.filters.level = level
  render_buffer(buf)
  update_winbar(buf)
end

---Clear all filters and re-render buffer.
---@param buf number
function M.clear_filters(buf)
  local session = State.get_session(buf)
  if not session then return end

  session.filters.keyword = nil
  session.filters.level = nil
  render_buffer(buf)
  update_winbar(buf)
end

---Stop all jobs for a buffer.
---@param buf number
function M.stop_jobs(buf)
  local session = State.get_session(buf)
  if not session then return end

  for job_id, _ in pairs(session.jobs) do
    pcall(vim.fn.jobstop, job_id)
  end
  session.jobs = {}
end

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

return M
