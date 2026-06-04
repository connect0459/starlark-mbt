// Data transformation pipeline: call Starlark functions from MoonBit.
//
// Demonstrates:
//   - @eval.call: invoking Starlark functions with MoonBit-constructed arguments
//   - Building Value objects to pass structured data into Starlark
//   - Round-tripping typed data through a Starlark transformation stage

///|
fn make_dict(entries : Array[(String, @value.Value)]) -> @value.Value {
  let sd = @value.StarlarkDict::new()
  for entry in entries {
    let _ = sd.set(@value.Value::new_string(entry.0), entry.1)
  }
  @value.Value::Dict(sd)
}

///|
fn int_val(n : Int) -> @value.Value {
  @value.Value::new_int(n.to_int64())
}

///|
fn str_val(s : String) -> @value.Value {
  @value.Value::new_string(s)
}

///|
fn list_val(items : Array[@value.Value]) -> @value.Value {
  @value.Value::new_list(items)
}

///|
fn dict_str(d : @value.StarlarkDict, key : String) -> String {
  match d.get(@value.Value::new_string(key)) {
    Ok(Some(@value.Value::String(s))) => s.raw()
    _ => ""
  }
}

///|
fn dict_int(d : @value.StarlarkDict, key : String) -> Int {
  match d.get(@value.Value::new_string(key)) {
    Ok(Some(v)) =>
      match @value.number_to_int(v) {
        Some(n) => n.to_int()
        None => 0
      }
    _ => 0
  }
}

///|
fn main {
  let src =
    #|def normalize(record):
    #|    return {
    #|        "id":    record["id"],
    #|        "name":  record.get("name", "").strip().lower(),
    #|        "score": max(0, min(100, record.get("score", 0))),
    #|        "tags":  [t.lower() for t in record.get("tags", [])],
    #|    }
    #|
    #|def filter_valid(records):
    #|    return [r for r in records if r["score"] >= 50]
    #|
    #|def _get_score(r):
    #|    return r["score"]
    #|
    #|def summarize(records):
    #|    if not records:
    #|        return {"count": 0, "avg_score": 0, "top": ""}
    #|    total = 0
    #|    best_score = -1
    #|    best_name = ""
    #|    for r in records:
    #|        total = total + r["score"]
    #|        if r["score"] > best_score:
    #|            best_score = r["score"]
    #|            best_name = r["name"]
    #|    return {"count": len(records), "avg_score": total // len(records), "top": best_name}
  let thread = @eval.Thread::new("pipeline")
  match
    @eval.exec_file(thread, "pipeline.star", src, @eval.Options::default()) {
    Err(e) => println("Script error: \{e.msg()}")
    Ok(m) =>
      match (m.get("normalize"), m.get("filter_valid"), m.get("summarize")) {
        (Some(norm_fn), Some(filt_fn), Some(summ_fn)) => {
          let raw_records = [
            make_dict([
              ("id", int_val(1)),
              ("name", str_val(" Alice ")),
              ("score", int_val(85)),
              ("tags", list_val([str_val("Dev"), str_val("Lead")])),
            ]),
            make_dict([
              ("id", int_val(2)),
              ("name", str_val("bob")),
              ("score", int_val(40)),
              ("tags", list_val([str_val("QA")])),
            ]),
            make_dict([
              ("id", int_val(3)),
              ("name", str_val("  CAROL")),
              ("score", int_val(92)),
              ("tags", list_val([str_val("Dev"), str_val("Arch")])),
            ]),
            make_dict([
              ("id", int_val(4)),
              ("name", str_val("dave")),
              ("score", int_val(55)),
              ("tags", list_val([])),
            ]),
          ]
          // Step 1: normalize each record
          let normalized : Array[@value.Value] = []
          for r in raw_records {
            match @eval.call(thread, norm_fn, [r], []) {
              Ok(v) => normalized.push(v)
              Err(e) => println("normalize error: \{e.msg()}")
            }
          }
          println("=== After normalize ===")
          for v in normalized {
            println("  \{v.repr()}")
          }
          println("")
          // Step 2: filter_valid
          match @eval.call(thread, filt_fn, [list_val(normalized)], []) {
            Err(e) => println("filter_valid error: \{e.msg()}")
            Ok(filtered) => {
              println("=== After filter_valid (score >= 50) ===")
              match filtered {
                @value.Value::List(lst) =>
                  for v in lst.iter() {
                    println("  \{v.repr()}")
                  }
                _ => ()
              }
              println("")
              // Step 3: summarize
              match @eval.call(thread, summ_fn, [filtered], []) {
                Err(e) => println("summarize error: \{e.msg()}")
                Ok(@value.Value::Dict(d)) => {
                  let count = dict_int(d, "count")
                  let avg = dict_int(d, "avg_score")
                  let top = dict_str(d, "top")
                  println("=== Summary ===")
                  println("  Count:     \{count}")
                  println("  Avg score: \{avg}")
                  println("  Top name:  \{top}")
                }
                Ok(v) => println("summarize returned: \{v.repr()}")
              }
            }
          }
        }
        _ => println("required function not found in script")
      }
  }
}
