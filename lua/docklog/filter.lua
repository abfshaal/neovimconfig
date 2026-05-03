local M = {}

local LEVEL_SEVERITY = {
  TRACE = 1,
  DEBUG = 2,
  INFO = 3,
  WARN = 4,
  WARNING = 4,
  ERROR = 5,
  CRITICAL = 6,
  FATAL = 6,
}

local LEVEL_PATTERN = "(TRACE|DEBUG|INFO|WARN|WARNING|ERROR|CRITICAL|FATAL)"

---@param text string
---@return string|nil level
local function extract_level(text)
  for level, _ in pairs(LEVEL_SEVERITY) do
    if text:find(level, 1, true) then
      return level
    end
  end
  return nil
end

---@param text string
---@param filters table
---@return boolean
function M.matches(text, filters)
  if filters.keyword then
    local pattern = filters.keyword:lower()
    if not text:lower():find(pattern, 1, true) then
      return false
    end
  end

  if filters.level then
    local min_severity = LEVEL_SEVERITY[filters.level:upper()]
    if min_severity then
      local line_level = extract_level(text)
      if line_level then
        local line_severity = LEVEL_SEVERITY[line_level]
        if line_severity < min_severity then
          return false
        end
      end
    end
  end

  return true
end

---@param tag string
---@param text string
---@return string
function M.build_display_line(tag, text)
  return string.format("[%s]  %s", tag, text)
end

---@param raw_lines table[]
---@param filters table
---@return table[]
function M.get_filtered_lines(raw_lines, filters)
  local result = {}
  for _, line in ipairs(raw_lines) do
    if M.matches(line.text, filters) then
      result[#result + 1] = {
        display = M.build_display_line(line.tag, line.text),
        tag = line.tag,
        text = line.text,
      }
    end
  end
  return result
end

return M
