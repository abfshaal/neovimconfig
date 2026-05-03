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
      attach_mappings = function(prompt_bufnr, _)
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
        attach_mappings = function(prompt_bufnr, _)
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
      attach_mappings = function(prompt_bufnr, _)
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

---Create a Telescope picker for K8s Deployments, auto-expand to pods.
---@param namespace? string
function M.k8s_deployments(namespace)
  local k8s = require("docklog.providers.kubernetes")

  local function open_picker(ns)
    k8s.list_deployments(ns, function(deployments)
      if #deployments == 0 then
        vim.notify("No deployments found in namespace: " .. ns, vim.log.levels.INFO)
        return
      end

      pickers.new({}, {
        prompt_title = "K8s Deployments [" .. ns .. "]",
        finder = finders.new_table({
          results = deployments,
          entry_maker = function(dep)
            return {
              value = dep,
              display = string.format("%-35s %d/%d ready   %s",
                dep.name, dep.replicas or 0, dep.desired or 0, ns),
              ordinal = dep.name,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if entry then
              local dep = entry.value
              if not dep.match_labels or vim.tbl_isempty(dep.match_labels) then
                vim.notify("Deployment " .. dep.name .. " has no selector labels", vim.log.levels.WARN)
                return
              end
              local selector = k8s.labels_to_selector(dep.match_labels)
              k8s.list_targets_by_label(dep.namespace, selector, function(targets)
                if #targets == 0 then
                  vim.notify("No pods found for deployment " .. dep.name, vim.log.levels.INFO)
                  return
                end
                Viewer.open(targets, k8s)
              end)
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

---Prompt for a K8s label selector, then open matching pods.
---@param namespace? string
function M.k8s_label(namespace)
  local k8s = require("docklog.providers.kubernetes")

  local function do_query(ns)
    vim.ui.input({ prompt = "Label selector (e.g. app=my-service): " }, function(input)
      if not input or input == "" then return end
      k8s.list_targets_by_label(ns, input, function(targets)
        if #targets == 0 then
          vim.notify("No pods match label: " .. input .. " in " .. ns, vim.log.levels.INFO)
          return
        end

        pickers.new({}, {
          prompt_title = "Pods [" .. input .. "]",
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
          attach_mappings = function(prompt_bufnr, _)
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
    end)
  end

  if namespace then
    do_query(namespace)
  else
    local Config = require("docklog.config")
    local ns = Config.values.k8s.namespace
    if ns then
      do_query(ns)
    else
      k8s.get_current_namespace(function(current_ns)
        do_query(current_ns)
      end)
    end
  end
end

---Create a Telescope picker for Docker Compose services.
---Selecting a service opens all its containers in one interleaved buffer.
function M.docker_compose()
  local docker = require("docklog.providers.docker")

  docker.list_compose_services(function(services)
    if #services == 0 then
      vim.notify("No Docker Compose services found", vim.log.levels.INFO)
      return
    end

    pickers.new({}, {
      prompt_title = "Docker Compose Services",
      finder = finders.new_table({
        results = services,
        entry_maker = function(svc)
          return {
            value = svc,
            display = string.format("%-25s %-15s %d container(s)",
              svc.service, svc.project or "", svc.count),
            ordinal = svc.key,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
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

          -- Collect all containers from all selected services
          local all_targets = {}
          for _, sel in ipairs(selections) do
            for _, container in ipairs(sel.value.containers) do
              all_targets[#all_targets + 1] = container
            end
          end

          if #all_targets > 0 then
            Viewer.open(all_targets, docker)
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
        attach_mappings = function(prompt_bufnr, _)
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
          attach_mappings = function(prompt_bufnr, _)
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
