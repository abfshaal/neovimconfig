return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Setup dap-ui
      dapui.setup({
        floating = {
          max_height = 0.9,
          max_width = 0.9,
        },
      })

      -- Setup virtual text
      require("nvim-dap-virtual-text").setup()

      -- Custom breakpoint signs
      vim.fn.sign_define("DapBreakpoint", {
        text = "🔴",
        texthl = "DapBreakpoint",
        linehl = "",
        numhl = "DapBreakpoint",
      })
      vim.fn.sign_define("DapBreakpointCondition", {
        text = "🟡",
        texthl = "DapBreakpointCondition",
        linehl = "",
        numhl = "DapBreakpointCondition",
      })
      vim.fn.sign_define("DapBreakpointRejected", {
        text = "❌",
        texthl = "DapBreakpointRejected",
        linehl = "",
        numhl = "DapBreakpointRejected",
      })
      vim.fn.sign_define("DapLogPoint", {
        text = "💬",
        texthl = "DapLogPoint",
        linehl = "",
        numhl = "DapLogPoint",
      })
      vim.fn.sign_define("DapStopped", {
        text = "👉",
        texthl = "DapStopped",
        linehl = "DapStoppedLine",
        numhl = "DapStopped",
      })

      -- Auto open/close dap-ui
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -- Fix keybindings in DAP UI buffers (use normal mode, not insert mode)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dapui_*",
        callback = function()
          vim.bo.modifiable = true
        end,
      })

      -- Debug keymaps
      vim.keymap.set("n", "dr", dap.continue, { desc = "Debug: Continue/Start debugging" })
      vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Debug: Step over" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: Step into" })
      vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Debug: Step out" })
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle breakpoint" })
      vim.keymap.set("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Debug: Set conditional breakpoint" })
      vim.keymap.set("n", "<leader>dR", dap.repl.open, { desc = "Debug: Open REPL" })
      vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run last configuration" })

      -- DAP UI keymaps
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug UI: Toggle" })
      vim.keymap.set("n", "<leader>dU", dapui.open, { desc = "Debug UI: Open" })
      vim.keymap.set("n", "<leader>dx", dapui.close, { desc = "Debug UI: Close" })
      vim.keymap.set("n", "<leader>de", function()
        dapui.eval()
      end, { desc = "Debug UI: Evaluate expression" })
      vim.keymap.set("v", "<leader>de", function()
        dapui.eval()
      end, { desc = "Debug UI: Evaluate selection" })

      -- Float element keymaps
      vim.keymap.set("n", "<leader>ds", function()
        dapui.float_element("scopes")
      end, { desc = "Debug UI: Float scopes" })
      vim.keymap.set("n", "<leader>dk", function()
        dapui.float_element("stacks")
      end, { desc = "Debug UI: Float stacks" })
      vim.keymap.set("n", "<leader>dw", function()
        dapui.float_element("watches")
      end, { desc = "Debug UI: Float watches" })
      vim.keymap.set("n", "<leader>dp", function()
        dapui.float_element("breakpoints")
      end, { desc = "Debug UI: Float breakpoints" })
      vim.keymap.set("n", "<leader>dt", function()
        dapui.float_element("console")
      end, { desc = "Debug UI: Float console" })
      vim.keymap.set("n", "<leader>df", function()
        dapui.float_element("repl")
      end, { desc = "Debug UI: Float REPL" })

      -- Terminate debugging session
      vim.keymap.set("n", "<leader>dT", dap.terminate, { desc = "Debug: Terminate session" })

      -- <C-f> prefix variants
      vim.keymap.set("n", "<C-f>do", dap.step_over, { desc = "Debug: Step over (C-f)" })
      vim.keymap.set("n", "<C-f>di", dap.step_into, { desc = "Debug: Step into (C-f)" })
      vim.keymap.set("n", "<C-f>dO", dap.step_out, { desc = "Debug: Step out (C-f)" })
      vim.keymap.set("n", "<C-f>db", dap.toggle_breakpoint, { desc = "Debug: Toggle breakpoint (C-f)" })
      vim.keymap.set("n", "<C-f>dB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Debug: Set conditional breakpoint (C-f)" })
      vim.keymap.set("n", "<C-f>dR", dap.repl.open, { desc = "Debug: Open REPL (C-f)" })
      vim.keymap.set("n", "<C-f>dl", dap.run_last, { desc = "Debug: Run last configuration (C-f)" })
      vim.keymap.set("n", "<C-f>du", dapui.toggle, { desc = "Debug UI: Toggle (C-f)" })
      vim.keymap.set("n", "<C-f>dU", dapui.open, { desc = "Debug UI: Open (C-f)" })
      vim.keymap.set("n", "<C-f>dx", dapui.close, { desc = "Debug UI: Close (C-f)" })
      vim.keymap.set("n", "<C-f>de", function() dapui.eval() end, { desc = "Debug UI: Evaluate (C-f)" })
      vim.keymap.set("v", "<C-f>de", function() dapui.eval() end, { desc = "Debug UI: Evaluate selection (C-f)" })
      vim.keymap.set("n", "<C-f>ds", function() dapui.float_element("scopes") end, { desc = "Debug UI: Float scopes (C-f)" })
      vim.keymap.set("n", "<C-f>dk", function() dapui.float_element("stacks") end, { desc = "Debug UI: Float stacks (C-f)" })
      vim.keymap.set("n", "<C-f>dw", function() dapui.float_element("watches") end, { desc = "Debug UI: Float watches (C-f)" })
      vim.keymap.set("n", "<C-f>dp", function() dapui.float_element("breakpoints") end, { desc = "Debug UI: Float breakpoints (C-f)" })
      vim.keymap.set("n", "<C-f>dt", function() dapui.float_element("console") end, { desc = "Debug UI: Float console (C-f)" })
      vim.keymap.set("n", "<C-f>df", function() dapui.float_element("repl") end, { desc = "Debug UI: Float REPL (C-f)" })
      vim.keymap.set("n", "<C-f>dT", dap.terminate, { desc = "Debug: Terminate session (C-f)" })
    end,
  },
  {
    "mfussenegger/nvim-dap-python",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    config = function()
      local dap_python = require("dap-python")

      -- Try to find python in current conda environment first, then fallback to system
      local function find_python()
        local conda_prefix = vim.env.CONDA_PREFIX
        if conda_prefix then
          return conda_prefix .. "/bin/python"
        end
        return "python3" -- fallback
      end

      dap_python.setup(find_python())

      -- FastAPI/uvicorn debug configuration
      table.insert(require("dap").configurations.python, {
        type = "python",
        request = "launch",
        name = "FastAPI Server (meetings)",
        module = "uvicorn",
        args = {
          "meetings.src.main:app",
          "--reload",
          "--host",
          "127.0.0.1",
          "--port",
          "8083",
        },
        env = function()
          -- You can modify these environment variables as needed
          local env = vim.fn.environ()
          -- Add any specific environment variables here
          -- env.DATABASE_URL = "your_database_url"
          -- env.SECRET_KEY = "your_secret_key"
          env.testvar = "test123"
          return env
        end,
        console = "integratedTerminal",
        justMyCode = false, -- Set to true if you only want to debug your code
        cwd = "${workspaceFolder}",
      })

      table.insert(require("dap").configurations.python, {
        type = "python",
        request = "launch",
        name = "FastAPI Server (workflowvibe)",
        module = "uvicorn",
        args = {
          "src.main:app",
          "--reload",
        },
        console = "integratedTerminal",
        justMyCode = false,
        cwd = "/Users/abdulraheem.shaal1/workflowvibe/backend",
      })

      -- Additional Python debugging keymaps
      vim.keymap.set("n", "<leader>dm", function()
        dap_python.test_method()
      end, { desc = "Debug Python test method" })
      vim.keymap.set("n", "<leader>dc", function()
        dap_python.test_class()
      end, { desc = "Debug Python test class" })

      -- <C-f> prefix variants
      vim.keymap.set("n", "<C-f>dm", function() dap_python.test_method() end, { desc = "Debug Python test method (C-f)" })
      vim.keymap.set("n", "<C-f>dc", function() dap_python.test_class() end, { desc = "Debug Python test class (C-f)" })
    end,
  },
}
