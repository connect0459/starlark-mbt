# server.star — pure-Starlark version of the config DSL example.
#
# Contrast with main.mbt: here the config is defined and printed entirely in
# Starlark itself.  Run via:  moon run cmd -- examples/config_dsl/server.star

# ---------------------------------------------------------------------------
# Configuration (what a user would write in a .star config file)
# ---------------------------------------------------------------------------

server = {"host": "localhost", "port": 8080}

routes = [
    {"method": "GET",  "path": "/",             "handler": "index"},
    {"method": "GET",  "path": "/api/v1/users",  "handler": "list_users"},
    {"method": "POST", "path": "/api/v1/users",  "handler": "create_user"},
    {"method": "GET",  "path": "/api/v1/health", "handler": "healthcheck"},
]

middleware = ["logging", "cors", "auth"]

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

print("=== Server Configuration ===")
print("  Host: " + server["host"])
print("  Port: " + str(server["port"]))
print("")

print("=== Middleware Chain ===")
for i, mw in enumerate(middleware):
    print("  " + str(i + 1) + ". " + mw)
print("")

print("=== Route Table ===")
for route in routes:
    print("  " + route["method"] + "  " + route["path"] + "  ->  " + route["handler"])
