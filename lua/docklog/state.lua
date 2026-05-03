local M = {}

local Config = require("docklog.config")

---@class docklog.Filters
---@field keyword? string
---@field level? string

---@class docklog.RawLine
---@field tag string
---@field text string

---@class docklog.Target
---@field name string
---@field tag string
---@field provider_type string
---@field ended boolean

---@class docklog.Session
---@field buf_id number
---@field jobs table<number, number>
---@field raw_lines docklog.RawLine[]
---@field filters docklog.Filters
---@field targets docklog.Target[]
---@field follow_mode boolean

---@type table<number, docklog.Session>
local sessions = {}

---@param buf_id number
---@return docklog.Session
function M.create_session(buf_id)
  local session = {
    buf_id = buf_id,
    jobs = {},
    raw_lines = {},
    filters = {
      keyword = nil,
      level = nil,
    },
    targets = {},
    follow_mode = true,
  }
  sessions[buf_id] = session
  return session
end

---@param buf_id number
---@return docklog.Session|nil
function M.get_session(buf_id)
  return sessions[buf_id]
end

---@param buf_id number
---@param tag string
---@param text string
function M.add_line(buf_id, tag, text)
  local session = sessions[buf_id]
  if not session then return end

  session.raw_lines[#session.raw_lines + 1] = {
    tag = tag,
    text = text,
  }

  local max = Config.values.max_lines
  if #session.raw_lines > max then
    local overflow = #session.raw_lines - max
    local trimmed = {}
    for i = overflow + 1, #session.raw_lines do
      trimmed[#trimmed + 1] = session.raw_lines[i]
    end
    session.raw_lines = trimmed
  end
end

---@param buf_id number
function M.remove_session(buf_id)
  sessions[buf_id] = nil
end

---@return table<number, docklog.Session>
function M.all_sessions()
  return sessions
end

return M
