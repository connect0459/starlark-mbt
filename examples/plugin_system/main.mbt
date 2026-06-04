// Plugin / scripting extension: MoonBit host provides built-ins for scripts.
//
// Demonstrates:
//   - Universe::set: registering MoonBit functions as Starlark built-ins
//   - Closures capturing host state updated by script calls
//   - Simulating host services (log, fetch, emit) callable from Starlark

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
fn level_tag(level : String) -> String {
  match level {
    "info" => "INFO "
    "debug" => "DEBUG"
    "warn" => "WARN "
    "error" => "ERROR"
    _ => level
  }
}

///|
fn main {
  let logs : Array[(String, String)] = []
  let events : Array[(String, @value.Value)] = []
  let universe = @eval.Universe::new()

  // log(level, msg) — record a log entry in the host
  universe.set(
    "log",
    @value.Value::new_builtin("log", fn(_ctx, args, _kws) {
      if args.length() != 2 {
        return Err("log: expected 2 arguments, got \{args.length()}")
      }
      let level = match args[0] {
        @value.Value::String(s) => s.raw()
        v => v.to_str()
      }
      let msg = match args[1] {
        @value.Value::String(s) => s.raw()
        v => v.to_str()
      }
      logs.push((level, msg))
      Ok(@value.Value::None)
    }),
  )

  // fetch(url) — return simulated API data
  let mock_response = make_dict([
    (
      "items",
      list_val([
        make_dict([("id", int_val(1)), ("value", int_val(10))]),
        make_dict([("id", int_val(2)), ("value", int_val(21))]),
        make_dict([("id", int_val(3)), ("value", int_val(4))]),
      ]),
    ),
    ("status", str_val("ok")),
  ])
  universe.set(
    "fetch",
    @value.Value::new_builtin("fetch", fn(_ctx, _args, _kws) {
      Ok(mock_response)
    }),
  )

  // emit(event, payload) — record a host-side event
  universe.set(
    "emit",
    @value.Value::new_builtin("emit", fn(_ctx, args, _kws) {
      if args.length() != 2 {
        return Err("emit: expected 2 arguments, got \{args.length()}")
      }
      let event = match args[0] {
        @value.Value::String(s) => s.raw()
        v => v.to_str()
      }
      events.push((event, args[1]))
      Ok(@value.Value::None)
    }),
  )

  let src =
    #|log("info", "Plugin starting up")
    #|
    #|response = fetch("/api/data")
    #|log("debug", "Fetched " + str(len(response["items"])) + " items")
    #|
    #|for item in response["items"]:
    #|    emit("item.processed", {"id": item["id"], "value": item["value"] * 2})
    #|
    #|log("info", "Done processing " + str(len(response["items"])) + " items")
  let thread = @eval.Thread::new("plugin")
  match
    @eval.exec_file_with_universe(
      thread,
      "plugin.star",
      src,
      @eval.Options::default(),
      universe,
    ) {
    Err(e) => println("Plugin error: \{e.msg()}")
    Ok(_) => {
      println("=== Plugin Log ===")
      for entry in logs {
        println("  [\{level_tag(entry.0)}] \{entry.1}")
      }
      println("")
      println("=== Emitted Events ===")
      for entry in events {
        println("  \{entry.0}  \{entry.1.repr()}")
      }
    }
  }
}
