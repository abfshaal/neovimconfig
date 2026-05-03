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

  describe("build_compose_list_cmd", function()
    it("includes compose service filter", function()
      local cmd = docker.build_compose_list_cmd()
      assert.same({
        "docker", "ps", "--filter", "label=com.docker.compose.service", "--format", "{{json .}}",
      }, cmd)
    end)
  end)

  describe("parse_compose_services", function()
    it("groups containers by compose service", function()
      local lines = {
        '{"ID":"a1","Names":"proj-web-1","Status":"Up","Image":"nginx","Labels":"com.docker.compose.project=proj,com.docker.compose.service=web"}',
        '{"ID":"a2","Names":"proj-web-2","Status":"Up","Image":"nginx","Labels":"com.docker.compose.project=proj,com.docker.compose.service=web"}',
        '{"ID":"b1","Names":"proj-api-1","Status":"Up","Image":"node","Labels":"com.docker.compose.project=proj,com.docker.compose.service=api"}',
      }
      local services = docker.parse_compose_services(lines)
      assert.is_not_nil(services["proj/web"])
      assert.equals(2, #services["proj/web"].containers)
      assert.equals("web", services["proj/web"].service)
      assert.is_not_nil(services["proj/api"])
      assert.equals(1, #services["proj/api"].containers)
      assert.equals("api", services["proj/api"].service)
    end)

    it("skips containers without compose labels", function()
      local lines = {
        '{"ID":"x1","Names":"standalone","Status":"Up","Image":"redis","Labels":""}',
      }
      local services = docker.parse_compose_services(lines)
      local count = 0
      for _ in pairs(services) do count = count + 1 end
      assert.equals(0, count)
    end)
  end)

  describe("get_tag", function()
    it("returns container name as tag", function()
      local target = { id = "abc", name = "my-container", status = "Up", image = "nginx" }
      assert.equals("my-container", docker.get_tag(target))
    end)
  end)
end)
