describe("docklog.providers.docker", function()
  local docker

  before_each(function()
    package.loaded["docklog.providers.docker"] = nil
    package.loaded["docklog.config"] = nil
    require("docklog.config").setup({})
    docker = require("docklog.providers.docker")
  end)

  describe("build_log_cmd", function()
    it("builds correct docker logs command", function()
      local target = { id = "abc123", name = "my-container" }
      local cmd = docker.build_log_cmd(target)
      assert.same({ "docker", "logs", "-f", "--tail", "100", "abc123" }, cmd)
    end)

    it("uses configured tail_lines", function()
      require("docklog.config").setup({ tail_lines = 50 })
      local target = { id = "abc123", name = "my-container" }
      local cmd = docker.build_log_cmd(target)
      assert.same({ "docker", "logs", "-f", "--tail", "50", "abc123" }, cmd)
    end)

    it("uses configured docker host", function()
      require("docklog.config").setup({ docker = { host = "tcp://remote:2375" } })
      local target = { id = "abc123", name = "my-container" }
      local cmd = docker.build_log_cmd(target)
      assert.same({ "docker", "-H", "tcp://remote:2375", "logs", "-f", "--tail", "100", "abc123" }, cmd)
    end)
  end)

  describe("parse_ps_output", function()
    it("parses docker ps JSON output into targets", function()
      local json_line = '{"ID":"abc123","Names":"my-app","Status":"Up 2 hours","Image":"nginx:latest"}'
      local targets = docker.parse_ps_output({ json_line })
      assert.equals(1, #targets)
      assert.equals("abc123", targets[1].id)
      assert.equals("my-app", targets[1].name)
      assert.equals("Up 2 hours", targets[1].status)
      assert.equals("nginx:latest", targets[1].image)
    end)

    it("handles multiple containers", function()
      local lines = {
        '{"ID":"abc","Names":"app1","Status":"Up","Image":"nginx"}',
        '{"ID":"def","Names":"app2","Status":"Up","Image":"redis"}',
      }
      local targets = docker.parse_ps_output(lines)
      assert.equals(2, #targets)
    end)

    it("skips invalid JSON lines", function()
      local lines = { "not json", '{"ID":"abc","Names":"app","Status":"Up","Image":"nginx"}' }
      local targets = docker.parse_ps_output(lines)
      assert.equals(1, #targets)
    end)
  end)

  describe("get_tag", function()
    it("returns container name as tag", function()
      local target = { id = "abc", name = "my-container", status = "Up", image = "nginx" }
      assert.equals("my-container", docker.get_tag(target))
    end)
  end)
end)
