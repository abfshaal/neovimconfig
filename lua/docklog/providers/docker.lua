local M = {}

local Config = require("docklog.config")

---@param target { id: string, name: string }
---@return string[]
function M.build_log_cmd(target)
  local cmd = { "docker" }

  if Config.values.docker.host then
    cmd[#cmd + 1] = "-H"
    cmd[#cmd + 1] = Config.values.docker.host
  end

  cmd[#cmd + 1] = "logs"
  cmd[#cmd + 1] = "-f"
  cmd[#cmd + 1] = "--tail"
  cmd[#cmd + 1] = tostring(Config.values.tail_lines)
  cmd[#cmd + 1] = target.id

  return cmd
end

---@return string[]
function M.build_list_cmd()
  local cmd = { "docker" }

  if Config.values.docker.host then
    cmd[#cmd + 1] = "-H"
    cmd[#cmd + 1] = Config.values.docker.host
  end

  cmd[#cmd + 1] = "ps"
  cmd[#cmd + 1] = "--format"
  cmd[#cmd + 1] = '{{json .}}'

  return cmd
end

---@param lines string[]
---@return table[]
function M.parse_ps_output(lines)
  local targets = {}
  for _, line in ipairs(lines) do
    local ok, data = pcall(vim.json.decode, line)
    if ok and type(data) == "table" and data.ID then
      targets[#targets + 1] = {
        id = data.ID,
        name = data.Names,
        status = data.Status,
        image = data.Image,
      }
    end
  end
  return targets
end

---@param callback fun(targets: table[])
function M.list_targets(callback)
  local cmd = M.build_list_cmd()
  local stdout_lines = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          stdout_lines[#stdout_lines + 1] = line
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.notify("Docker: failed to list containers (is Docker running?)", vim.log.levels.ERROR)
          callback({})
          return
        end
        callback(M.parse_ps_output(stdout_lines))
      end)
    end,
  })
end

---@param target { name: string }
---@return string
function M.get_tag(target)
  return target.name
end

---@return string
function M.type()
  return "docker"
end

return M
