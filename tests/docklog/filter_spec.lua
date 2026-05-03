describe("docklog.filter", function()
  local filter

  before_each(function()
    package.loaded["docklog.filter"] = nil
    filter = require("docklog.filter")
  end)

  describe("matches", function()
    it("returns true when no filters active", function()
      assert.is_true(filter.matches("INFO some log line", {}))
    end)

    it("filters by keyword case-insensitive", function()
      local filters = { keyword = "error" }
      assert.is_true(filter.matches("ERROR something broke", filters))
      assert.is_true(filter.matches("Got an error here", filters))
      assert.is_false(filter.matches("INFO all good", filters))
    end)

    it("filters by log level inclusive upward", function()
      local filters = { level = "WARN" }
      assert.is_true(filter.matches("2026-05-03 ERROR connection refused", filters))
      assert.is_true(filter.matches("2026-05-03 WARN slow query", filters))
      assert.is_true(filter.matches("2026-05-03 WARNING deprecated", filters))
      assert.is_true(filter.matches("2026-05-03 CRITICAL out of memory", filters))
      assert.is_false(filter.matches("2026-05-03 INFO request ok", filters))
      assert.is_false(filter.matches("2026-05-03 DEBUG details", filters))
    end)

    it("combines keyword and level filters (both must match)", function()
      local filters = { keyword = "connection", level = "ERROR" }
      assert.is_true(filter.matches("ERROR connection refused", filters))
      assert.is_false(filter.matches("ERROR disk full", filters))
      assert.is_false(filter.matches("INFO connection opened", filters))
    end)

    it("handles FATAL as same severity as CRITICAL", function()
      local filters = { level = "CRITICAL" }
      assert.is_true(filter.matches("FATAL crash", filters))
      assert.is_true(filter.matches("CRITICAL crash", filters))
      assert.is_false(filter.matches("ERROR crash", filters))
    end)

    it("handles level DEBUG shows everything except TRACE", function()
      local filters = { level = "DEBUG" }
      assert.is_true(filter.matches("DEBUG test", filters))
      assert.is_true(filter.matches("INFO test", filters))
      assert.is_true(filter.matches("CRITICAL test", filters))
      assert.is_false(filter.matches("TRACE test", filters))
    end)

    it("returns true for lines with no recognized level when level filter active", function()
      local filters = { level = "ERROR" }
      assert.is_true(filter.matches("  at com.example.Main.run(Main.java:42)", filters))
    end)
  end)

  describe("build_display_line", function()
    it("formats line with tag prefix", function()
      local result = filter.build_display_line("api-pod", "INFO request received")
      assert.equals("[api-pod]  INFO request received", result)
    end)
  end)

  describe("get_filtered_lines", function()
    it("returns all lines when no filter", function()
      local raw_lines = {
        { tag = "pod1", text = "INFO hello" },
        { tag = "pod1", text = "ERROR bad" },
      }
      local result = filter.get_filtered_lines(raw_lines, {})
      assert.equals(2, #result)
    end)

    it("returns only matching lines", function()
      local raw_lines = {
        { tag = "pod1", text = "INFO hello" },
        { tag = "pod1", text = "ERROR bad" },
        { tag = "pod1", text = "WARN hmm" },
      }
      local result = filter.get_filtered_lines(raw_lines, { level = "WARN" })
      assert.equals(2, #result)
      assert.equals("[pod1]  ERROR bad", result[1].display)
      assert.equals("[pod1]  WARN hmm", result[2].display)
    end)
  end)
end)
