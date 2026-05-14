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

local pod_cache = {}

local PODS_JSONPATH =
  [[jsonpath={range .items[*]}{.metadata.name}{"\t"}{.metadata.namespace}{"\t"}{.status.phase}{"\t"}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}]]

local function now_ms()
  return (vim.uv or vim.loop).now()
end

local function cache_key(namespace, label_selector)
  local kubeconfig = Config.values.k8s.kubeconfig or vim.env.KUBECONFIG or ""
  return table.concat({ kubeconfig, namespace, label_selector or "" }, "\0")
end

local function cache_ttl_ms()
  return Config.values.k8s.pod_cache_ttl_ms or 0
end

local function copy_targets(targets)
  return vim.deepcopy(targets)
end

local function get_cached_targets(namespace, label_selector)
  local ttl = cache_ttl_ms()
  if ttl <= 0 then
    return nil
  end

  local cached = pod_cache[cache_key(namespace, label_selector)]
  if not cached or (now_ms() - cached.time) > ttl then
    return nil
  end

  return copy_targets(cached.targets)
end

local function set_cached_targets(namespace, label_selector, targets)
  local ttl = cache_ttl_ms()
  if ttl <= 0 then
    return
  end

  pod_cache[cache_key(namespace, label_selector)] = {
    time = now_ms(),
    targets = copy_targets(targets),
  }
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

---@param namespace string
---@param label_selector? string
---@return string[]
function M.build_pod_list_cmd(namespace, label_selector)
  local cmd = base_cmd()
  cmd[#cmd + 1] = "get"
  cmd[#cmd + 1] = "pods"
  cmd[#cmd + 1] = "-n"
  cmd[#cmd + 1] = namespace
  if label_selector and label_selector ~= "" then
    cmd[#cmd + 1] = "-l"
    cmd[#cmd + 1] = label_selector
  end
  cmd[#cmd + 1] = "-o"
  cmd[#cmd + 1] = PODS_JSONPATH
  return cmd
end

---@param lines string[]
---@param namespace string
---@return table[]
function M.parse_pods_lines(lines, namespace)
  local targets = {}

  for _, line in ipairs(lines) do
    if line ~= "" then
      local name, ns, phase, containers_str = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
      if name and name ~= "" then
        ns = ns ~= "" and ns or namespace
        phase = phase ~= "" and phase or "Unknown"

        local containers = {}
        for container in tostring(containers_str or ""):gmatch("([^,]+)") do
          containers[#containers + 1] = container
        end

        if #containers <= 1 then
          targets[#targets + 1] = {
            name = name,
            namespace = ns,
            status = phase,
            container = nil,
          }
        else
          for _, container in ipairs(containers) do
            targets[#targets + 1] = {
              name = name,
              namespace = ns,
              status = phase,
              container = container,
            }
          end
        end
      end
    end
  end

  return targets
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
  local cached = get_cached_targets(namespace)
  if cached then
    vim.schedule(function()
      callback(cached)
    end)
    return
  end

  local cmd = M.build_pod_list_cmd(namespace)
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
        local targets = M.parse_pods_lines(stdout_chunks, namespace)
        set_cached_targets(namespace, nil, targets)
        callback(targets)
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

---Parse kubectl get deployments JSON output.
---@param json_str string
---@param namespace string
---@return table[]
function M.parse_deployments_json(json_str, namespace)
  local ok, data = pcall(vim.json.decode, json_str)
  if not ok or type(data) ~= "table" or not data.items then
    return {}
  end

  local deployments = {}
  for _, item in ipairs(data.items) do
    local name = item.metadata and item.metadata.name or "unknown"
    local ns = item.metadata and item.metadata.namespace or namespace
    local replicas = item.status and item.status.readyReplicas or 0
    local desired = item.spec and item.spec.replicas or 0

    -- Extract matchLabels for pod selection
    local match_labels = {}
    if item.spec and item.spec.selector and item.spec.selector.matchLabels then
      match_labels = item.spec.selector.matchLabels
    end

    deployments[#deployments + 1] = {
      name = name,
      namespace = ns,
      replicas = replicas,
      desired = desired,
      match_labels = match_labels,
    }
  end
  return deployments
end

---List deployments in a namespace.
---@param namespace string
---@param callback fun(deployments: table[])
function M.list_deployments(namespace, callback)
  local cmd = base_cmd()
  cmd[#cmd + 1] = "get"
  cmd[#cmd + 1] = "deployments"
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
          vim.notify("kubectl: failed to list deployments", vim.log.levels.ERROR)
          callback({})
          return
        end
        local json_str = table.concat(stdout_chunks, "\n")
        callback(M.parse_deployments_json(json_str, namespace))
      end)
    end,
  })
end

---List pods matching a label selector in a namespace.
---@param namespace string
---@param label_selector string e.g. "app=my-service"
---@param callback fun(targets: table[])
function M.list_targets_by_label(namespace, label_selector, callback)
  local cached = get_cached_targets(namespace, label_selector)
  if cached then
    vim.schedule(function()
      callback(cached)
    end)
    return
  end

  local cmd = M.build_pod_list_cmd(namespace, label_selector)
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
          vim.notify("kubectl: failed to list pods with label " .. label_selector, vim.log.levels.ERROR)
          callback({})
          return
        end
        local targets = M.parse_pods_lines(stdout_chunks, namespace)
        set_cached_targets(namespace, label_selector, targets)
        callback(targets)
      end)
    end,
  })
end

---Convert matchLabels table to a label selector string.
---@param match_labels table<string, string>
---@return string
function M.labels_to_selector(match_labels)
  local parts = {}
  for k, v in pairs(match_labels) do
    parts[#parts + 1] = k .. "=" .. v
  end
  table.sort(parts)
  return table.concat(parts, ",")
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
