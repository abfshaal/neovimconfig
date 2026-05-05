local M = {}

local Client = require("ado.client")
local Config = require("ado.config")
local Git = require("ado.git")
local State = require("ado.state")
local Util = require("ado.util")
local BufferRender = require("ado.ui.buffer")

local NAV = {
  { id = "prs", label = "PRs" },
  { id = "mywork", label = "My Work" },
  { id = "backlogs", label = "Backlogs" },
  { id = "sprints", label = "Sprints" },
  { id = "repos", label = "Repos" },
  { id = "projects", label = "Projects" },
  { id = "teams", label = "Teams" },
}

local function scratch_buf(name, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft or "markdown"
  return buf
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function header_line(state)
  local org = Config.values.org_url or "(org?)"
  local project = State.values.project or "(project?)"
  local repo = (State.values.repo and State.values.repo.name) or "(repo?)"
  local team = State.values.team or "(team?)"
  return string.format("ADO: %s  Project:%s  Repo:%s  Team:%s", org, project, repo, team)
end

local function ui_winbar(state)
  return header_line(state) .. "  |  q quit  ? help  tab switch  p project  r repo  t team  R refresh"
end

local function fmt_pr(pr)
  local author = (pr.createdBy and pr.createdBy.displayName) or ""
  return string.format("#%s %s  (%s)", tostring(pr.pullRequestId), pr.title or "", author)
end

local function fmt_work_item(wi)
  local fields = wi.fields or {}
  return string.format("#%s %s", tostring(wi.id), fields["System.Title"] or "")
end

---@class ado.ui.AppState
---@field tab integer|nil
---@field bufs { nav: integer, list: integer, details: integer }
---@field wins { nav: integer, list: integer, details: integer }
---@field focus 'nav'|'list'|'details'
---@field nav_index integer
---@field list_index integer
---@field nav_items table[]
---@field list_items any[]
---@field cache table
---@field detail_timer integer|nil
local S = {
  tab = nil,
  bufs = { nav = -1, list = -1, details = -1 },
  wins = { nav = -1, list = -1, details = -1 },
  focus = "list",
  nav_index = 1,
  list_index = 1,
  last_nav_id = nil,
  nav_items = NAV,
  list_items = {},
  cache = {
    projects = nil,
    repos_by_project = {},
    teams_by_project = {},
    prs_by_repo = {},
    backlogs_by_team = {},
    work_item_details = {},
  },
  detail_timer = nil,
  backlogs_mode = "backlogs", -- 'backlogs' | 'items' | 'links'
  selected_backlog = nil,
  links_source_id = nil,
  view_stack = {},
  work_item_filter = nil, -- substring filter on assignee (case-insensitive)
  list_items_all = nil, -- unfiltered items for work-item lists
}

-- Forward declarations (used by helpers defined above their bodies).
local current_nav
local current_item
local render_list
local refresh_details

local function clamp_list_index()
  if S.list_index < 1 then
    S.list_index = 1
  end
  local max = #S.list_items
  if max == 0 then
    S.list_index = 1
    return
  end
  if S.list_index > max then
    S.list_index = max
  end
end

local function work_item_assignee(it)
  local fields = (it and it.fields) or {}
  local assigned = fields["System.AssignedTo"]
  if type(assigned) == "table" then
    return assigned.displayName or assigned.uniqueName or assigned.name or ""
  end
  return assigned or ""
end

local function apply_work_item_filter(items)
  if not S.work_item_filter or S.work_item_filter == "" then
    return items
  end
  local needle = string.lower(S.work_item_filter)
  local out = {}
  for _, it in ipairs(items or {}) do
    local a = string.lower(work_item_assignee(it) or "")
    if a:find(needle, 1, true) then
      out[#out + 1] = it
    end
  end
  return out
end

local function is_work_item_list_context()
  local nav = current_nav and current_nav() and current_nav().id
  if nav == "mywork" then
    return true
  end
  if nav == "backlogs" and S.backlogs_mode ~= "backlogs" then
    return true
  end
  return false
end

local function list_render_info(nav)
  if nav == "projects" then
    return "PROJECTS", function(p)
      return p.name
    end
  end
  if nav == "repos" then
    return "REPOS", function(r)
      return r.name
    end
  end
  if nav == "teams" then
    return "TEAMS", function(t)
      return t.name
    end
  end
  if nav == "prs" then
    return "PRS", fmt_pr
  end
  if nav == "mywork" then
    return "MY WORK", fmt_work_item
  end
  if nav == "sprints" then
    return "SPRINTS", function(it)
      return it.name or ""
    end
  end
  if nav == "backlogs" then
    if S.backlogs_mode == "backlogs" then
      return "BACKLOGS", function(b)
        return b.name or b.id or "backlog"
      end
    end
    if S.backlogs_mode == "items" then
      local name = (S.selected_backlog and (S.selected_backlog.name or S.selected_backlog.id)) or "backlog"
      return string.format("BACKLOG: %s", name), fmt_work_item
    end
    if S.backlogs_mode == "links" then
      local src = S.links_source_id and ("#" .. tostring(S.links_source_id)) or "(unknown)"
      return string.format("LINKS FROM %s", src), fmt_work_item
    end
    return "BACKLOGS", function(b)
      return b.name or b.id or "backlog"
    end
  end
  return "", function(_)
    return ""
  end
end

local function push_view()
  S.view_stack[#S.view_stack + 1] = {
    nav_index = S.nav_index,
    list_index = S.list_index,
    list_items = S.list_items,
    backlogs_mode = S.backlogs_mode,
    selected_backlog = S.selected_backlog,
    links_source_id = S.links_source_id,
    focus = S.focus,
  }
end

local function pop_view()
  local top = S.view_stack[#S.view_stack]
  if not top then
    return false
  end
  S.view_stack[#S.view_stack] = nil
  S.nav_index = top.nav_index
  S.list_index = top.list_index
  S.list_items = top.list_items
  S.backlogs_mode = top.backlogs_mode
  S.selected_backlog = top.selected_backlog
  S.links_source_id = top.links_source_id
  if top.focus then
    S.focus = top.focus
  end
  return true
end

local function parse_work_item_relation_ids(wi)
  local ids = {}
  local seen = {}
  for _, r in ipairs((wi and wi.relations) or {}) do
    local url = r.url
    if type(url) == "string" then
      local id = url:match("/workItems/(%d+)") or url:match("/workitems/(%d+)")
      if id and not seen[id] then
        seen[id] = true
        ids[#ids + 1] = tonumber(id)
      end
    end
  end
  table.sort(ids)
  return ids
end

local function ensure_work_item_details(project, id, cb)
  if S.cache.work_item_details[id] then
    return cb(nil, S.cache.work_item_details[id])
  end

  Client.get_work_item(project, id, {
    "System.Title",
    "System.State",
    "System.WorkItemType",
    "System.AssignedTo",
    "System.CreatedBy",
    "System.Tags",
    "System.AreaPath",
    "System.IterationPath",
    "System.Description",
  }, function(err, wi)
    if err then
      return cb(err, nil)
    end
    S.cache.work_item_details[id] = wi
    cb(nil, wi)
  end)
end

local function rerender_current_list()
  clamp_list_index()
  local nav = current_nav().id
  local title, fmt = list_render_info(nav)
  render_list(title, S.list_items, fmt)
end

current_nav = function()
  return S.nav_items[S.nav_index]
end

current_item = function()
  return S.list_items[S.list_index]
end

local function focus(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

local function render_nav()
  local lines = { "NAV", "" }
  for i, item in ipairs(S.nav_items) do
    local prefix = (i == S.nav_index) and ">" or " "
    lines[#lines + 1] = string.format("%s %s", prefix, item.label)
  end
  set_lines(S.bufs.nav, lines)
end

render_list = function(title, entries, formatter)
  local lines = { title, "" }
  for i, it in ipairs(entries) do
    local prefix = (i == S.list_index) and ">" or " "
    local text = formatter(it)
    lines[#lines + 1] = string.format("%s %s", prefix, text)
  end
  if #entries == 0 then
    lines[#lines + 1] = "(empty)"
  end
  set_lines(S.bufs.list, lines)
end

local function render_details_lines(lines)
  set_lines(S.bufs.details, lines)
end

local function set_winbars()
  local bar = ui_winbar(S)
  for _, win in pairs(S.wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winbar = bar
    end
  end
end

local function schedule_details_refresh(fn)
  if S.detail_timer then
    pcall(vim.fn.timer_stop, S.detail_timer)
    S.detail_timer = nil
  end
  S.detail_timer = vim.fn.timer_start(200, function()
    vim.schedule(fn)
  end)
end

local function load_projects(cb)
  if S.cache.projects then
    return cb(S.cache.projects)
  end
  Client.list_projects(function(err, projects)
    if err then
      Util.notify(err.message, vim.log.levels.ERROR)
      return cb({})
    end
    S.cache.projects = projects
    cb(projects)
  end)
end

local function load_repos(project, cb)
  if S.cache.repos_by_project[project] then
    return cb(S.cache.repos_by_project[project])
  end
  Client.list_repos(project, function(err, repos)
    if err then
      Util.notify(err.message, vim.log.levels.ERROR)
      return cb({})
    end
    S.cache.repos_by_project[project] = repos
    cb(repos)
  end)
end

local function load_teams(project, cb)
  if S.cache.teams_by_project[project] then
    return cb(S.cache.teams_by_project[project])
  end
  Client.list_teams(project, function(err, teams)
    if err then
      teams = {}
    end
    S.cache.teams_by_project[project] = teams
    cb(teams)
  end)
end

local function load_prs(project, repo_id, cb)
  local key = project .. ":" .. repo_id
  if S.cache.prs_by_repo[key] then
    return cb(S.cache.prs_by_repo[key])
  end
  Client.list_pull_requests(project, repo_id, "active", function(err, prs)
    if err then
      Util.notify(err.message, vim.log.levels.ERROR)
      return cb({})
    end
    S.cache.prs_by_repo[key] = prs
    cb(prs)
  end)
end

local function load_backlogs(project, team, cb)
  local key = project .. ":" .. team
  if S.cache.backlogs_by_team[key] then
    return cb(S.cache.backlogs_by_team[key])
  end
  Client.list_backlogs(project, team, function(err, backlogs)
    if err then
      Util.notify(err.message, vim.log.levels.ERROR)
      return cb({})
    end
    S.cache.backlogs_by_team[key] = backlogs
    cb(backlogs)
  end)
end

local function refresh_list()
  set_winbars()
  render_nav()

  local nav = current_nav().id
  local project = State.values.project
  local team = State.values.team
  local repo = State.values.repo

  if S.last_nav_id ~= nav then
    S.list_index = 1
    S.last_nav_id = nav
  end

  if nav == "projects" then
    return load_projects(function(projects)
      S.list_items = projects
      rerender_current_list()
      render_details_lines({ "Select a project with <Enter>." })
    end)
  end

  if nav == "repos" then
    if not project or project == "" then
      S.list_items = {}
      rerender_current_list()
      return
    end
    return load_repos(project, function(repos)
      S.list_items = repos
      rerender_current_list()
      render_details_lines({ "Select a repo with <Enter>." })
    end)
  end

  if nav == "teams" then
    if not project or project == "" then
      S.list_items = {}
      rerender_current_list()
      return
    end
    return load_teams(project, function(teams)
      S.list_items = teams
      rerender_current_list()
      render_details_lines({ "Select a team with <Enter>." })
    end)
  end

  if nav == "prs" then
    if not project or not repo or not repo.id then
      S.list_items = {}
      rerender_current_list()
      return render_details_lines({ "Select project/repo first (p/r)." })
    end
    return load_prs(project, repo.id, function(prs)
      S.list_items = prs
      rerender_current_list()
      render_details_lines({ "Select a PR to preview. Press d for diff, a/s/x to vote, c to comment." })
    end)
  end

  if nav == "mywork" then
    if not project or project == "" then
      S.list_items = {}
      rerender_current_list()
      return render_details_lines({ "Select a project first (p)." })
    end

    local wiql = [[
SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType]
FROM workitems
WHERE
  [System.TeamProject] = @project
  AND [System.AssignedTo] = @Me
ORDER BY [System.ChangedDate] DESC
    ]]

    return Client.query_wiql(project, team, wiql, function(err, result)
      if err then
        Util.notify(err.message, vim.log.levels.ERROR)
        S.list_items = {}
        rerender_current_list()
        return
      end
      local work_items = (result and result.workItems) or {}
      local ids = {}
      for _, wi in ipairs(work_items) do
        ids[#ids + 1] = wi.id
      end

      Client.get_work_items(project, ids, { "System.Title", "System.State", "System.WorkItemType", "System.AssignedTo" }, function(err2, items)
        if err2 then
          Util.notify(err2.message, vim.log.levels.ERROR)
          items = {}
        end
        S.list_items_all = items
        S.list_items = apply_work_item_filter(items)
        rerender_current_list()
        refresh_details()
      end)
    end)
  end

  if nav == "sprints" then
    if not project or not team then
      S.list_items = {}
      rerender_current_list()
      return render_details_lines({ "Select project/team first (p/t)." })
    end
    return Client.list_team_iterations(project, team, "current", function(err, iterations)
      if err then
        Util.notify(err.message, vim.log.levels.ERROR)
        iterations = {}
      end
      S.list_items = iterations
      rerender_current_list()
      render_details_lines({ "Current iterations." })
    end)
  end

  if nav == "backlogs" then
    if not project or not team then
      S.list_items = {}
      rerender_current_list()
      return render_details_lines({ "Select project/team first (p/t)." })
    end
    if S.backlogs_mode == "backlogs" then
      return load_backlogs(project, team, function(backlogs)
        S.list_items = backlogs
        rerender_current_list()
        render_details_lines({ "Select a backlog to view its work items." })
      end)
    end
    -- items/links modes keep their own list_items; just re-render.
    rerender_current_list()
    refresh_details()
    return
  end
end

refresh_details = function()
  local nav = current_nav().id
  local item = current_item()
  local project = State.values.project
  local repo = State.values.repo
  local team = State.values.team

  if not item then
    return
  end

  if nav == "prs" and repo and repo.id then
    return schedule_details_refresh(function()
      Client.get_pull_request(project, repo.id, item.pullRequestId, function(err, pr)
        if err then
          return render_details_lines({ "Failed to load PR details:", err.message })
        end
        Client.list_threads(project, repo.id, item.pullRequestId, function(err2, threads)
          if err2 then
            threads = {}
          end
          render_details_lines(BufferRender.render_pr(pr, threads))
        end)
      end)
    end)
  end

  if nav == "mywork" then
    if not item.id then
      return
    end
    return schedule_details_refresh(function()
      ensure_work_item_details(project, item.id, function(err, wi)
        if err then
          return render_details_lines({ "Failed to load work item:", err.message })
        end
        render_details_lines(BufferRender.render_work_item_details(wi))
      end)
    end)
  end

  if nav == "backlogs" and project and team then
    if S.backlogs_mode == "backlogs" then
      return render_details_lines({ "Select a backlog with <Enter>." })
    end

    -- items / links: item is a work item summary; fetch full details + relations.
    if not item or not item.id then
      return
    end

    return schedule_details_refresh(function()
      ensure_work_item_details(project, item.id, function(err, wi)
        if err then
          return render_details_lines({ "Failed to load work item:", err.message })
        end
        render_details_lines(BufferRender.render_work_item_details(wi))
      end)
    end)
  end
end

local function move_nav(delta)
  S.nav_index = math.max(1, math.min(#S.nav_items, S.nav_index + delta))
  refresh_list()
end

local function move_list(delta)
  if #S.list_items == 0 then
    return
  end
  S.list_index = math.max(1, math.min(#S.list_items, S.list_index + delta))
  rerender_current_list()
  refresh_details()
end

local function set_focus(which)
  S.focus = which
  focus(S.wins[which])
end

local function focus_next()
  if S.focus == "nav" then
    return set_focus("list")
  end
  if S.focus == "list" then
    return set_focus("details")
  end
  return set_focus("nav")
end

local function select_current()
  local nav = current_nav().id
  local item = current_item()
  if not item then
    return
  end

  if nav == "projects" then
    State.values.project = item.name
    State.values.team = nil
    State.values.repo = nil
    State.save()
    Util.notify("Project set: " .. item.name)
    S.nav_index = 1
    return refresh_list()
  end

  if nav == "repos" then
    State.values.repo = { id = item.id, name = item.name, remoteUrl = item.remoteUrl }
    State.save()
    Util.notify("Repo set: " .. item.name)
    S.nav_index = 1
    return refresh_list()
  end

  if nav == "teams" then
    State.values.team = item.name
    State.save()
    Util.notify("Team set: " .. item.name)
    S.nav_index = 1
    return refresh_list()
  end

  if nav == "backlogs" then
    local project = State.values.project
    local team = State.values.team
    if not project or not team then
      return
    end

    if S.backlogs_mode == "backlogs" then
      -- Enter backlog: list shows its work items.
      push_view()
      S.selected_backlog = item
      S.backlogs_mode = "items"
      S.links_source_id = nil
      S.list_index = 1
      S.list_items = {}
      rerender_current_list()
      render_details_lines({ "Loading backlog items..." })

      return Client.get_backlog_level_work_items(project, team, item.id, function(err, links)
        if err then
          Util.notify(err.message, vim.log.levels.ERROR)
          -- Restore previous view.
          pop_view()
          return refresh_list()
        end
        local ids = {}
        for _, link in ipairs(links or {}) do
          local target = link.target or {}
          if target.id then
            ids[#ids + 1] = target.id
          end
        end
        Client.get_work_items(project, ids, { "System.Title", "System.State", "System.WorkItemType", "System.AssignedTo" }, function(err2, items)
          if err2 then
            Util.notify(err2.message, vim.log.levels.ERROR)
            items = {}
          end
          S.list_items_all = items
          S.list_items = apply_work_item_filter(items)
          S.list_index = 1
          rerender_current_list()
          refresh_details()
        end)
      end)
    end

    -- In items/links mode, <CR> just refreshes details.
    return refresh_details()
  end

  refresh_details()
end

local function action_back()
  if current_nav().id ~= "backlogs" then
    return
  end
  if pop_view() then
    S.list_items_all = (S.list_items_all and S.list_items_all) or nil
    rerender_current_list()
    refresh_details()
  end
end

local function action_filter_work_items()
  if not is_work_item_list_context() then
    return Util.notify("Filter is only available for work item lists", vim.log.levels.INFO)
  end
  vim.ui.input({ prompt = "Filter assignee (substring; empty clears): " }, function(input)
    if input == nil then
      return
    end
    input = Util.trim(input)
    if input == "" then
      S.work_item_filter = nil
    else
      S.work_item_filter = input
    end

    local items = S.list_items_all or S.list_items
    S.list_items = apply_work_item_filter(items)
    S.list_index = 1
    rerender_current_list()
    refresh_details()
  end)
end

local function action_clear_filter()
  S.work_item_filter = nil
  if S.list_items_all then
    S.list_items = S.list_items_all
    S.list_index = 1
    rerender_current_list()
    refresh_details()
  end
end

local function click_index_from_mouse(line)
  -- List render format: title, blank, then items.
  local idx = tonumber(line) - 2
  if not idx or idx < 1 then
    return nil
  end
  return idx
end

local function action_click_nav(double)
  local pos = vim.fn.getmousepos()
  local idx = click_index_from_mouse(pos.line)
  if not idx or idx > #S.nav_items then
    return
  end
  S.nav_index = idx
  set_focus("nav")
  refresh_list()
  if double then
    refresh_list()
  end
end

local function action_click_list(double)
  local pos = vim.fn.getmousepos()
  local idx = click_index_from_mouse(pos.line)
  if not idx or idx > #S.list_items then
    return
  end
  S.list_index = idx
  set_focus("list")
  rerender_current_list()
  refresh_details()
  if double then
    select_current()
  end
end

local function action_open_links()
  if current_nav().id ~= "backlogs" then
    return
  end
  if S.backlogs_mode == "backlogs" then
    return
  end
  local project = State.values.project
  local item = current_item()
  if not project or not item or not item.id then
    return
  end

  ensure_work_item_details(project, item.id, function(err, wi)
    if err then
      return Util.notify(err.message, vim.log.levels.ERROR)
    end
    local ids = parse_work_item_relation_ids(wi)
    if #ids == 0 then
      return Util.notify("No linked work items", vim.log.levels.INFO)
    end

    push_view()
    S.backlogs_mode = "links"
    S.links_source_id = item.id
    S.list_items = {}
    S.list_index = 1
    rerender_current_list()
    render_details_lines({ string.format("Loading links for #%s...", tostring(item.id)) })

    Client.get_work_items(project, ids, { "System.Title", "System.State", "System.WorkItemType" }, function(err2, items)
      if err2 then
        Util.notify(err2.message, vim.log.levels.ERROR)
        pop_view()
        return refresh_list()
      end
      S.list_items_all = items
      S.list_items = apply_work_item_filter(items)
      S.list_index = 1
      rerender_current_list()
      refresh_details()
    end)
  end)
end

local function action_open_browser()
  local nav = current_nav().id
  local item = current_item()
  if not item then
    return
  end
  if nav == "prs" then
    local url = item._links and item._links.web and item._links.web.href
    if url then
      return vim.ui.open(url)
    end
    return Util.notify("PR web URL not available", vim.log.levels.WARN)
  end
  if nav == "mywork" then
    local project = State.values.project
    local base = Config.values.org_url
    if base and project then
      return vim.ui.open(base .. "/" .. project .. "/_workitems/edit/" .. tostring(item.id))
    end
  end

  if nav == "backlogs" then
    local project = State.values.project
    local base = Config.values.org_url
    if base and project and item.id then
      return vim.ui.open(base .. "/" .. project .. "/_workitems/edit/" .. tostring(item.id))
    end
  end
end

local function action_vote(vote)
  local nav = current_nav().id
  local pr = current_item()
  local project = State.values.project
  local repo = State.values.repo
  if nav ~= "prs" or not pr or not repo or not repo.id then
    return
  end
  Client.get_me(function(err, me)
    if err then
      return Util.notify(err.message, vim.log.levels.ERROR)
    end
    Client.set_reviewer_vote(project, repo.id, pr.pullRequestId, me.id, vote, function(err2)
      if err2 then
        return Util.notify(err2.message, vim.log.levels.ERROR)
      end
      Util.notify(string.format("Set vote=%s on PR #%s", tostring(vote), tostring(pr.pullRequestId)))
      S.cache.prs_by_repo = {}
      refresh_list()
      refresh_details()
    end)
  end)
end

local function action_comment()
  local nav = current_nav().id
  local pr = current_item()
  local project = State.values.project
  local repo = State.values.repo
  if nav ~= "prs" or not pr or not repo or not repo.id then
    return
  end
  vim.ui.input({ prompt = "Comment: " }, function(content)
    content = content and Util.trim(content) or nil
    if not content or content == "" then
      return
    end
    Client.create_pr_comment_thread(project, repo.id, pr.pullRequestId, content, function(err)
      if err then
        return Util.notify(err.message, vim.log.levels.ERROR)
      end
      Util.notify("Comment posted")
      refresh_details()
    end)
  end)
end

local function action_diffview()
  local nav = current_nav().id
  local pr = current_item()
  local repo = State.values.repo
  if nav ~= "prs" or not pr or not repo or not repo.remoteUrl then
    return
  end

  Git.get_origin_url(function(origin)
    if not origin then
      return Util.notify("Not inside a git repo (no remote.origin.url)", vim.log.levels.WARN)
    end
    if not Git.remote_matches_ado(repo.remoteUrl, origin) then
      return Util.notify("Current git repo does not match selected ADO repo", vim.log.levels.WARN)
    end

    Git.fetch_pr_merge_ref(pr.pullRequestId, function(ok, merge_ref, err)
      if not ok then
        return Util.notify("Failed to fetch PR ref: " .. (err or ""), vim.log.levels.ERROR)
      end
      local target = pr.targetRefName or "HEAD"
      Git.open_diffview(target, merge_ref)
    end)
  end)
end

local function action_switch_project()
  for i, it in ipairs(S.nav_items) do
    if it.id == "projects" then
      S.nav_index = i
      return refresh_list()
    end
  end
end

local function action_switch_repo()
  for i, it in ipairs(S.nav_items) do
    if it.id == "repos" then
      S.nav_index = i
      return refresh_list()
    end
  end
end

local function action_switch_team()
  for i, it in ipairs(S.nav_items) do
    if it.id == "teams" then
      S.nav_index = i
      return refresh_list()
    end
  end
end

local function action_refresh()
  S.cache.prs_by_repo = {}
  S.cache.projects = nil
  S.cache.repos_by_project = {}
  S.cache.teams_by_project = {}
  S.cache.backlogs_by_team = {}
  S.cache.work_item_details = {}
  S.backlogs_mode = "backlogs"
  S.selected_backlog = nil
  S.links_source_id = nil
  S.view_stack = {}
  S.list_items_all = nil
  refresh_list()
  refresh_details()
end

local function quit()
  if S.tab and vim.api.nvim_tabpage_is_valid(S.tab) then
    vim.api.nvim_set_current_tabpage(S.tab)
    vim.cmd("tabclose")
  end
end

local HELP = {
  { "q", "Quit" },
  { "?", "Help" },
  { "<Tab>", "Next pane" },
  { "p", "Switch project" },
  { "r", "Switch repo" },
  { "t", "Switch team" },
  { "R", "Refresh" },
  { "o", "Open in browser (PR/work item)" },
  { "j / k", "Move selection (nav/list)" },
  { "<CR>", "Select" },
  { "l", "Links (work item)" },
  { "b", "Back (within backlogs)" },
  { "f", "Filter work items by assignee" },
  { "F", "Clear work item filter" },
  { "d", "Diffview (PR only)" },
  { "a", "Approve (PR only)" },
  { "s", "Approve w/ suggestions (PR only)" },
  { "x", "Request changes (PR only)" },
  { "c", "Comment (PR only)" },
}

local help_win
local help_buf

local function close_help()
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    vim.api.nvim_win_close(help_win, true)
  end
  help_win = nil
  help_buf = nil
end

local function show_help()
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    return close_help()
  end

  local prev_win = vim.api.nvim_get_current_win()

  help_buf = scratch_buf("ado://help", "markdown")
  vim.bo[help_buf].modifiable = true
  vim.bo[help_buf].bufhidden = "wipe"
  vim.bo[help_buf].filetype = "markdown"

  local lines = {
    "ADO Help",
    "",
    "Keys:",
    "",
  }
  for _, item in ipairs(HELP) do
    lines[#lines + 1] = string.format("- %s: %s", item[1], item[2])
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Press q, <Esc>, or ? to close."
  set_lines(help_buf, lines)

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, #l)
  end
  width = math.min(math.max(width + 4, 44), math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.7))

  help_win = vim.api.nvim_open_win(help_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
  })

  vim.wo[help_win].wrap = false
  vim.wo[help_win].cursorline = false

  vim.keymap.set("n", "q", function()
    close_help()
    if prev_win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end, { buffer = help_buf, silent = true })
  vim.keymap.set("n", "?", function()
    close_help()
    if prev_win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end, { buffer = help_buf, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    close_help()
    if prev_win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end, { buffer = help_buf, silent = true })
end

local function map_buf(buf, mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
end

local function setup_keymaps()
  for _, buf in pairs(S.bufs) do
    map_buf(buf, "n", "q", quit, "Quit")
    map_buf(buf, "n", "?", show_help, "Help")
    map_buf(buf, "n", "<Tab>", focus_next, "Next pane")
    map_buf(buf, "n", "p", action_switch_project, "Switch project")
    map_buf(buf, "n", "r", action_switch_repo, "Switch repo")
    map_buf(buf, "n", "t", action_switch_team, "Switch team")
    map_buf(buf, "n", "R", action_refresh, "Refresh")
    map_buf(buf, "n", "o", action_open_browser, "Open in browser")
    map_buf(buf, "n", "b", action_back, "Back")
    map_buf(buf, "n", "l", action_open_links, "Links")
    map_buf(buf, "n", "f", action_filter_work_items, "Filter work items")
    map_buf(buf, "n", "F", action_clear_filter, "Clear filter")
  end

  map_buf(S.bufs.nav, "n", "j", function()
    move_nav(1)
  end, "Down")
  map_buf(S.bufs.nav, "n", "k", function()
    move_nav(-1)
  end, "Up")
  map_buf(S.bufs.nav, "n", "<CR>", function()
    refresh_list()
  end, "Select nav")

  map_buf(S.bufs.nav, "n", "<LeftMouse>", function()
    action_click_nav(false)
  end, "Click")
  map_buf(S.bufs.nav, "n", "<2-LeftMouse>", function()
    action_click_nav(true)
  end, "Double click")

  map_buf(S.bufs.list, "n", "j", function()
    move_list(1)
  end, "Down")
  map_buf(S.bufs.list, "n", "k", function()
    move_list(-1)
  end, "Up")
  map_buf(S.bufs.list, "n", "<CR>", select_current, "Select")

  map_buf(S.bufs.list, "n", "<LeftMouse>", function()
    action_click_list(false)
  end, "Click")
  map_buf(S.bufs.list, "n", "<2-LeftMouse>", function()
    action_click_list(true)
  end, "Double click")

  for _, buf in pairs(S.bufs) do
    map_buf(buf, "n", "d", action_diffview, "Diffview")
    map_buf(buf, "n", "a", function()
      action_vote(10)
    end, "Approve")
    map_buf(buf, "n", "s", function()
      action_vote(5)
    end, "Approve with suggestions")
    map_buf(buf, "n", "x", function()
      action_vote(-10)
    end, "Request changes")
    map_buf(buf, "n", "c", action_comment, "Comment")
  end
end

local function open_layout()
  vim.cmd("tabnew")
  S.tab = vim.api.nvim_get_current_tabpage()

  -- Layout: nav | list | details
  vim.cmd("vsplit")
  vim.cmd("vsplit")

  local wins = vim.api.nvim_tabpage_list_wins(S.tab)
  -- win order is not guaranteed; assign by current layout using left-to-right positions
  table.sort(wins, function(a, b)
    local pa = vim.api.nvim_win_get_position(a)
    local pb = vim.api.nvim_win_get_position(b)
    if pa[1] == pb[1] then
      return pa[2] < pb[2]
    end
    return pa[1] < pb[1]
  end)

  S.wins.nav = wins[1]
  S.wins.list = wins[2]
  S.wins.details = wins[3]

  S.bufs.nav = scratch_buf("ado://nav", "ado")
  S.bufs.list = scratch_buf("ado://list", "ado")
  S.bufs.details = scratch_buf("ado://details", "markdown")

  vim.api.nvim_win_set_buf(S.wins.nav, S.bufs.nav)
  vim.api.nvim_win_set_buf(S.wins.list, S.bufs.list)
  vim.api.nvim_win_set_buf(S.wins.details, S.bufs.details)

  vim.wo[S.wins.nav].number = false
  vim.wo[S.wins.list].number = false
  vim.wo[S.wins.details].number = false
  vim.wo[S.wins.nav].relativenumber = false
  vim.wo[S.wins.list].relativenumber = false
  vim.wo[S.wins.details].relativenumber = false
  vim.wo[S.wins.nav].wrap = false
  vim.wo[S.wins.list].wrap = false
  vim.wo[S.wins.details].wrap = true

  vim.api.nvim_win_set_width(S.wins.nav, 20)

  set_winbars()
  setup_keymaps()
  set_focus("list")
end

function M.open()
  Util.ensure_configured_or_prompt(function()
    if not State.values.project or State.values.project == "" then
      -- pick a project implicitly by rendering projects first
      S.nav_index = 6
    else
      S.nav_index = 1
    end

    open_layout()
    refresh_list()
    refresh_details()
  end)
end

return M
