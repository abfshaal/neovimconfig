local M = {}

local Config = require("docklog.config")

---@param opts? table
function M.setup(opts)
  Config.setup(opts)
end

return M
