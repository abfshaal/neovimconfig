describe("docklog.providers.kubernetes", function()
  local k8s

  before_each(function()
    package.loaded["docklog.providers.kubernetes"] = nil
    package.loaded["docklog.config"] = nil
    require("docklog.config").setup({})
    k8s = require("docklog.providers.kubernetes")
  end)

  describe("build_log_cmd", function()
    it("builds correct kubectl logs command", function()
      local target = { name = "api-pod", namespace = "default" }
      local cmd = k8s.build_log_cmd(target)
      assert.same({
        "kubectl", "logs", "-f", "--tail=100", "-n", "default", "api-pod",
      }, cmd)
    end)

    it("appends container flag for multi-container pod", function()
      local target = { name = "api-pod", namespace = "default", container = "sidecar" }
      local cmd = k8s.build_log_cmd(target)
      assert.same({
        "kubectl", "logs", "-f", "--tail=100", "-n", "default", "api-pod", "-c", "sidecar",
      }, cmd)
    end)

    it("uses configured tail_lines", function()
      require("docklog.config").setup({ tail_lines = 200 })
      local target = { name = "api-pod", namespace = "default" }
      local cmd = k8s.build_log_cmd(target)
      assert.same({
        "kubectl", "logs", "-f", "--tail=200", "-n", "default", "api-pod",
      }, cmd)
    end)

    it("uses configured kubeconfig", function()
      require("docklog.config").setup({ k8s = { kubeconfig = "/tmp/kubeconfig" } })
      local target = { name = "api-pod", namespace = "default" }
      local cmd = k8s.build_log_cmd(target)
      assert.same({
        "kubectl", "--kubeconfig", "/tmp/kubeconfig",
        "logs", "-f", "--tail=100", "-n", "default", "api-pod",
      }, cmd)
    end)
  end)

  describe("parse_pods_json", function()
    it("parses kubectl get pods JSON into targets", function()
      local json_str = vim.json.encode({
        items = {
          {
            metadata = { name = "api-pod", namespace = "default" },
            status = { phase = "Running" },
            spec = { containers = { { name = "app" } } },
          },
        },
      })
      local targets = k8s.parse_pods_json(json_str, "default")
      assert.equals(1, #targets)
      assert.equals("api-pod", targets[1].name)
      assert.equals("default", targets[1].namespace)
      assert.equals("Running", targets[1].status)
      assert.is_nil(targets[1].container)
    end)

    it("expands multi-container pods into separate targets", function()
      local json_str = vim.json.encode({
        items = {
          {
            metadata = { name = "web-pod", namespace = "prod" },
            status = { phase = "Running" },
            spec = {
              containers = {
                { name = "app" },
                { name = "sidecar" },
              },
            },
          },
        },
      })
      local targets = k8s.parse_pods_json(json_str, "prod")
      assert.equals(2, #targets)
      assert.equals("web-pod", targets[1].name)
      assert.equals("app", targets[1].container)
      assert.equals("web-pod", targets[2].name)
      assert.equals("sidecar", targets[2].container)
    end)
  end)

  describe("parse_namespaces_json", function()
    it("parses kubectl get namespaces JSON", function()
      local json_str = vim.json.encode({
        items = {
          { metadata = { name = "default" } },
          { metadata = { name = "kube-system" } },
          { metadata = { name = "prod" } },
        },
      })
      local namespaces = k8s.parse_namespaces_json(json_str)
      assert.same({ "default", "kube-system", "prod" }, namespaces)
    end)
  end)

  describe("parse_deployments_json", function()
    it("parses kubectl get deployments JSON", function()
      local json_str = vim.json.encode({
        items = {
          {
            metadata = { name = "api", namespace = "default" },
            spec = {
              replicas = 3,
              selector = { matchLabels = { app = "api", tier = "backend" } },
            },
            status = { readyReplicas = 3 },
          },
        },
      })
      local deps = k8s.parse_deployments_json(json_str, "default")
      assert.equals(1, #deps)
      assert.equals("api", deps[1].name)
      assert.equals("default", deps[1].namespace)
      assert.equals(3, deps[1].replicas)
      assert.equals(3, deps[1].desired)
      assert.same({ app = "api", tier = "backend" }, deps[1].match_labels)
    end)

    it("handles deployment with no selector", function()
      local json_str = vim.json.encode({
        items = {
          {
            metadata = { name = "simple", namespace = "default" },
            spec = { replicas = 1 },
            status = { readyReplicas = 1 },
          },
        },
      })
      local deps = k8s.parse_deployments_json(json_str, "default")
      assert.equals(1, #deps)
      assert.same({}, deps[1].match_labels)
    end)
  end)

  describe("labels_to_selector", function()
    it("converts single label to selector string", function()
      assert.equals("app=api", k8s.labels_to_selector({ app = "api" }))
    end)

    it("converts multiple labels sorted alphabetically", function()
      local result = k8s.labels_to_selector({ tier = "backend", app = "api" })
      assert.equals("app=api,tier=backend", result)
    end)
  end)

  describe("get_tag", function()
    it("returns pod name for single-container pod", function()
      local target = { name = "api-pod", namespace = "default" }
      assert.equals("api-pod", k8s.get_tag(target))
    end)

    it("returns pod/container for multi-container pod", function()
      local target = { name = "web-pod", namespace = "default", container = "sidecar" }
      assert.equals("web-pod/sidecar", k8s.get_tag(target))
    end)
  end)
end)
