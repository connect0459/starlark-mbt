# BUILD.star — pure-Starlark version of the build system example.
#
# Contrast with main.mbt: here rule functions, the rule registry, macro
# expansion, and topological sort are all written in Starlark itself.
# Run via:  moon run cmd -- examples/build_system/BUILD.star

# ---------------------------------------------------------------------------
# Rule registry
# ---------------------------------------------------------------------------

_rules = []

def _make_rule(kind):
    """Returns a rule function that appends to the global registry."""
    def rule(name, srcs=[], deps=[]):
        _rules.append({"name": name, "kind": kind, "srcs": srcs, "deps": deps})
    return rule

cc_library  = _make_rule("cc_library")
cc_binary   = _make_rule("cc_binary")
go_library  = _make_rule("go_library")
go_binary   = _make_rule("go_binary")
filegroup   = _make_rule("filegroup")

# ---------------------------------------------------------------------------
# Macro (would live in a .bzl file in a real build system)
# ---------------------------------------------------------------------------

def versioned_cc_library(name, version, srcs=[], deps=[]):
    """Creates a cc_library whose target name includes a version suffix."""
    cc_library(
        name = name + "_v" + str(version),
        srcs = srcs,
        deps = deps,
    )

# ---------------------------------------------------------------------------
# BUILD rules  (what a user would write in a BUILD file)
# ---------------------------------------------------------------------------

cc_library(
    name = "math",
    srcs = ["add.c", "mul.c"],
)

cc_library(
    name = "string_utils",
    srcs = ["string_utils.c"],
    deps = [":math"],
)

# Macro expands to cc_library(name="crypto_v2", ...)
versioned_cc_library(
    name = "crypto",
    version = 2,
    srcs = ["crypto.c"],
    deps = [":math"],
)

cc_binary(
    name = "server",
    srcs = ["main.c"],
    deps = [":math", ":string_utils", ":crypto_v2"],
)

# ---------------------------------------------------------------------------
# Build-order computation (topological sort in pure Starlark)
# ---------------------------------------------------------------------------

def _strip_colon(dep):
    return dep[1:] if dep.startswith(":") else dep

def _build_order(rules):
    done = []
    pending = list(rules)
    result = []
    while pending:
        progress = False
        next_pending = []
        for rule in pending:
            ready = True
            for raw_dep in rule["deps"]:
                dep = _strip_colon(raw_dep)
                is_local = any([r["name"] == dep for r in rules])
                if is_local and dep not in done:
                    ready = False
                    break
            if ready:
                result.append(rule)
                done.append(rule["name"])
                progress = True
            else:
                next_pending.append(rule)
        if not progress:
            result.extend(next_pending)
            break
        pending = next_pending
    return result

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

print("=== Registered Rules ===")
for rule in _rules:
    src_part = ("  srcs: [" + ", ".join(rule["srcs"]) + "]") if rule["srcs"] else ""
    dep_part = ("  deps: [" + ", ".join(rule["deps"]) + "]") if rule["deps"] else ""
    print("  " + rule["kind"] + "(name=\"" + rule["name"] + "\")" + src_part + dep_part)

print("")
print("=== Build Order ===")
for i, rule in enumerate(_build_order(_rules)):
    deps = [_strip_colon(d) for d in rule["deps"]]
    arrow = (" <- " + ", ".join(deps)) if deps else ""
    print("  " + str(i + 1) + ". " + rule["name"] + arrow)
