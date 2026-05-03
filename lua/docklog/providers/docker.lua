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

---Build command to list containers with compose labels.
---@return string[]
function M.build_compose_list_cmd()
  local cmd = { "docker" }

  if Config.values.docker.host then
    cmd[#cmd + 1] = "-H"
    cmd[#cmd + 1] = Config.values.docker.host
  end

  cmd[#cmd + 1] = "ps"
  cmd[#cmd + 1] = "--filter"
  cmd[#cmd + 1] = "label=com.docker.compose.service"
  cmd[#cmd + 1] = "--format"
  cmd[#cmd + 1] = '{{json .}}'

  return cmd
end

---Parse docker ps output and group by compose service.
---@param lines string[]
---@return table<string, table[]> service_name -> list of containers
function M.parse_compose_services(lines)
  local services = {}
  for _, line in ipairs(lines) do
    local ok, data = pcall(vim.json.decode, line)
    if ok and type(data) == "table" and data.ID then
      local labels = data.Labels or ""
      local service = labels:match("com%.docker%.compose%.service=([^,]+)")
      local project = labels:match("com%.docker%.compose%.project=([^,]+)")
      if service then
        local key = project and (project .. "/" .. service) or service
        if not services[key] then
          services[key] = {
            service = service,
            project = project,
            containers = {},
          }
        end
        services[key].containers[#services[key].containers + 1] = {
          id = data.ID,
          name = data.Names,
          status = data.Status,
          image = data.Image,
          service = service,
          project = project,
        }
      end
    end
  end
  return services
end

---List compose services (grouped).
---@param callback fun(services: table[])
function M.list_compose_services(callback)
  local cmd = M.build_compose_list_cmd()
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
          vim.notify("Docker: failed to list compose services", vim.log.levels.ERROR)
          callback({})
          return
        end
        local services_map = M.parse_compose_services(stdout_lines)
        local result = {}
        for key, svc in pairs(services_map) do
          result[#result + 1] = {
            key = key,
            service = svc.service,
            project = svc.project,
            containers = svc.containers,
            count = #svc.containers,
          }
        end
        table.sort(result, function(a, b) return a.key < b.key end)
        callback(result)
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
