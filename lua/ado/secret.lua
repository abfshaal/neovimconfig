local M = {}

local Util = require("ado.util")

local function is_darwin()
  local ok, uname = pcall(vim.loop.os_uname)
  if not ok or type(uname) ~= "table" then
    return false
  end
  return uname.sysname == "Darwin"
end

local function has_security_cli()
  if vim.fn.executable("security") == 1 then
    return true
  end
  return false
end

function M.supported()
  return is_darwin() and has_security_cli()
end

local function trim(s)
  return Util.trim(s or "")
end

---@param service string
---@param account string
---@param cb fun(ok: boolean, secret: string|nil, err: string|nil)
function M.get(service, account, cb)
  if not M.supported() then
    return cb(false, nil, "keychain unsupported")
  end
  vim.system({ "security", "find-generic-password", "-a", account, "-s", service, "-w" }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return cb(false, nil, trim(res.stderr) ~= "" and trim(res.stderr) or "not found")
      end
      local secret = trim(res.stdout)
      if secret == "" then
        return cb(false, nil, "empty secret")
      end
      cb(true, secret, nil)
    end)
  end)
end

---@param service string
---@param account string
---@param secret string
---@param cb fun(ok: boolean, err: string|nil)
function M.set(service, account, secret, cb)
  if not M.supported() then
    return cb(false, "keychain unsupported")
  end
  vim.system({
    "security",
    "add-generic-password",
    "-a",
    account,
    "-s",
    service,
    "-U",
    "-w",
    secret,
  }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        local msg = trim(res.stderr)
        if msg == "" then
          msg = trim(res.stdout)
        end
        return cb(false, msg ~= "" and msg or "failed to save")
      end
      cb(true, nil)
    end)
  end)
end

---@param service string
---@param account string
---@param cb fun(ok: boolean, err: string|nil)
function M.delete(service, account, cb)
  if not M.supported() then
    return cb(false, "keychain unsupported")
  end
  vim.system({ "security", "delete-generic-password", "-a", account, "-s", service }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        local msg = trim(res.stderr)
        if msg == "" then
          msg = trim(res.stdout)
        end
        return cb(false, msg ~= "" and msg or "failed to delete")
      end
      cb(true, nil)
    end)
  end)
end

return M
