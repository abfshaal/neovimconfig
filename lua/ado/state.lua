local M = {}

local Config = require("ado.config")

local state_path = vim.fn.stdpath("data") .. "/ado.nvim.json"

---@class ado.State
---@field org_url? string
---@field project? string
---@field team? string
---@field repo? { id: string, name: string, remoteUrl: string|nil }
M.values = {
  org_url = nil,
  project = nil,
  team = nil,
  repo = nil,
}

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return table.concat(lines, "\n")
end

local function write_file(path, content)
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)
end

function M.load()
  if not Config.values.persist then
    return
  end

  local content = read_file(state_path)
  if not content or content == "" then
    return
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return
  end

  M.values.project = decoded.project or Config.values.project
  M.values.team = decoded.team or Config.values.team
  M.values.repo = decoded.repo

  M.values.org_url = decoded.org_url or Config.values.org_url
  if (not Config.values.org_url or Config.values.org_url == "") and M.values.org_url then
    Config.values.org_url = M.values.org_url
  end
end

function M.save()
  if not Config.values.persist then
    return
  end

  local encoded = vim.json.encode({
    org_url = M.values.org_url,
    project = M.values.project,
    team = M.values.team,
    repo = M.values.repo,
  })

  -- Can be called from async callbacks (fast event context).
  vim.schedule(function()
    write_file(state_path, encoded)
  end)
end

return M
