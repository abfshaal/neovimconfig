local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local Viewer = require("docklog.viewer")

---Create a Telescope picker for Docker containers.
function M.docker_containers()
  local docker = require("docklog.providers.docker")

  docker.list_targets(function(targets)
    if #targets == 0 then
      vim.notify("No running Docker containers found", vim.log.levels.INFO)
      return
    end

    pickers.new({}, {
      prompt_title = "Docker Containers",
      finder = finders.new_table({
        results = targets,
        entry_maker = function(target)
          return {
            value = target,
            display = string.format("%-30s %-15s %s", target.name, target.status, target.image),
            ordinal = target.name .. " " .. target.image,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Enable multi-select with Tab
        actions.select_default:replace(function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local selections = picker:get_multi_selection()

          if #selections == 0 then
            local entry = action_state.get_selected_entry()
            if entry then
              selections = { entry }
            end
          end

          actions.close(prompt_bufnr)

          local selected_targets = {}
          for _, sel in ipairs(selections) do
            selected_targets[#selected_targets + 1] = sel.value
          end

          if #selected_targets > 0 then
            Viewer.open(selected_targets, docker)
          end
        end)
        return true
      end,
    }):find()
  end)
end

---Create a Telescope picker for K8s pods.
---@param namespace? string If nil, uses current context namespace
function M.k8s_pods(namespace)
  local k8s = require("docklog.providers.kubernetes")

  local function open_picker(ns)
    k8s.list_targets(ns, function(targets)
      if #targets == 0 then
        vim.notify("No pods found in namespace: " .. ns, vim.log.levels.INFO)
        return
      end

      pickers.new({}, {
        prompt_title = "K8s Pods [" .. ns .. "]",
        finder = finders.new_table({
          results = targets,
          entry_maker = function(target)
            local display_name = target.name
            if target.container then
              display_name = target.name .. "/" .. target.container
            end
            return {
              value = target,
              display = string.format("%-40s %-10s %s", display_name, target.status, ns),
              ordinal = display_name,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            local picker = action_state.get_current_picker(prompt_bufnr)
            local selections = picker:get_multi_selection()

            if #selections == 0 then
              local entry = action_state.get_selected_entry()
              if entry then
                selections = { entry }
              end
            end

            actions.close(prompt_bufnr)

            local selected_targets = {}
            for _, sel in ipairs(selections) do
              selected_targets[#selected_targets + 1] = sel.value
            end

            if #selected_targets > 0 then
              Viewer.open(selected_targets, k8s)
            end
          end)
          return true
        end,
      }):find()
    end)
  end

  if namespace then
    open_picker(namespace)
  else
    local Config = require("docklog.config")
    local ns = Config.values.k8s.namespace
    if ns then
      open_picker(ns)
    else
      k8s.get_current_namespace(function(current_ns)
        open_picker(current_ns)
      end)
    end
  end
end

---Create a Telescope picker for K8s namespaces, then open pod picker.
function M.k8s_namespaces()
  local k8s = require("docklog.providers.kubernetes")

  k8s.list_namespaces(function(namespaces)
    if #namespaces == 0 then
      vim.notify("No namespaces found", vim.log.levels.INFO)
      return
    end

    pickers.new({}, {
      prompt_title = "K8s Namespaces",
      finder = finders.new_table({
        results = namespaces,
        entry_maker = function(ns)
          return {
            value = ns,
            display = ns,
            ordinal = ns,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry then
            M.k8s_pods(entry.value)
          end
        end)
        return true
      end,
    }):find()
  end)
end

---Add more targets to an existing log buffer.
---@param buf number
---@param provider table
function M.add_to_buffer(buf, provider)
  local provider_type = provider.type()

  if provider_type == "docker" then
    local docker = require("docklog.providers.docker")
    docker.list_targets(function(targets)
      if #targets == 0 then
        vim.notify("No running Docker containers found", vim.log.levels.INFO)
        return
      end

      pickers.new({}, {
        prompt_title = "Add Docker Container",
        finder = finders.new_table({
          results = targets,
          entry_maker = function(target)
            return {
              value = target,
              display = string.format("%-30s %-15s %s", target.name, target.status, target.image),
              ordinal = target.name .. " " .. target.image,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            local picker = action_state.get_current_picker(prompt_bufnr)
            local selections = picker:get_multi_selection()

            if #selections == 0 then
              local entry = action_state.get_selected_entry()
              if entry then
                selections = { entry }
              end
            end

            actions.close(prompt_bufnr)

            for _, sel in ipairs(selections) do
              Viewer.add_target(buf, sel.value, docker)
            end
          end)
          return true
        end,
      }):find()
    end)
  elseif provider_type == "kubernetes" then
    local k8s = require("docklog.providers.kubernetes")
    local Config = require("docklog.config")
    local ns = Config.values.k8s.namespace

    local function do_add(target_ns)
      k8s.list_targets(target_ns, function(targets)
        if #targets == 0 then
          vim.notify("No pods found in namespace: " .. target_ns, vim.log.levels.INFO)
          return
        end

        pickers.new({}, {
          prompt_title = "Add K8s Pod [" .. target_ns .. "]",
          finder = finders.new_table({
            results = targets,
            entry_maker = function(target)
              local display_name = target.name
              if target.container then
                display_name = target.name .. "/" .. target.container
              end
              return {
                value = target,
                display = string.format("%-40s %-10s", display_name, target.status),
                ordinal = display_name,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              local picker = action_state.get_current_picker(prompt_bufnr)
              local selections = picker:get_multi_selection()

              if #selections == 0 then
                local entry = action_state.get_selected_entry()
                if entry then
                  selections = { entry }
                end
              end

              actions.close(prompt_bufnr)

              for _, sel in ipairs(selections) do
                Viewer.add_target(buf, sel.value, k8s)
              end
            end)
            return true
          end,
        }):find()
      end)
    end

    if ns then
      do_add(ns)
    else
      k8s.get_current_namespace(function(current_ns)
        do_add(current_ns)
      end)
    end
  end
end

return M
