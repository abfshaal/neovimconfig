if vim.g.loaded_docklog then
  return
end
vim.g.loaded_docklog = true

vim.api.nvim_create_user_command("DocklogDocker", function()
  require("docklog.picker").docker_containers()
end, { desc = "Docklog: pick Docker containers and view logs" })

vim.api.nvim_create_user_command("DocklogKube", function()
  require("docklog.picker").k8s_pods()
end, { desc = "Docklog: pick K8s pods and view logs" })

vim.api.nvim_create_user_command("DocklogKubeNs", function()
  require("docklog.picker").k8s_namespaces()
end, { desc = "Docklog: pick K8s namespace then pods" })

vim.api.nvim_create_user_command("DocklogCompose", function()
  require("docklog.picker").docker_compose()
end, { desc = "Docklog: pick Docker Compose services and view logs" })

vim.api.nvim_create_user_command("DocklogKubeDeploy", function()
  require("docklog.picker").k8s_deployments()
end, { desc = "Docklog: pick K8s deployment, auto-expand to pods" })

vim.api.nvim_create_user_command("DocklogKubeLabel", function(opts)
  if opts.args and opts.args ~= "" then
    local k8s = require("docklog.providers.kubernetes")
    local Config = require("docklog.config")
    local ns = Config.values.k8s.namespace
    local function do_query(namespace)
      k8s.list_targets_by_label(namespace, opts.args, function(targets)
        if #targets == 0 then
          vim.notify("No pods match label: " .. opts.args, vim.log.levels.INFO)
          return
        end
        require("docklog.viewer").open(targets, k8s)
      end)
    end
    if ns then
      do_query(ns)
    else
      k8s.get_current_namespace(function(current_ns)
        do_query(current_ns)
      end)
    end
  else
    require("docklog.picker").k8s_label()
  end
end, { nargs = "?", desc = "Docklog: pick K8s pods by label selector" })

vim.api.nvim_create_user_command("DocklogFollow", function()
  local state = require("docklog.state")
  local viewer = require("docklog.viewer")
  local buf = vim.api.nvim_get_current_buf()
  if state.get_session(buf) then
    viewer.toggle_follow(buf)
  end
end, { desc = "Docklog: toggle follow/pause" })

vim.api.nvim_create_user_command("DocklogFilter", function(opts)
  local state = require("docklog.state")
  local viewer = require("docklog.viewer")
  local buf = vim.api.nvim_get_current_buf()
  if state.get_session(buf) then
    if opts.args and opts.args ~= "" then
      viewer.set_keyword_filter(buf, opts.args)
    else
      vim.ui.input({ prompt = "Filter keyword: " }, function(input)
        if input and input ~= "" then
          viewer.set_keyword_filter(buf, input)
        end
      end)
    end
  end
end, { nargs = "?", desc = "Docklog: set keyword filter" })

vim.api.nvim_create_user_command("DocklogLevel", function(opts)
  local state = require("docklog.state")
  local viewer = require("docklog.viewer")
  local buf = vim.api.nvim_get_current_buf()
  if state.get_session(buf) then
    if opts.args and opts.args ~= "" then
      viewer.set_level_filter(buf, opts.args)
    else
      vim.ui.select(
        { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "CRITICAL" },
        { prompt = "Minimum log level:" },
        function(choice)
          if choice then
            viewer.set_level_filter(buf, choice)
          end
        end
      )
    end
  end
end, { nargs = "?", desc = "Docklog: set log level filter" })

vim.api.nvim_create_user_command("DocklogClear", function()
  local state = require("docklog.state")
  local viewer = require("docklog.viewer")
  local buf = vim.api.nvim_get_current_buf()
  if state.get_session(buf) then
    viewer.clear_filters(buf)
  end
end, { desc = "Docklog: clear all filters" })

vim.api.nvim_create_user_command("DocklogStop", function()
  local state = require("docklog.state")
  local viewer = require("docklog.viewer")
  local buf = vim.api.nvim_get_current_buf()
  if state.get_session(buf) then
    viewer.close(buf)
  end
end, { desc = "Docklog: stop streams and close" })

vim.api.nvim_create_user_command("DocklogAdd", function()
  local state = require("docklog.state")
  local picker = require("docklog.picker")
  local buf = vim.api.nvim_get_current_buf()
  local session = state.get_session(buf)
  if session then
    local provider_type = session.targets[1] and session.targets[1].provider_type
    if provider_type == "docker" then
      picker.add_to_buffer(buf, require("docklog.providers.docker"))
    elseif provider_type == "kubernetes" then
      picker.add_to_buffer(buf, require("docklog.providers.kubernetes"))
    end
  end
end, { desc = "Docklog: add another target to current buffer" })

vim.api.nvim_create_user_command("DocklogSessions", function()
  require("docklog.picker").docklog_sessions()
end, { desc = "Docklog: pick from active log sessions" })
