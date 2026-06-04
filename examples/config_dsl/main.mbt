// Starlark as a configuration language.
//
// Demonstrates:
//   - exec_file + Module::get: reading named globals from a script
//   - Value pattern matching: decoding dicts, lists, strings, and ints

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
    #|server = {"host": "localhost", "port": 8080}
    #|
    #|routes = [
    #|    {"method": "GET",  "path": "/",             "handler": "index"},
    #|    {"method": "GET",  "path": "/api/v1/users",  "handler": "list_users"},
    #|    {"method": "POST", "path": "/api/v1/users",  "handler": "create_user"},
    #|    {"method": "GET",  "path": "/api/v1/health", "handler": "healthcheck"},
    #|]
    #|
    #|middleware = ["logging", "cors", "auth"]
  let thread = @eval.Thread::new("config")
  match @eval.exec_file(thread, "server.star", src, @eval.Options::default()) {
    Err(e) => println("Config error: \{e.msg()}")
    Ok(m) => {
      match m.get("server") {
        Some(@value.Value::Dict(d)) => {
          let host = dict_str(d, "host")
          let port = dict_int(d, "port")
          println("=== Server Configuration ===")
          println("  Host: \{host}")
          println("  Port: \{port}")
        }
        _ => ()
      }
      println("")
      match m.get("middleware") {
        Some(@value.Value::List(lst)) => {
          println("=== Middleware Chain ===")
          let mut idx = 1
          for v in lst.iter() {
            match v {
              @value.Value::String(s) => {
                println("  \{idx}. \{s.raw()}")
                idx = idx + 1
              }
              _ => ()
            }
          }
          println("")
        }
        _ => ()
      }
      match m.get("routes") {
        Some(@value.Value::List(lst)) => {
          println("=== Route Table ===")
          for v in lst.iter() {
            match v {
              @value.Value::Dict(d) => {
                let http_method = dict_str(d, "method")
                let path = dict_str(d, "path")
                let handler = dict_str(d, "handler")
                println("  \{http_method}  \{path}  ->  \{handler}")
              }
              _ => ()
            }
          }
        }
        _ => ()
      }
    }
  }
}
