local M = {}

local Util = require("ado.util")

local function system(cmd, cb)
  vim.system(cmd, { text = true }, function(res)
    cb(res)
  end)
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_remote(url)
  if not url or url == "" then
    return nil
  end

  url = trim(url)
  url = url:gsub("%.git$", "")

  -- Convert scp-like syntax: git@host:org/project/_git/repo
  if url:match("^[%w%-_]+@[%w%._%-]+:") then
    url = url:gsub(":", "/", 1)
    url = "ssh://" .. url
  end

  -- Strip credentials
  url = url:gsub("^(https?://)[^/@]+@", "%1")

  -- Normalize host path casing minimally
  return url
end

function M.get_repo_root(cb)
  system({ "git", "rev-parse", "--show-toplevel" }, function(res)
    if res.code ~= 0 then
      return cb(nil)
    end
    cb(trim(res.stdout or ""))
  end)
end

function M.get_origin_url(cb)
  system({ "git", "config", "--get", "remote.origin.url" }, function(res)
    if res.code ~= 0 then
      return cb(nil)
    end
    cb(trim(res.stdout or ""))
  end)
end

function M.remote_matches_ado(ado_remote_url, origin_url)
  local a = normalize_remote(ado_remote_url)
  local o = normalize_remote(origin_url)
  if not a or not o then
    return false
  end
  return o:find(a, 1, true) ~= nil or a:find(o, 1, true) ~= nil
end

---@param pr_id number|string
---@param cb fun(ok: boolean, ref: string|nil, err: string|nil)
function M.fetch_pr_merge_ref(pr_id, cb)
  local ref_remote = string.format("refs/pull/%s/merge", tostring(pr_id))
  local ref_local = string.format("refs/ado/pr/%s/merge", tostring(pr_id))
  local spec = string.format("+%s:%s", ref_remote, ref_local)

  system({ "git", "fetch", "origin", spec }, function(res)
    if res.code ~= 0 then
      local msg = (res.stderr and res.stderr ~= "") and res.stderr or (res.stdout or "")
      msg = trim(msg)
      return cb(false, nil, msg ~= "" and msg or "git fetch failed")
    end
    cb(true, ref_local, nil)
  end)
end

---@param target_ref string
---@param merge_ref string
function M.open_diffview(target_ref, merge_ref)
  if vim.fn.exists(":DiffviewOpen") ~= 2 then
    return Util.notify("diffview.nvim not available (:DiffviewOpen missing)", vim.log.levels.ERROR)
  end

  local lhs = target_ref
  local rhs = merge_ref
  local rev = string.format("%s...%s", lhs, rhs)
  vim.cmd("DiffviewOpen " .. rev)
end

return M
