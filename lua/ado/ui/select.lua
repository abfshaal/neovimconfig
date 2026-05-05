local M = {}

local Config = require("ado.config")

local function has_telescope()
  return pcall(require, "telescope")
end

---@param items any[]
---@param opts { prompt?: string, format_item?: fun(item:any):string }
---@param on_choice fun(item:any|nil)
function M.select(items, opts, on_choice)
  opts = opts or {}

  local picker = Config.values.picker

  -- plenary.curl callbacks can run in "fast" event contexts.
  -- Telescope/vim.ui.* must be scheduled onto the main loop.
  vim.schedule(function()
    if picker == "telescope" or (picker == "auto" and has_telescope()) then
      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local conf = require("telescope.config").values
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      pickers
        .new({}, {
          prompt_title = opts.prompt or "Select",
          finder = finders.new_table({
            results = items,
            entry_maker = function(item)
              local display = opts.format_item and opts.format_item(item) or tostring(item)
              return {
                value = item,
                display = display,
                ordinal = display,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(bufnr, map)
            actions.select_default:replace(function()
              local entry = action_state.get_selected_entry()
              actions.close(bufnr)
              on_choice(entry and entry.value or nil)
            end)

            -- Avoid overriding actions.close (it can break Telescope's internals).
            -- Instead, map explicit cancel keys to close + nil.
            map("i", "<esc>", function()
              actions.close(bufnr)
              on_choice(nil)
            end)
            map("n", "<esc>", function()
              actions.close(bufnr)
              on_choice(nil)
            end)
            map("i", "<C-c>", function()
              actions.close(bufnr)
              on_choice(nil)
            end)
            map("n", "<C-c>", function()
              actions.close(bufnr)
              on_choice(nil)
            end)

            return true
          end,
        })
        :find()

      return
    end

    vim.ui.select(items, {
      prompt = opts.prompt,
      format_item = opts.format_item,
    }, on_choice)
  end)
end

return M
