local M = {}

local Config = require("docklog.config")

---@return string[]
local function base_cmd()
  local cmd = { "kubectl" }
  if Config.values.k8s.kubeconfig then
    cmd[#cmd + 1] = "--kubeconfig"
    cmd[#cmd + 1] = Config.values.k8s.kubeconfig
  end
  return cmd
end

---@param target { name: string, namespace: string, container?: string }
---@return string[]
function M.build_log_cmd(target)
  local cmd = base_cmd()
  cmd[#cmd + 1] = "logs"
  cmd[#cmd + 1] = "-f"
  cmd[#cmd + 1] = "--tail=" .. tostring(Config.values.tail_lines)
  cmd[#cmd + 1] = "-n"
  cmd[#cmd + 1] = target.namespace
  cmd[#cmd + 1] = target.name

  if target.container then
    cmd[#cmd + 1] = "-c"
    cmd[#cmd + 1] = target.container
  end

  return cmd
end

---@param json_str string
---@param namespace string
---@return table[]
function M.parse_pods_json(json_str, namespace)
  local ok, data = pcall(vim.json.decode, json_str)
  if not ok or type(data) ~= "table" or not data.items then
    return {}
  end

  local targets = {}
  for _, item in ipairs(data.items) do
    local pod_name = item.metadata and item.metadata.name or "unknown"
    local pod_ns = item.metadata and item.metadata.namespace or namespace
    local phase = item.status and item.status.phase or "Unknown"
    local containers = item.spec and item.spec.containers or {}

    if #containers <= 1 then
      targets[#targets + 1] = {
        name = pod_name,
        namespace = pod_ns,
        status = phase,
        container = nil,
      }
    else
      for _, c in ipairs(containers) do
        targets[#targets + 1] = {
          name = pod_name,
          namespace = pod_ns,
          status = phase,
          container = c.name,
        }
      end
    end
  end

  return targets
end

---@param json_str string
---@return string[]
function M.parse_namespaces_json(json_str)
  local ok, data = pcall(vim.json.decode, json_str)
  if not ok or type(data) ~= "table" or not data.items then
    return {}
  end

  local namespaces = {}
  for _, item in ipairs(data.items) do
    if item.metadata and item.metadata.name then
      namespaces[#namespaces + 1] = item.metadata.name
    end
  end
  return namespaces
end

---@param namespace string
---@param callback fun(targets: table[])
function M.list_targets(namespace, callback)
  local cmd = base_cmd()
  cmd[#cmd + 1] = "get"
  cmd[#cmd + 1] = "pods"
  cmd[#cmd + 1] = "-n"
  cmd[#cmd + 1] = namespace
  cmd[#cmd + 1] = "-o"
  cmd[#cmd + 1] = "json"

  local stdout_chunks = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          stdout_chunks[#stdout_chunks + 1] = line
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.notify("kubectl: failed to list pods (check cluster connection)", vim.log.levels.ERROR)
          callback({})
          return
        end
        local json_str = table.concat(stdout_chunks, "\n")
        callback(M.parse_pods_json(json_str, namespace))
      end)
    end,
  })
end

---@param callback fun(namespaces: string[])
function M.list_namespaces(callback)
  local cmd = base_cmd()
  cmd[#cmd + 1] = "get"
  cmd[#cmd + 1] = "namespaces"
  cmd[#cmd + 1] = "-o"
  cmd[#cmd + 1] = "json"

  local stdout_chunks = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          stdout_chunks[#stdout_chunks + 1] = line
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.notify("kubectl: failed to list namespaces", vim.log.levels.ERROR)
          callback({})
          return
        end
        local json_str = table.concat(stdout_chunks, "\n")
        callback(M.parse_namespaces_json(json_str))
      end)
    end,
  })
end

---@param callback fun(namespace: string)
function M.get_current_namespace(callback)
  local cmd = base_cmd()
  cmd[#cmd + 1] = "config"
  cmd[#cmd + 1] = "view"
  cmd[#cmd + 1] = "--minify"
  cmd[#cmd + 1] = "-o"
  cmd[#cmd + 1] = "jsonpath={.contexts[0].context.namespace}"

  local stdout_chunks = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          stdout_chunks[#stdout_chunks + 1] = line
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        local ns = table.concat(stdout_chunks, "")
        if exit_code ~= 0 or ns == "" then
          ns = "default"
        end
        callback(ns)
      end)
    end,
  })
end

---@param target { name: string, container?: string }
---@return string
function M.get_tag(target)
  if target.container then
    return target.name .. "/" .. target.container
  end
  return target.name
end

---@return string
function M.type()
  return "kubernetes"
end

return M
