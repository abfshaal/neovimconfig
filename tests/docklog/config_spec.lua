describe("docklog.config", function()
  local config

  before_each(function()
    package.loaded["docklog.config"] = nil
    config = require("docklog.config")
  end)

  it("has sensible defaults", function()
    assert.equals(10000, config.values.max_lines)
    assert.equals("docker", config.values.default_provider)
    assert.equals(100, config.values.tail_lines)
    assert.equals("below", config.values.ui.split_direction)
    assert.equals(15, config.values.ui.split_size)
    assert.equals("<C-f>l", config.values.keymaps.prefix)
  end)

  it("merges user options", function()
    config.setup({ max_lines = 5000, ui = { split_size = 20 } })
    assert.equals(5000, config.values.max_lines)
    assert.equals(20, config.values.ui.split_size)
    assert.equals("below", config.values.ui.split_direction)
    assert.equals("<C-f>l", config.values.keymaps.prefix)
  end)

  it("merges keymap overrides", function()
    config.setup({ keymaps = { prefix = "<leader>l" } })
    assert.equals("<leader>l", config.values.keymaps.prefix)
    assert.equals("f", config.values.keymaps.follow)
  end)
end)
