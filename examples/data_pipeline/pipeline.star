# pipeline.star — pure-Starlark version of the data_pipeline example.
#
# Contrast with main.mbt: here normalize, filter_valid, and summarize are
# defined and called entirely in Starlark.
# Run via:  moon run cmd -- examples/data_pipeline/pipeline.star

# ---------------------------------------------------------------------------
# Transformation functions
# ---------------------------------------------------------------------------

def normalize(record):
    return {
        "id":    record["id"],
        "name":  record.get("name", "").strip().lower(),
        "score": max(0, min(100, record.get("score", 0))),
        "tags":  [t.lower() for t in record.get("tags", [])],
    }

def filter_valid(records):
    return [r for r in records if r["score"] >= 50]

def summarize(records):
    if not records:
        return {"count": 0, "avg_score": 0, "top": ""}
    total = 0
    best_score = -1
    best_name = ""
    for r in records:
        total = total + r["score"]
        if r["score"] > best_score:
            best_score = r["score"]
            best_name = r["name"]
    return {"count": len(records), "avg_score": total // len(records), "top": best_name}

# ---------------------------------------------------------------------------
# Input records
# ---------------------------------------------------------------------------

raw_records = [
    {"id": 1, "name": " Alice ", "score": 85, "tags": ["Dev", "Lead"]},
    {"id": 2, "name": "bob",     "score": 40, "tags": ["QA"]},
    {"id": 3, "name": "  CAROL", "score": 92, "tags": ["Dev", "Arch"]},
    {"id": 4, "name": "dave",    "score": 55, "tags": []},
]

# ---------------------------------------------------------------------------
# Pipeline execution
# ---------------------------------------------------------------------------

normalized = [normalize(r) for r in raw_records]

print("=== After normalize ===")
for r in normalized:
    print("  " + repr(r))
print("")

filtered = filter_valid(normalized)

print("=== After filter_valid (score >= 50) ===")
for r in filtered:
    print("  " + repr(r))
print("")

result = summarize(filtered)

print("=== Summary ===")
print("  Count:     " + str(result["count"]))
print("  Avg score: " + str(result["avg_score"]))
print("  Top name:  " + result["top"])
