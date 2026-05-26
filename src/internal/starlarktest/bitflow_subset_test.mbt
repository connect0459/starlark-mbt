// Compliance tests for the Starlark subset used by the bitflow workflow DSL.
// Reference: .connect0459/ref-repos/bitflow/src/starlark/ (MoonBit Starlark Subset Contract)
//
// Bitflow uses Starlark as a workflow configuration language. These tests
// exercise the Starlark language features that appear in real bitflow workflow
// files: variable references in call arguments, conditionals, for loops,
// function definitions with defaults, list comprehensions, and dict operations.

// --- 1. Variable assignment and use as function argument ---

///|
let bitflow_vars_src : String =
  #|load("assert.star", "assert")
  #|
  #|profile = "prod"
  #|max_parallel = 4
  #|
  #|workflow_name = "ci-" + profile
  #|assert.eq(workflow_name, "ci-prod")
  #|
  #|limit = max_parallel * 2
  #|assert.eq(limit, 8)
  #|
  #|is_prod = profile == "prod"
  #|assert.true(is_prod)

///|
test "bitflow subset: variables used in expressions and comparisons" {
  let errs = run_star_string(bitflow_vars_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 2. Conditional expressions for configuration ---

///|
let bitflow_conditionals_src : String =
  #|load("assert.star", "assert")
  #|
  #|env = "staging"
  #|region = "us-east" if env == "prod" else "eu-west"
  #|assert.eq(region, "eu-west")
  #|
  #|timeout = 300 if env == "prod" else 60
  #|assert.eq(timeout, 60)
  #|
  #|env = "prod"
  #|region = "us-east" if env == "prod" else "eu-west"
  #|assert.eq(region, "us-east")
  #|
  #|parallelism = 8 if env == "prod" else (4 if env == "staging" else 1)
  #|assert.eq(parallelism, 8)

///|
test "bitflow subset: conditional expressions select configuration values" {
  let errs = run_star_string(bitflow_conditionals_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 3. For loop building a list of tasks ---

///|
let bitflow_forloop_src : String =
  #|load("assert.star", "assert")
  #|
  #|nodes = ["api", "web", "db"]
  #|build_tasks = []
  #|for n in nodes:
  #|    build_tasks.append(n + ":build")
  #|
  #|assert.eq(build_tasks, ["api:build", "web:build", "db:build"])
  #|
  #|test_tasks = []
  #|for n in nodes:
  #|    test_tasks.append(n + ":test")
  #|
  #|assert.eq(len(build_tasks), len(test_tasks))
  #|assert.eq(test_tasks[0], "api:test")
  #|assert.eq(test_tasks[2], "db:test")

///|
test "bitflow subset: for loop builds task id lists" {
  let errs = run_star_string(bitflow_forloop_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 4. Function definitions with defaults (workflow declarators) ---

///|
let bitflow_func_defaults_src : String =
  #|load("assert.star", "assert")
  #|
  #|def make_node(id, depends_on=None, required=True):
  #|    return {"id": id, "depends_on": depends_on or [], "required": required}
  #|
  #|def make_task(id, cmd, node, needs=None, cwd=""):
  #|    return {"id": id, "cmd": cmd, "node": node, "needs": needs or [], "cwd": cwd}
  #|
  #|root = make_node("root")
  #|assert.eq(root["id"], "root")
  #|assert.eq(root["depends_on"], [])
  #|assert.eq(root["required"], True)
  #|
  #|child = make_node("child", depends_on=["root"], required=False)
  #|assert.eq(child["id"], "child")
  #|assert.eq(child["depends_on"], ["root"])
  #|assert.eq(child["required"], False)
  #|
  #|t = make_task("root:build", "make build", "root")
  #|assert.eq(t["id"], "root:build")
  #|assert.eq(t["cmd"], "make build")
  #|assert.eq(t["needs"], [])
  #|assert.eq(t["cwd"], "")
  #|
  #|t2 = make_task("root:test", "make test", "root", needs=["root:build"], cwd="packages/root")
  #|assert.eq(t2["needs"], ["root:build"])
  #|assert.eq(t2["cwd"], "packages/root")

///|
test "bitflow subset: function definitions with defaults model workflow declarators" {
  let errs = run_star_string(bitflow_func_defaults_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 5. List comprehension for building derived task sets ---

///|
let bitflow_comprehension_src : String =
  #|load("assert.star", "assert")
  #|
  #|nodes = ["api", "web", "db"]
  #|
  #|build_tasks = [n + ":build" for n in nodes]
  #|assert.eq(build_tasks, ["api:build", "web:build", "db:build"])
  #|
  #|test_tasks = [n + ":test" for n in nodes]
  #|assert.eq(test_tasks, ["api:test", "web:test", "db:test"])
  #|
  #|required_nodes = [n for n in nodes if n != "db"]
  #|assert.eq(required_nodes, ["api", "web"])
  #|
  #|task_pairs = [(n, n + ":build") for n in nodes]
  #|assert.eq(task_pairs[0], ("api", "api:build"))

///|
test "bitflow subset: list comprehension generates task sets from node lists" {
  let errs = run_star_string(bitflow_comprehension_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 6. Dict operations for workflow configuration ---

///|
let bitflow_dict_src : String =
  #|load("assert.star", "assert")
  #|
  #|workflow = {
  #|    "name": "ci",
  #|    "max_parallel": 4,
  #|    "env": "prod",
  #|}
  #|
  #|assert.eq(workflow["name"], "ci")
  #|assert.eq(workflow["max_parallel"], 4)
  #|assert.eq(workflow.get("env", "dev"), "prod")
  #|assert.eq(workflow.get("region", "us-east"), "us-east")
  #|
  #|env_config = {"NODE_ENV": "production", "PORT": "8080"}
  #|assert.eq(env_config["NODE_ENV"], "production")
  #|assert.eq(len(env_config), 2)
  #|assert.eq(list(env_config.keys()), ["NODE_ENV", "PORT"])

///|
test "bitflow subset: dict operations for workflow configuration" {
  let errs = run_star_string(bitflow_dict_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 7. String operations (cmd construction, id formatting) ---

///|
let bitflow_string_ops_src : String =
  #|load("assert.star", "assert")
  #|
  #|prefix = "ci"
  #|version = "v2"
  #|workflow_id = prefix + "-" + version
  #|assert.eq(workflow_id, "ci-v2")
  #|
  #|services = ["api", "web", "worker"]
  #|deploy_cmds = ["deploy " + s for s in services]
  #|assert.eq(deploy_cmds[0], "deploy api")
  #|assert.eq(deploy_cmds[2], "deploy worker")
  #|
  #|cmd_parts = ["echo", "hello", "world"]
  #|cmd = " ".join(cmd_parts)
  #|assert.eq(cmd, "echo hello world")
  #|
  #|task_id = "root:build"
  #|parts = task_id.split(":")
  #|assert.eq(parts[0], "root")
  #|assert.eq(parts[1], "build")

///|
test "bitflow subset: string operations for command and id construction" {
  let errs = run_star_string(bitflow_string_ops_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 8. End-to-end workflow simulation ---

///|
let bitflow_workflow_simulation_src : String =
  #|load("assert.star", "assert")
  #|
  #|# Configuration
  #|profile = "prod"
  #|max_parallel = 4
  #|base_image = "ubuntu-22.04"
  #|
  #|# Helper builders
  #|def node(id, depends_on=None, required=True):
  #|    return {"id": id, "depends_on": depends_on or [], "required": required}
  #|
  #|def task(id, node_id, cmd, needs=None, env=None):
  #|    return {
  #|        "id": id,
  #|        "node": node_id,
  #|        "cmd": cmd,
  #|        "needs": needs or [],
  #|        "env": env or {},
  #|    }
  #|
  #|# Build the workflow
  #|services = ["api", "web", "db"]
  #|
  #|nodes = [node(s, required=(s != "db")) for s in services]
  #|assert.eq(len(nodes), 3)
  #|assert.eq(nodes[0]["id"], "api")
  #|assert.true(nodes[0]["required"])
  #|assert.eq(nodes[2]["id"], "db")
  #|assert.true(not nodes[2]["required"])
  #|
  #|build_tasks = [
  #|    task(s + ":build", s, "make build", env={"PROFILE": profile})
  #|    for s in services
  #|]
  #|assert.eq(len(build_tasks), 3)
  #|assert.eq(build_tasks[0]["id"], "api:build")
  #|assert.eq(build_tasks[0]["env"]["PROFILE"], "prod")
  #|
  #|test_tasks = [
  #|    task(s + ":test", s, "make test", needs=[s + ":build"])
  #|    for s in services
  #|]
  #|assert.eq(len(test_tasks), 3)
  #|assert.eq(test_tasks[1]["needs"], ["web:build"])
  #|
  #|# Conditional parallelism
  #|parallelism = max_parallel if profile == "prod" else 1
  #|assert.eq(parallelism, 4)
  #|
  #|# Entrypoint calculation
  #|entry_targets = [s + ":test" for s in services]
  #|assert.eq(entry_targets, ["api:test", "web:test", "db:test"])

///|
test "bitflow subset: end-to-end workflow simulation" {
  let errs = run_star_string(bitflow_workflow_simulation_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

// --- 9. Load pattern: helper functions from loaded module ---

///|
let bitflow_load_helpers_src : String =
  #|load("assert.star", "assert", "freeze")
  #|
  #|# Simulate a loaded helper module: a function from assert.star
  #|# Tests that load() binds module members accessible by name
  #|assert.eq(type(assert), "module")
  #|
  #|# Freeze simulates immutable workflow config (like a loaded const file)
  #|config = {"env": "prod", "version": "1.0"}
  #|freeze(config)
  #|assert.fails(lambda: config.update({"env": "dev"}), "frozen")

///|
test "bitflow subset: load() binds helpers and freeze() locks config dicts" {
  let errs = run_star_string(bitflow_load_helpers_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
