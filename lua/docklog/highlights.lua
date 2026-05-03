local M = {}

local Config = require("docklog.config")

-- Log level to highlight group mapping
M.level_highlights = {
  CRITICAL = "DiagnosticError",
  FATAL = "DiagnosticError",
  ERROR = "DiagnosticError",
  WARN = "DiagnosticWarn",
  WARNING = "DiagnosticWarn",
  INFO = "DiagnosticInfo",
  DEBUG = "DiagnosticHint",
  TRACE = "Comment",
}

-- Level keywords to search for in each line
M.level_keywords = { "CRITICAL", "FATAL", "ERROR", "WARNING", "WARN", "INFO", "DEBUG", "TRACE" }

---Apply syntax highlighting to a single line in a buffer.
---Highlights the tag prefix and any log level keyword found.
---@param buf number
---@param line_idx number 0-indexed line number
---@param tag string The source tag for this line
---@param tag_color_idx number Index into tag_colors config (1-based, will wrap)
function M.highlight_line(buf, line_idx, tag, tag_color_idx)
  if not vim.api.nvim_buf_is_valid(buf) then return end

  local line = vim.api.nvim_buf_get_lines(buf, line_idx, line_idx + 1, false)[1]
  if not line then return end

  -- Highlight the tag prefix [tag]
  local tag_colors = Config.values.ui.tag_colors
  local color_idx = ((tag_color_idx - 1) % #tag_colors) + 1
  local hl_group = tag_colors[color_idx]
  local tag_end = #tag + 2 -- [tag]
  vim.api.nvim_buf_add_highlight(buf, -1, hl_group, line_idx, 0, tag_end)

  -- Highlight log level keyword
  for _, keyword in ipairs(M.level_keywords) do
    local start_pos = line:find(keyword, tag_end + 1, true)
    if start_pos then
      local hl = M.level_highlights[keyword]
      vim.api.nvim_buf_add_highlight(buf, -1, hl, line_idx, start_pos - 1, start_pos - 1 + #keyword)
      break
    end
  end
end

---Get the color index for a tag based on its position in the target list.
---@param tag string
---@param targets docklog.Target[]
---@return number
function M.get_tag_color_index(tag, targets)
  for i, t in ipairs(targets) do
    if t.tag == tag then
      return i
    end
  end
  return 1
end

return M
