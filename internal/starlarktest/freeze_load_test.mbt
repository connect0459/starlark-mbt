///|
fn run_load_mutation(loaded_src : String, main_src : String) -> String {
  let thread = @eval.Thread::with_loader("test", fn(_thread, path) {
    let inner = @eval.Thread::new("inner")
    @eval.exec_file(inner, path, loaded_src, @eval.Options::default())
  })
  match
    @eval.exec_file(thread, "main.star", main_src, @eval.Options::default()) {
    Ok(_) => "ok"
    Err(e) => e.msg()
  }
}

///|
test "loaded list is deeply frozen and cannot be mutated" {
  let loaded =
    #|x = [1, 2]
  let main =
    #|load("a.star", "x")
    #|x.append(99)
  inspect(
    run_load_mutation(loaded, main),
    content="cannot append to frozen list",
  )
}

///|
test "loaded dict is deeply frozen and cannot be mutated" {
  let loaded =
    #|d = {"a": 1}
  let main =
    #|load("a.star", "d")
    #|d.clear()
  inspect(
    run_load_mutation(loaded, main),
    content="cannot clear frozen hash table",
  )
}

///|
test "loaded set is deeply frozen and cannot be mutated" {
  let loaded =
    #|s = set([1, 2, 3])
  let main =
    #|load("a.star", "s")
    #|s.add(4)
  inspect(
    run_load_mutation(loaded, main),
    content="add: cannot insert into frozen hash table",
  )
}
