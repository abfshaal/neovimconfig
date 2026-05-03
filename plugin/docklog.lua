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
