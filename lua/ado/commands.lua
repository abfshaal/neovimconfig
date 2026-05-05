local M = {}

local Client = require("ado.client")
local State = require("ado.state")
local Util = require("ado.util")
local Select = require("ado.ui.select")
local Buffer = require("ado.ui.buffer")

local function ensure_project(cb)
  if State.values.project and State.values.project ~= "" then
    return cb(State.values.project)
  end
  M.pick_project(function(project)
    if project then
      cb(project)
    end
  end)
end

local function ensure_repo(cb)
  if State.values.repo and State.values.repo.id then
    return cb(State.values.repo)
  end
  M.pick_repo(function(repo)
    if repo then
      cb(repo)
    end
  end)
end

local function ensure_team(cb)
  if State.values.team and State.values.team ~= "" then
    return cb(State.values.team)
  end
  M.pick_team(function(team)
    if team then
      cb(team)
    end
  end)
end

function M.pick_project(cb)
  Util.ensure_configured_or_prompt(function()
    Client.list_projects(function(err, projects)
      if err then
        return Util.notify(err.message, vim.log.levels.ERROR)
      end

      Select.select(projects, {
        prompt = "Select ADO Project",
        format_item = function(p)
          return p.name
        end,
      }, function(choice)
        if not choice then
          return cb(nil)
        end
        State.values.project = choice.name
        State.values.team = nil
        State.values.repo = nil
        State.save()
        Util.notify("Project set: " .. choice.name)
        cb(choice.name)
      end)
    end)
  end)
end

function M.pick_repo(cb)
  ensure_project(function(project)
    Client.list_repos(project, function(err, repos)
      if err then
        return Util.notify(err.message, vim.log.levels.ERROR)
      end
      Select.select(repos, {
        prompt = string.format("Select Repo (%s)", project),
        format_item = function(r)
          return r.name
        end,
      }, function(choice)
        if not choice then
          return cb(nil)
        end
        State.values.repo = { id = choice.id, name = choice.name, remoteUrl = choice.remoteUrl }
        State.save()
        Util.notify("Repo set: " .. choice.name)
        cb(State.values.repo)
      end)
    end)
  end)
end

function M.pick_team(cb)
  ensure_project(function(project)
    Client.list_teams(project, function(err, teams)
      if err then
        Util.notify("Unable to list teams; falling back to project name as team", vim.log.levels.WARN)
        State.values.team = project
        State.save()
        return cb(project)
      end
      Select.select(teams, {
        prompt = string.format("Select Team (%s)", project),
        format_item = function(t)
          return t.name
        end,
      }, function(choice)
        if not choice then
          return cb(nil)
        end
        State.values.team = choice.name
        State.save()
        Util.notify("Team set: " .. choice.name)
        cb(choice.name)
      end)
    end)
  end)
end

function M.prs()
  Util.ensure_configured_or_prompt(function()
    ensure_project(function(project)
      ensure_repo(function(repo)
        Client.list_pull_requests(project, repo.id, "active", function(err, prs)
          if err then
            return Util.notify(err.message, vim.log.levels.ERROR)
          end

          Select.select(prs, {
            prompt = string.format("PRs (%s/%s)", project, repo.name),
            format_item = function(pr)
              local author = (pr.createdBy and pr.createdBy.displayName) or ""
              return string.format("#%s %s — %s", tostring(pr.pullRequestId), pr.title or "", author)
            end,
          }, function(pr)
            if not pr then
              return
            end
            M.pr_menu(pr)
          end)
        end)
      end)
    end)
  end)
end

