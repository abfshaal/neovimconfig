local M = {}

function M.notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "ado.nvim" })
  end)
end

function M.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.base64_encode(data)
  if vim.base64 and vim.base64.encode then
    return vim.base64.encode(data)
  end

  -- Pure Lua base64 encoder (ASCII only)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local bytes = { data:byte(1, #data) }
  local out = {}
  for i = 1, #bytes, 3 do
    local a = bytes[i]
    local c = bytes[i + 1]
    local d = bytes[i + 2]
    local n = (a or 0) * 65536 + (c or 0) * 256 + (d or 0)
    local n1 = math.floor(n / 262144) % 64
    local n2 = math.floor(n / 4096) % 64
    local n3 = math.floor(n / 64) % 64
    local n4 = n % 64
    out[#out + 1] = b:sub(n1 + 1, n1 + 1)
    out[#out + 1] = b:sub(n2 + 1, n2 + 1)
    out[#out + 1] = (c ~= nil) and b:sub(n3 + 1, n3 + 1) or "="
    out[#out + 1] = (d ~= nil) and b:sub(n4 + 1, n4 + 1) or "="
  end
  return table.concat(out)
end

function M.basic_auth_header(pat)
  local token = M.base64_encode(":" .. pat)
  return "Basic " .. token
end

function M.url_join(...)
  local parts = { ... }
  local out = {}
  for i, p in ipairs(parts) do
    if p ~= nil and p ~= "" then
      if i == 1 then
        out[#out + 1] = (p:gsub("/*$", ""))
      else
        out[#out + 1] = (p:gsub("^/*", ""):gsub("/*$", ""))
      end
    end
  end
  return table.concat(out, "/")
end

local function percent_encode(str)
  -- RFC 3986 unreserved: ALPHA / DIGIT / "-" / "." / "_" / "~"
  return (tostring(str):gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

function M.query_encode(tbl)
  if not tbl then
    return ""
  end
  local parts = {}
  for k, v in pairs(tbl) do
    if v ~= nil then
      parts[#parts + 1] = string.format("%s=%s", percent_encode(k), percent_encode(v))
    end
  end
  table.sort(parts)
  return table.concat(parts, "&")
end

function M.ensure_configured_or_prompt(cb)
  local Config = require("ado.config")
  local State = require("ado.state")
  local Secret = require("ado.secret")

  local function done()
    State.values.org_url = Config.values.org_url
    State.values.project = State.values.project or Config.values.project
    State.values.team = State.values.team or Config.values.team
    State.save()
    cb()
  end

  if (not Config.values.org_url or Config.values.org_url == "") and State.values.org_url then
    Config.values.org_url = State.values.org_url
  end

  if Config.values.org_url and Config.values.pat then
    return done()
  end

  if Config.values.org_url and (not Config.values.pat or Config.values.pat == "") and Secret.supported() then
    Secret.get(Config.values.keychain_service, Config.values.org_url, function(ok, secret)
      if ok and secret and secret ~= "" then
        Config.values.pat = secret
        return done()
      end

      -- fall through to prompting below
      vim.schedule(function()
        vim.ui.input({ prompt = "ADO PAT: ", secret = true }, function(pat)
          pat = pat and M.trim(pat) or nil
          if not pat or pat == "" then
            return M.notify("ADO PAT is required", vim.log.levels.ERROR)
          end
          Config.values.pat = pat
          vim.ui.select({ "Yes", "No" }, { prompt = "Save PAT to macOS Keychain?" }, function(choice)
            if choice == "Yes" then
              Secret.set(Config.values.keychain_service, Config.values.org_url, pat, function(ok2, err)
                if not ok2 then
                  M.notify("Failed to save PAT to Keychain: " .. tostring(err), vim.log.levels.WARN)
                end
                done()
              end)
              return
            end
            done()
          end)
        end)
      end)
    end)
    return
  end

  if not Config.values.org_url then
    vim.ui.input({ prompt = "ADO org URL (e.g. https://dev.azure.com/myorg): " }, function(input)
      input = input and M.trim(input) or nil
      if not input or input == "" then
        return M.notify("ADO org URL is required", vim.log.levels.ERROR)
      end
      Config.values.org_url = input
      if Config.values.pat then
        return done()
      end

      vim.ui.input({ prompt = "ADO PAT: ", secret = true }, function(pat)
        pat = pat and M.trim(pat) or nil
        if not pat or pat == "" then
          return M.notify("ADO PAT is required", vim.log.levels.ERROR)
        end
        Config.values.pat = pat

        if Secret.supported() then
          vim.ui.select({ "Yes", "No" }, { prompt = "Save PAT to macOS Keychain?" }, function(choice)
            if choice == "Yes" then
              Secret.set(Config.values.keychain_service, Config.values.org_url, pat, function(ok2, err)
                if not ok2 then
                  M.notify("Failed to save PAT to Keychain: " .. tostring(err), vim.log.levels.WARN)
                end
                done()
              end)
              return
            end
            done()
          end)
          return
        end

        done()
      end)
    end)
    return
  end

  vim.ui.input({ prompt = "ADO PAT: ", secret = true }, function(pat)
    pat = pat and M.trim(pat) or nil
    if not pat or pat == "" then
      return M.notify("ADO PAT is required", vim.log.levels.ERROR)
    end
    Config.values.pat = pat

    if Secret.supported() then
      vim.ui.select({ "Yes", "No" }, { prompt = "Save PAT to macOS Keychain?" }, function(choice)
        if choice == "Yes" then
          Secret.set(Config.values.keychain_service, Config.values.org_url, pat, function(ok2, err)
            if not ok2 then
              M.notify("Failed to save PAT to Keychain: " .. tostring(err), vim.log.levels.WARN)
            end
            done()
          end)
          return
        end
        done()
      end)
      return
    end

    done()
  end)
end

return M
