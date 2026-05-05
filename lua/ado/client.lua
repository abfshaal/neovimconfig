local M = {}

local Config = require("ado.config")
local Http = require("ado.http")
local Util = require("ado.util")

local function org_base()
  return Config.values.org_url
end

local function api_version()
  return Config.values.api_version
end

local function auth_headers()
  return {
    Authorization = Util.basic_auth_header(Config.values.pat),
  }
end

---@param cb fun(err: ado.HttpError|nil, me: { id: string, displayName: string|nil }|nil)
function M.get_me(cb)
  -- Use org-scoped connectionData to identify the authenticated user.
  -- Avoid profile service (app.vssps.visualstudio.com) which can 401 depending on tenant/PAT rules.
  local url = Util.url_join(org_base(), "_apis/connectionData")
  Http.request("GET", url, {
    headers = auth_headers(),
    query = {
      -- connectionData uses preview versions; use a known-compatible value independent of other APIs.
      ["api-version"] = "7.1-preview.1",
      connectOptions = 1,
      lastChangeId = -1,
      lastChangeId64 = -1,
    },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    local json = resp.json or {}
    local user = json.authenticatedUser or json.authorizedUser or {}
    if not user.id or user.id == "" then
      return cb({ status = resp.status, message = "connectionData did not include authenticatedUser.id", response = resp }, nil)
    end
    cb(nil, { id = user.id, displayName = user.customDisplayName or user.providerDisplayName or user.displayName })
  end)
end

---@param cb fun(err: ado.HttpError|nil, projects: table[]|nil)
function M.list_projects(cb)
  local url = Util.url_join(org_base(), "_apis/projects")
  Http.request("GET", url, { headers = auth_headers(), query = { ["api-version"] = api_version() } }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param cb fun(err: ado.HttpError|nil, repos: table[]|nil)
function M.list_repos(project, cb)
  local url = Util.url_join(org_base(), project, "_apis/git/repositories")
  Http.request("GET", url, { headers = auth_headers(), query = { ["api-version"] = api_version() } }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param repo_id string
---@param status? 'active'|'completed'|'abandoned'|'all'
---@param cb fun(err: ado.HttpError|nil, prs: table[]|nil)
function M.list_pull_requests(project, repo_id, status, cb)
  local url = Util.url_join(org_base(), project, "_apis/git/repositories", repo_id, "pullrequests")
  Http.request("GET", url, {
    headers = auth_headers(),
    query = {
      ["api-version"] = api_version(),
      ["searchCriteria.status"] = status or "active",
    },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param repo_id string
---@param pr_id number|string
---@param cb fun(err: ado.HttpError|nil, pr: table|nil)
function M.get_pull_request(project, repo_id, pr_id, cb)
  local url = Util.url_join(org_base(), project, "_apis/git/repositories", repo_id, "pullrequests", tostring(pr_id))
  Http.request("GET", url, { headers = auth_headers(), query = { ["api-version"] = api_version() } }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, resp.json)
  end)
end

---@param project string
---@param repo_id string
---@param pr_id number|string
---@param cb fun(err: ado.HttpError|nil, threads: table[]|nil)
function M.list_threads(project, repo_id, pr_id, cb)
  local url = Util.url_join(org_base(), project, "_apis/git/repositories", repo_id, "pullrequests", tostring(pr_id), "threads")
  Http.request("GET", url, { headers = auth_headers(), query = { ["api-version"] = api_version() } }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param repo_id string
---@param pr_id number|string
---@param reviewer_id string
---@param vote number
---@param cb fun(err: ado.HttpError|nil, reviewer: table|nil)
function M.set_reviewer_vote(project, repo_id, pr_id, reviewer_id, vote, cb)
  local url = Util.url_join(
    org_base(),
    project,
    "_apis/git/repositories",
    repo_id,
    "pullrequests",
    tostring(pr_id),
    "reviewers",
    reviewer_id
  )

  Http.request("PUT", url, {
    headers = auth_headers(),
    query = { ["api-version"] = api_version() },
    body = { vote = vote, hasDeclined = false },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, resp.json)
  end)
end

---@param project string
---@param repo_id string
---@param pr_id number|string
---@param content string
---@param cb fun(err: ado.HttpError|nil, thread: table|nil)
function M.create_pr_comment_thread(project, repo_id, pr_id, content, cb)
  local url = Util.url_join(org_base(), project, "_apis/git/repositories", repo_id, "pullrequests", tostring(pr_id), "threads")

  Http.request("POST", url, {
    headers = auth_headers(),
    query = { ["api-version"] = api_version() },
    body = {
      comments = {
        {
          parentCommentId = 0,
          content = content,
          commentType = 1,
        },
      },
      status = 1,
    },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, resp.json)
  end)
end

---@param project string
---@param cb fun(err: ado.HttpError|nil, teams: table[]|nil)
function M.list_teams(project, cb)
  local url = Util.url_join(org_base(), "_apis/projects", project, "teams")
  Http.request("GET", url, { headers = auth_headers(), query = { ["api-version"] = api_version() } }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param team string
---@param timeframe? 'current'|'past'|'future'
---@param cb fun(err: ado.HttpError|nil, iterations: table[]|nil)
function M.list_team_iterations(project, team, timeframe, cb)
  local url = Util.url_join(org_base(), project, team, "_apis/work/teamsettings/iterations")
  Http.request("GET", url, {
    headers = auth_headers(),
    query = { ["api-version"] = api_version(), ["$timeframe"] = timeframe },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param team string
---@param cb fun(err: ado.HttpError|nil, backlogs: table[]|nil)
function M.list_backlogs(project, team, cb)
  local url = Util.url_join(org_base(), project, team, "_apis/work/backlogs")
  Http.request("GET", url, {
    headers = auth_headers(),
    query = { ["api-version"] = api_version() },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param team string
---@param backlog_id string
---@param cb fun(err: ado.HttpError|nil, links: table[]|nil)
function M.get_backlog_level_work_items(project, team, backlog_id, cb)
  local url = Util.url_join(org_base(), project, team, "_apis/work/backlogs", backlog_id, "workItems")
  Http.request("GET", url, {
    headers = auth_headers(),
    query = { ["api-version"] = api_version() },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.workItems) or {})
  end)
end

---@param project string
---@param team string|nil
---@param wiql string
---@param cb fun(err: ado.HttpError|nil, result: table|nil)
function M.query_wiql(project, team, wiql, cb)
  local url
  if team and team ~= "" then
    url = Util.url_join(org_base(), project, team, "_apis/wit/wiql")
  else
    url = Util.url_join(org_base(), project, "_apis/wit/wiql")
  end

  Http.request("POST", url, {
    headers = auth_headers(),
    query = { ["api-version"] = api_version() },
    body = { query = wiql },
  }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, resp.json)
  end)
end

---@param project string
---@param ids number[]
---@param fields? string[]
---@param cb fun(err: ado.HttpError|nil, items: table[]|nil)
function M.get_work_items(project, ids, fields, cb)
  if #ids == 0 then
    return cb(nil, {})
  end

  local url = Util.url_join(org_base(), project, "_apis/wit/workitems")
  local q = {
    ["api-version"] = api_version(),
    ids = table.concat(ids, ","),
  }
  if fields and #fields > 0 then
    q.fields = table.concat(fields, ",")
  end

  Http.request("GET", url, { headers = auth_headers(), query = q }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, (resp.json and resp.json.value) or {})
  end)
end

---@param project string
---@param id number|string
---@param fields? string[]
---@param cb fun(err: ado.HttpError|nil, item: table|nil)
function M.get_work_item(project, id, fields, cb)
  local url = Util.url_join(org_base(), project, "_apis/wit/workitems", tostring(id))
  local q = {
    ["api-version"] = api_version(),
    ["$expand"] = "relations",
  }
  if fields and #fields > 0 then
    q.fields = table.concat(fields, ",")
  end

  Http.request("GET", url, { headers = auth_headers(), query = q }, function(err, resp)
    if err then
      return cb(err, nil)
    end
    cb(nil, resp.json)
  end)
end

return M
