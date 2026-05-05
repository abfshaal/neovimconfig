local M = {}

local function open_scratch(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_set_current_buf(buf)
  return buf
end

function M.show_lines(name, lines)
  local buf = open_scratch(name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return buf
end

function M.render_pr(pr, threads)
  local lines = {}
  lines[#lines + 1] = string.format("# PR %s: %s", tostring(pr.pullRequestId), pr.title or "")
  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format("- Status: %s", pr.status or "")
  lines[#lines + 1] = string.format("- Author: %s", (pr.createdBy and pr.createdBy.displayName) or "")
  lines[#lines + 1] = string.format("- Source: %s", pr.sourceRefName or "")
  lines[#lines + 1] = string.format("- Target: %s", pr.targetRefName or "")
  if pr.url then
    lines[#lines + 1] = string.format("- API URL: %s", pr.url)
  end
  lines[#lines + 1] = ""
  if pr.description and pr.description ~= "" then
    lines[#lines + 1] = "## Description"
    lines[#lines + 1] = pr.description
    lines[#lines + 1] = ""
  end

  if pr.reviewers and #pr.reviewers > 0 then
    lines[#lines + 1] = "## Reviewers"
    for _, r in ipairs(pr.reviewers) do
      lines[#lines + 1] = string.format("- %s (vote=%s)", r.displayName or r.uniqueName or r.id or "?", tostring(r.vote))
    end
    lines[#lines + 1] = ""
  end

  if threads and #threads > 0 then
    lines[#lines + 1] = "## Threads"
    for _, t in ipairs(threads) do
      lines[#lines + 1] = string.format("### Thread %s (%s)", tostring(t.id), t.status or "")
      if t.comments then
        for _, c in ipairs(t.comments) do
          local author = (c.author and c.author.displayName) or ""
          lines[#lines + 1] = string.format("- %s: %s", author, (c.content or ""):gsub("\n", " "))
        end
      end
      lines[#lines + 1] = ""
    end
  end

  return lines
end

function M.render_work_items(items)
  local lines = { "# My Work Items", "" }
  for _, wi in ipairs(items) do
    local fields = wi.fields or {}
    local title = fields["System.Title"] or ""
    local state = fields["System.State"] or ""
    local wtype = fields["System.WorkItemType"] or ""
    lines[#lines + 1] = string.format("- #%s [%s] %s (%s)", tostring(wi.id), wtype, title, state)
  end
  if #items == 0 then
    lines[#lines + 1] = "(no items)"
  end
  return lines
end

function M.render_backlog(backlog_name, items)
  local lines = { string.format("# Backlog: %s", backlog_name), "" }
  for _, wi in ipairs(items) do
    local fields = wi.fields or {}
    local title = fields["System.Title"] or ""
    local state = fields["System.State"] or ""
    local wtype = fields["System.WorkItemType"] or ""
    lines[#lines + 1] = string.format("- #%s [%s] %s (%s)", tostring(wi.id), wtype, title, state)
  end
  if #items == 0 then
    lines[#lines + 1] = "(no items)"
  end
  return lines
end

local function extract_work_item_id(url)
  if type(url) ~= "string" then
    return nil
  end
  local id = url:match("/workItems/(%d+)") or url:match("/workitems/(%d+)")
  if id then
    return tonumber(id)
  end
  return nil
end

local function strip_html(s)
  if type(s) ~= "string" then
    return ""
  end
  -- Minimal, best-effort conversion for ADO HTML descriptions.
  s = s:gsub("<br%s*/?>", "\n")
  s = s:gsub("</p>", "\n\n")
  s = s:gsub("</div>", "\n")
  s = s:gsub("<[^>]+>", "")
  s = s:gsub("&nbsp;", " ")
  s = s:gsub("&lt;", "<"):gsub("&gt;", ">")
  s = s:gsub("&amp;", "&")
  return s
end

function M.render_work_item_details(wi)
  local fields = (wi and wi.fields) or {}
  local id = wi and wi.id
  local title = fields["System.Title"] or ""
  local state = fields["System.State"] or ""
  local wtype = fields["System.WorkItemType"] or ""

  local assigned = fields["System.AssignedTo"]
  if type(assigned) == "table" then
    assigned = assigned.displayName or assigned.uniqueName or assigned.name or ""
  end
  assigned = assigned or ""

  local created_by = fields["System.CreatedBy"]
  if type(created_by) == "table" then
    created_by = created_by.displayName or created_by.uniqueName or created_by.name or ""
  end
  created_by = created_by or ""

  local tags = fields["System.Tags"] or ""
  local area = fields["System.AreaPath"] or ""
  local iter = fields["System.IterationPath"] or ""
  local desc = strip_html(fields["System.Description"])

  local lines = {
    string.format("# Work Item #%s: %s", tostring(id or ""), title),
    "",
    string.format("- Type: %s", wtype),
    string.format("- State: %s", state),
  }
  if assigned ~= "" then
    lines[#lines + 1] = string.format("- Assigned To: %s", assigned)
  end
  if created_by ~= "" then
    lines[#lines + 1] = string.format("- Created By: %s", created_by)
  end
  if area ~= "" then
    lines[#lines + 1] = string.format("- Area: %s", area)
  end
  if iter ~= "" then
    lines[#lines + 1] = string.format("- Iteration: %s", iter)
  end
  if tags ~= "" then
    lines[#lines + 1] = string.format("- Tags: %s", tags)
  end

  local rels = wi and wi.relations or {}
  local parents, children, related = {}, {}, {}
  for _, r in ipairs(rels or {}) do
    local rel = r.rel or ""
    local rid = extract_work_item_id(r.url)
    if rid then
      if rel == "System.LinkTypes.Hierarchy-Reverse" then
        parents[#parents + 1] = rid
      elseif rel == "System.LinkTypes.Hierarchy-Forward" then
        children[#children + 1] = rid
      else
        related[#related + 1] = rid
      end
    end
  end
  table.sort(parents)
  table.sort(children)
  table.sort(related)

  lines[#lines + 1] = ""
  lines[#lines + 1] = "## Links"
  lines[#lines + 1] = string.format("- Parent(s): %s", (#parents > 0) and table.concat(parents, ", ") or "(none)")
  lines[#lines + 1] = string.format("- Children: %s", (#children > 0) and table.concat(children, ", ") or "(none)")
  lines[#lines + 1] = string.format("- Related: %s", (#related > 0) and table.concat(related, ", ") or "(none)")
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Press l to browse linked items. Press b to go back."

  if desc ~= "" then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "## Description"
    for line in desc:gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end
  end

  return lines
end

return M
