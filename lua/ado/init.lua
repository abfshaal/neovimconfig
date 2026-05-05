local M = {}

local Config = require("ado.config")
local State = require("ado.state")
local Commands = require("ado.commands")

---@class ado.SetupOpts
---@field org_url? string
---@field pat? string
---@field project? string
---@field team? string
---@field api_version? string
---@field picker? 'auto'|'native'|'telescope'
---@field persist? boolean
---@field keychain_service? string

---@param opts? ado.SetupOpts
function M.setup(opts)
  Config.setup(opts or {})
  State.load()
  Commands.setup()
end

return M
