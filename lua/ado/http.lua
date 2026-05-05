local M = {}

local Curl = require("plenary.curl")
local Util = require("ado.util")

---@class ado.HttpResponse
---@field status number
---@field headers table
---@field body string
---@field json any|nil

---@class ado.HttpError
---@field status number|nil
---@field message string
---@field response ado.HttpResponse|nil

local function normalize_headers(headers)
  headers = headers or {}
  local out = {}
  for k, v in pairs(headers) do
    out[tostring(k)] = tostring(v)
  end
  return out
end

local function try_decode_json(body)
  if type(body) ~= "string" then
    return nil
  end
  local trimmed = body:gsub("^%s+", "")
  if trimmed == "" then
    return nil
  end
  local first = trimmed:sub(1, 1)
  if first ~= "{" and first ~= "[" then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, body)
  if ok then
    return decoded
  end
  return nil
end

---@param method string
---@param url string
---@param opts? { headers?: table, query?: table, body?: any }
---@param cb fun(err: ado.HttpError|nil, resp: ado.HttpResponse|nil)
function M.request(method, url, opts, cb)
  opts = opts or {}

  local q = Util.query_encode(opts.query)
  if q ~= "" then
    if url:find("?", 1, true) then
      url = url .. "&" .. q
    else
      url = url .. "?" .. q
    end
  end

  local headers = normalize_headers(opts.headers)

  local body
  if opts.body ~= nil then
    body = (type(opts.body) == "string") and opts.body or vim.json.encode(opts.body)
    headers["Content-Type"] = headers["Content-Type"] or "application/json"
  end
  headers["Accept"] = headers["Accept"] or "application/json"

  Curl.request({
    url = url,
    method = method,
    headers = headers,
    body = body,
    callback = function(res)
      -- plenary.curl callbacks can execute in a fast-event context.
      -- Always schedule results back onto the main loop.
      vim.schedule(function()
        local resp = {
          status = tonumber(res.status) or 0,
          headers = res.headers or {},
          body = res.body or "",
          json = try_decode_json(res.body),
        }

        if resp.status >= 200 and resp.status < 300 then
          return cb(nil, resp)
        end

        local detail
        if type(resp.json) == "table" then
          detail = resp.json.message or resp.json.error or resp.json.type
        end
        if not detail or detail == "" then
          detail = (resp.body or ""):gsub("\n", " ")
          if #detail > 200 then
            detail = detail:sub(1, 200) .. "..."
          end
        end

        local msg = string.format("HTTP %s %s -> %s", method, url, tostring(resp.status))
        if detail and detail ~= "" then
          msg = msg .. " | " .. tostring(detail)
        end
        cb({ status = resp.status, message = msg, response = resp }, nil)
      end)
    end,
  })
end

return M
