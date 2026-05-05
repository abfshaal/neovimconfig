local M = {}

---@class ado.Config
---@field org_url string|nil
---@field pat string|nil
---@field project string|nil
---@field team string|nil
---@field api_version string
---@field picker 'auto'|'native'|'telescope'
---@field persist boolean
---@field keychain_service string
M.values = {
  org_url = nil,
  pat = nil,
  project = nil,
  team = nil,
  api_version = "7.1",
  picker = "auto",
  persist = true,
  keychain_service = "ado.nvim",
}

local function env(key)
  local v = vim.env[key]
  if v == nil or v == "" then
    return nil
  end
  return v
end

---@param opts ado.SetupOpts
function M.setup(opts)
  M.values.org_url = opts.org_url or env("ADO_ORG_URL")
  M.values.pat = opts.pat or env("ADO_PAT")
  M.values.project = opts.project or env("ADO_PROJECT")
  M.values.team = opts.team or env("ADO_TEAM")
  M.values.api_version = opts.api_version or M.values.api_version
  M.values.picker = opts.picker or M.values.picker
  if opts.persist ~= nil then
    M.values.persist = opts.persist
  end
  if opts.keychain_service ~= nil then
    M.values.keychain_service = opts.keychain_service
  end
end

return M