function M.pr_menu(pr)
  local items = {
    { id = "open", label = "Open in browser" },
    { id = "details", label = "Show details + threads" },
    { id = "approve", label = "Approve (vote=10)" },
    { id = "approve_suggest", label = "Approve with suggestions (vote=5)" },
    { id = "reject", label = "Request changes (vote=-10)" },
    { id = "comment", label = "Comment (new thread)" },
  }

  Select.select(items, {
    prompt = string.format("PR #%s", tostring(pr.pullRequestId)),
    format_item = function(i)
      return i.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.id == "open" then
      return M.pr_open(pr)
    end
    if choice.id == "details" then
      return M.pr_details(pr)
    end
    if choice.id == "comment" then
      return M.pr_comment(pr)
    end
    if choice.id == "approve" then
      return M.pr_vote(pr, 10)
    end
    if choice.id == "approve_suggest" then
      return M.pr_vote(pr, 5)
    end
    if choice.id == "reject" then
      return M.pr_vote(pr, -10)
    end
  end)
end

function M.pr_open(pr)
  local url = pr._links and pr._links.web and pr._links.web.href
  if not url then
    return Util.notify("PR web URL not found in response", vim.log.levels.ERROR)
  end
  vim.ui.open(url)
end

function M.pr_details(pr)
  ensure_project(function(project)
    ensure_repo(function(repo)
      Client.get_pull_request(project, repo.id, pr.pullRequestId, function(err, full)
        if err then
          return Util.notify(err.message, vim.log.levels.ERROR)
        end
        Client.list_threads(project, repo.id, pr.pullRequestId, function(err2, threads)
          if err2 then
            return Util.notify(err2.message, vim.log.levels.ERROR)
          end
          local lines = Buffer.render_pr(full, threads)
          Buffer.show_lines(string.format("ado-pr-%s", tostring(pr.pullRequestId)), lines)
        end)
      end)
    end)
  end)
end

function M.pr_vote(pr, vote)
  ensure_project(function(project)
    ensure_repo(function(repo)
      Client.get_me(function(err, me)
        if err then
          return Util.notify(err.message, vim.log.levels.ERROR)
        end
        Client.set_reviewer_vote(project, repo.id, pr.pullRequestId, me.id, vote, function(err2)
          if err2 then
            return Util.notify(err2.message, vim.log.levels.ERROR)
          end
          Util.notify(string.format("Set vote=%s on PR #%s", tostring(vote), tostring(pr.pullRequestId)))
        end)
      end)
    end)
  end)
end

function M.pr_comment(pr)
  vim.ui.input({ prompt = "Comment: " }, function(content)
    content = content and Util.trim(content) or nil
    if not content or content == "" then
      return
    end

    ensure_project(function(project)
      ensure_repo(function(repo)
        Client.create_pr_comment_thread(project, repo.id, pr.pullRequestId, content, function(err)
          if err then
            return Util.notify(err.message, vim.log.levels.ERROR)
          end
          Util.notify("Comment posted")
        end)
      end)
    end)
  end)
end

function M.my_work()
  Util.ensure_configured_or_prompt(function()
    ensure_project(function(project)
      ensure_team(function(team)
        local wiql = [[
SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType]
FROM workitems
WHERE
  [System.TeamProject] = @project
  AND [System.AssignedTo] = @Me
ORDER BY [System.ChangedDate] DESC
        ]]

        Client.query_wiql(project, team, wiql, function(err, result)
          if err then
            return Util.notify(err.message, vim.log.levels.ERROR)
          end
          local work_items = (result and result.workItems) or {}
          local ids = {}
          for _, wi in ipairs(work_items) do
            ids[#ids + 1] = wi.id
          end

          Client.get_work_items(project, ids, {
            "System.Title",
            "System.State",
            "System.WorkItemType",
          }, function(err2, items)
            if err2 then
              return Util.notify(err2.message, vim.log.levels.ERROR)
            end
            local lines = Buffer.render_work_items(items)
            Buffer.show_lines("ado-my-work", lines)
          end)
        end)
      end)
    end)
  end)
end

function M.sprints()
  Util.ensure_configured_or_prompt(function()
    ensure_project(function(project)
      ensure_team(function(team)
        Client.list_team_iterations(project, team, "current", function(err, iterations)
          if err then
            return Util.notify(err.message, vim.log.levels.ERROR)
          end
          local lines = { string.format("# Current Iterations (%s/%s)", project, team), "" }
          for _, it in ipairs(iterations) do
            lines[#lines + 1] = string.format("- %s (%s .. %s)", it.name or "", it.attributes and it.attributes.startDate or "", it.attributes and it.attributes.finishDate or "")
          end
          if #iterations == 0 then
            lines[#lines + 1] = "(none)"
          end
          Buffer.show_lines("ado-sprints", lines)
        end)
      end)
    end)
  end)
end

function M.backlogs()
  Util.ensure_configured_or_prompt(function()
    ensure_project(function(project)
      ensure_team(function(team)
        Client.list_backlogs(project, team, function(err, backlogs)
          if err then
            return Util.notify(err.message, vim.log.levels.ERROR)
          end

          Select.select(backlogs, {
            prompt = string.format("Backlogs (%s/%s)", project, team),
            format_item = function(b)
              return b.name or b.id or "backlog"
            end,
          }, function(backlog)
            if not backlog then
              return
            end

            Client.get_backlog_level_work_items(project, team, backlog.id, function(err2, links)
              if err2 then
                return Util.notify(err2.message, vim.log.levels.ERROR)
              end

              local ids = {}
              for _, link in ipairs(links or {}) do
                local target = link.target or {}
                if target.id then
                  ids[#ids + 1] = target.id
                end
              end

              Client.get_work_items(project, ids, {
                "System.Title",
                "System.State",
                "System.WorkItemType",
              }, function(err3, items)
                if err3 then
                  return Util.notify(err3.message, vim.log.levels.ERROR)
                end

                local lines = Buffer.render_backlog(backlog.name or backlog.id or "Backlog", items)
                Buffer.show_lines("ado-backlog", lines)

                if #items > 0 then
                  Select.select(items, {
                    prompt = "Open work item",
                    format_item = function(wi)
                      local fields = wi.fields or {}
                      return string.format("#%s %s", tostring(wi.id), fields["System.Title"] or "")
                    end,
                  }, function(wi)
                    if not wi then
                      return
                    end
                    local base = require("ado.config").values.org_url
                    local url = base .. "/" .. project .. "/_workitems/edit/" .. tostring(wi.id)
                    vim.ui.open(url)
                  end)
                end
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end

function M.health()
  Util.ensure_configured_or_prompt(function()
    Client.list_projects(function(err, projects)
      if err then
        return Util.notify("Health check failed: " .. err.message, vim.log.levels.ERROR)
      end
      Util.notify("Health check OK (projects=" .. tostring(#projects) .. ")")
    end)
  end)
end

function M.main_menu()
  local items = {
    { id = "projects", label = "Switch project" },
    { id = "repos", label = "Switch repo" },
    { id = "teams", label = "Switch team" },
    { id = "prs", label = "Pull requests" },
    { id = "mywork", label = "My work items" },
    { id = "sprints", label = "Current sprint/iterations" },
    { id = "backlogs", label = "Backlogs" },
    { id = "repo_open", label = "Open repo in browser" },
    { id = "health", label = "Health check" },
  }

  Select.select(items, {
    prompt = "Azure DevOps",
    format_item = function(i)
      return i.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.id == "projects" then
      return M.pick_project(function() end)
    end
    if choice.id == "repos" then
      return M.pick_repo(function() end)
    end
    if choice.id == "teams" then
      return M.pick_team(function() end)
    end
    if choice.id == "prs" then
      return M.prs()
    end
    if choice.id == "mywork" then
      return M.my_work()
    end
    if choice.id == "sprints" then
      return M.sprints()
    end
    if choice.id == "backlogs" then
      return M.backlogs()
    end
    if choice.id == "repo_open" then
      if State.values.repo and State.values.repo.remoteUrl then
        return vim.ui.open(State.values.repo.remoteUrl)
      end
      Util.notify("No repo selected", vim.log.levels.WARN)
      return
    end
    if choice.id == "health" then
      return M.health()
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("Ado", function()
    require("ado.ui.app").open()
  end, { desc = "Azure DevOps UI" })

  vim.api.nvim_create_user_command("AdoMenu", function()
    M.main_menu()
  end, { desc = "Azure DevOps picker menu" })

  vim.api.nvim_create_user_command("AdoUI", function()
    require("ado.ui.app").open()
  end, { desc = "Azure DevOps UI" })

  vim.api.nvim_create_user_command("AdoProjects", function()
    M.pick_project(function() end)
  end, { desc = "Select Azure DevOps project" })

  vim.api.nvim_create_user_command("AdoRepos", function()
    M.pick_repo(function() end)
  end, { desc = "Select Azure DevOps repo" })

  vim.api.nvim_create_user_command("AdoTeam", function()
    M.pick_team(function() end)
  end, { desc = "Select Azure DevOps team" })

  vim.api.nvim_create_user_command("AdoPrs", function()
    M.prs()
  end, { desc = "List Azure DevOps pull requests" })

  vim.api.nvim_create_user_command("AdoMyWork", function()
    M.my_work()
  end, { desc = "Show work items assigned to me" })

  vim.api.nvim_create_user_command("AdoSprints", function()
    M.sprints()
  end, { desc = "Show current iterations" })

  vim.api.nvim_create_user_command("AdoBacklogs", function()
    M.backlogs()
  end, { desc = "Browse team backlogs" })

  vim.api.nvim_create_user_command("AdoHealth", function()
    M.health()
  end, { desc = "Azure DevOps health check" })

  vim.api.nvim_create_user_command("AdoAuthClear", function()
    local Config = require("ado.config")
    local Secret = require("ado.secret")
    if not Secret.supported() then
      return Util.notify("Keychain not supported on this system", vim.log.levels.WARN)
    end
    if not Config.values.org_url or Config.values.org_url == "" then
      return Util.notify("No org URL configured", vim.log.levels.WARN)
    end
    Secret.delete(Config.values.keychain_service, Config.values.org_url, function(ok, err)
      if not ok then
        return Util.notify("Failed to delete Keychain entry: " .. tostring(err), vim.log.levels.ERROR)
      end
      Config.values.pat = nil
      Util.notify("Deleted PAT from Keychain")
    end)
  end, { desc = "Clear saved PAT from Keychain" })
end

return M
