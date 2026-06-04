# plugin.star — pure-Starlark version of the plugin_system example.
#
# Contrast with main.mbt: here log, fetch, and emit are stubbed in Starlark
# itself instead of being provided by the MoonBit host.
# Run via:  moon run cmd -- examples/plugin_system/plugin.star

# ---------------------------------------------------------------------------
# Host service stubs (replaced by MoonBit built-ins in the embedded version)
# ---------------------------------------------------------------------------

_TAGS = {"info": "INFO ", "debug": "DEBUG", "warn": "WARN ", "error": "ERROR"}
_logs = []
_events = []

def log(level, msg):
    _logs.append((level, msg))

def fetch(_url):
    return {
        "items": [
            {"id": 1, "value": 10},
            {"id": 2, "value": 21},
            {"id": 3, "value": 4},
        ],
        "status": "ok",
    }

def emit(event, payload):
    _events.append((event, payload))

# ---------------------------------------------------------------------------
# Plugin script (identical to what the MoonBit host executes)
# ---------------------------------------------------------------------------

log("info", "Plugin starting up")

response = fetch("/api/data")
log("debug", "Fetched " + str(len(response["items"])) + " items")

for item in response["items"]:
    emit("item.processed", {"id": item["id"], "value": item["value"] * 2})

log("info", "Done processing " + str(len(response["items"])) + " items")

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

print("=== Plugin Log ===")
for entry in _logs:
    tag = _TAGS.get(entry[0], entry[0])
    print("  [" + tag + "] " + entry[1])
print("")

print("=== Emitted Events ===")
for entry in _events:
    print("  " + entry[0] + "  " + repr(entry[1]))
