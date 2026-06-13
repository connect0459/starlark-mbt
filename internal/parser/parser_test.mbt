// Parser tests — TDD Red phase.

///|
fn parse_e(src : String) -> @syntax.Expr {
  match @parser.parse_expr("test.star", src) {
    Ok(e) => e
    Err(e) => abort("parse error: \{e.to_string()}")
  }
}

///|
fn parse_f(src : String) -> @syntax.File {
  match @parser.parse_file("test.star", src) {
    Ok(f) => f
    Err(e) => abort("parse error: \{e.to_string()}")
  }
}

// --- Literal expressions ---

///|
test "integer literal is parsed as LitInt" {
  match parse_e("42") {
    ELiteral(LitInt(42N), _) => ()
    _ => fail("expected LitInt(42)")
  }
}

///|
test "zero integer literal" {
  match parse_e("0") {
    ELiteral(LitInt(0N), _) => ()
    _ => fail("expected LitInt(0)")
  }
}

///|
test "hex integer literal" {
  match parse_e("0xFF") {
    ELiteral(LitInt(255N), _) => ()
    _ => fail("expected LitInt(255)")
  }
}

///|
test "float literal is parsed as LitFloat" {
  match parse_e("1.5") {
    ELiteral(LitFloat(f), _) => assert_eq(f, 1.5)
    _ => fail("expected LitFloat(1.5)")
  }
}

///|
test "string literal is parsed as LitString" {
  match parse_e("\"hello\"") {
    ELiteral(LitString("hello"), _) => ()
    _ => fail("expected LitString(\"hello\")")
  }
}

///|
test "None is parsed as an identifier" {
  match parse_e("None") {
    EIdent("None", _) => ()
    _ => fail("expected EIdent(\"None\")")
  }
}

///|
test "True is parsed as an identifier" {
  match parse_e("True") {
    EIdent("True", _) => ()
    _ => fail("expected EIdent(\"True\")")
  }
}

///|
test "False is parsed as an identifier" {
  match parse_e("False") {
    EIdent("False", _) => ()
    _ => fail("expected EIdent(\"False\")")
  }
}

///|
test "identifier is parsed as EIdent" {
  match parse_e("xyz") {
    EIdent("xyz", _) => ()
    _ => fail("expected EIdent(\"xyz\")")
  }
}

// --- Unary expressions ---

///|
test "unary minus on integer" {
  match parse_e("-1") {
    EUnary(OpMinus, ELiteral(LitInt(1N), _), _) => ()
    _ => fail("expected EUnary(OpMinus, LitInt(1))")
  }
}

///|
test "unary not on identifier" {
  match parse_e("not x") {
    EUnary(OpNot, EIdent("x", _), _) => ()
    _ => fail("expected EUnary(OpNot, EIdent(x))")
  }
}

///|
test "unary bitwise not" {
  match parse_e("~x") {
    EUnary(OpBitNot, EIdent("x", _), _) => ()
    _ => fail("expected EUnary(OpBitNot, EIdent(x))")
  }
}

// --- Binary expressions ---

///|
test "binary addition" {
  match parse_e("1 + 2") {
    EBinary(ELiteral(LitInt(1N), _), OpAdd, ELiteral(LitInt(2N), _), _) => ()
    _ => fail("expected 1 + 2")
  }
}

///|
test "multiplication has higher precedence than addition" {
  match parse_e("1 + 2 * 3") {
    EBinary(
      ELiteral(LitInt(1N), _),
      OpAdd,
      EBinary(ELiteral(LitInt(2N), _), OpMul, ELiteral(LitInt(3N), _), _),
      _
    ) => ()
    _ => fail("expected 1 + (2 * 3)")
  }
}

///|
test "floor division" {
  match parse_e("7 // 2") {
    EBinary(_, OpFloorDiv, _, _) => ()
    _ => fail("expected floor division")
  }
}

///|
test "power operator is not supported" {
  match @parser.parse_expr("test.star", "2 ** 10") {
    Err(_) => ()
    Ok(_) => fail("expected ** to be rejected as a binary operator")
  }
}

///|
test "equality comparison" {
  match parse_e("x == y") {
    EBinary(EIdent("x", _), OpEq, EIdent("y", _), _) => ()
    _ => fail("expected x == y")
  }
}

///|
test "in operator" {
  match parse_e("x in lst") {
    EBinary(EIdent("x", _), OpIn, EIdent("lst", _), _) => ()
    _ => fail("expected x in lst")
  }
}

///|
test "not in operator" {
  match parse_e("x not in lst") {
    EBinary(EIdent("x", _), OpNotIn, EIdent("lst", _), _) => ()
    _ => fail("expected x not in lst")
  }
}

///|
test "boolean and" {
  match parse_e("a and b") {
    EBinary(EIdent("a", _), OpAnd, EIdent("b", _), _) => ()
    _ => fail("expected a and b")
  }
}

///|
test "boolean or" {
  match parse_e("a or b") {
    EBinary(EIdent("a", _), OpOr, EIdent("b", _), _) => ()
    _ => fail("expected a or b")
  }
}

// --- Conditional expression ---

///|
test "conditional expression x if c else y" {
  match parse_e("1 if True else 0") {
    ECond(
      ELiteral(LitInt(1N), _),
      EIdent("True", _),
      ELiteral(LitInt(0N), _),
      _
    ) => ()
    _ => fail("expected conditional expression")
  }
}

// --- Collection literals ---

///|
test "empty list literal" {
  match parse_e("[]") {
    EList(items, _) => assert_eq(items.length(), 0)
    _ => fail("expected empty list")
  }
}

///|
test "list with elements" {
  match parse_e("[1, 2, 3]") {
    EList(items, _) => assert_eq(items.length(), 3)
    _ => fail("expected list with 3 elements")
  }
}

///|
test "empty tuple from parentheses" {
  match parse_e("()") {
    ETuple(items, _) => assert_eq(items.length(), 0)
    _ => fail("expected empty tuple")
  }
}

///|
test "single element tuple requires trailing comma" {
  match parse_e("(1,)") {
    ETuple(items, _) => assert_eq(items.length(), 1)
    _ => fail("expected singleton tuple")
  }
}

///|
test "multi-element tuple with parens" {
  match parse_e("(1, 2)") {
    ETuple(items, _) => assert_eq(items.length(), 2)
    _ => fail("expected 2-element tuple")
  }
}

///|
test "empty dict literal" {
  match parse_e("{}") {
    EDict(pairs, _) => assert_eq(pairs.length(), 0)
    _ => fail("expected empty dict")
  }
}

///|
test "dict with entries" {
  match parse_e("{\"a\": 1, \"b\": 2}") {
    EDict(pairs, _) => assert_eq(pairs.length(), 2)
    _ => fail("expected dict with 2 entries")
  }
}

///|
test "set literal" {
  match parse_e("{1, 2, 3}") {
    ESet(items, _) => assert_eq(items.length(), 3)
    _ => fail("expected set with 3 elements")
  }
}

// --- Call, dot, index, slice ---

///|
test "function call with no args" {
  match parse_e("f()") {
    ECall(EIdent("f", _), args, _) => assert_eq(args.length(), 0)
    _ => fail("expected f()")
  }
}

///|
test "function call with positional args" {
  match parse_e("f(1, 2)") {
    ECall(EIdent("f", _), args, _) => assert_eq(args.length(), 2)
    _ => fail("expected f(1, 2)")
  }
}

///|
test "function call with keyword arg" {
  match parse_e("f(x=1)") {
    ECall(EIdent("f", _), args, _) => {
      assert_eq(args.length(), 1)
      match args[0] {
        ArgKw("x", ELiteral(LitInt(1N), _), _) => ()
        _ => fail("expected keyword arg x=1")
      }
    }
    _ => fail("expected f(x=1)")
  }
}

///|
test "attribute access" {
  match parse_e("obj.attr") {
    EDot(EIdent("obj", _), "attr", _) => ()
    _ => fail("expected obj.attr")
  }
}

///|
test "index access" {
  match parse_e("lst[0]") {
    EIndex(EIdent("lst", _), ELiteral(LitInt(0N), _), _) => ()
    _ => fail("expected lst[0]")
  }
}

///|
test "slice with start and end" {
  match parse_e("lst[1:3]") {
    ESlice(
      EIdent("lst", _),
      Some(ELiteral(LitInt(1N), _)),
      Some(ELiteral(LitInt(3N), _)),
      None,
      _
    ) => ()
    _ => fail("expected lst[1:3]")
  }
}

///|
test "full slice with step" {
  match parse_e("lst[::2]") {
    ESlice(EIdent("lst", _), None, None, Some(ELiteral(LitInt(2N), _)), _) => ()
    _ => fail("expected lst[::2]")
  }
}

// --- Lambda ---

///|
test "lambda with no params" {
  match parse_e("lambda: 42") {
    ELambda(params, ELiteral(LitInt(42N), _), _) =>
      assert_eq(params.length(), 0)
    _ => fail("expected lambda: 42")
  }
}

///|
test "lambda with one param" {
  match parse_e("lambda x: x") {
    ELambda(params, EIdent("x", _), _) => {
      assert_eq(params.length(), 1)
      match params[0] {
        ParamIdent("x", _) => ()
        _ => fail("expected param x")
      }
    }
    _ => fail("expected lambda x: x")
  }
}

// --- List comprehension ---

///|
test "list comprehension" {
  match parse_e("[x for x in lst]") {
    EListComp(EIdent("x", _), clauses, _) => {
      assert_eq(clauses.length(), 1)
      match clauses[0] {
        ClauseFor(EIdent("x", _), EIdent("lst", _), _) => ()
        _ => fail("expected for x in lst clause")
      }
    }
    _ => fail("expected list comprehension")
  }
}

///|
test "list comprehension with if filter" {
  match parse_e("[x for x in lst if x > 0]") {
    EListComp(EIdent("x", _), clauses, _) => assert_eq(clauses.length(), 2)
    _ => fail("expected list comprehension with filter")
  }
}

// --- Simple statements ---

///|
test "empty file has no stmts" {
  let f = parse_f("")
  assert_eq(f.stmts().length(), 0)
}

///|
test "pass statement" {
  let f = parse_f("pass\n")
  assert_eq(f.stmts().length(), 1)
  match f.stmts()[0] {
    SPass(_) => ()
    _ => fail("expected SPass")
  }
}

///|
test "break statement" {
  let f = parse_f("break\n")
  match f.stmts()[0] {
    SBreak(_) => ()
    _ => fail("expected SBreak")
  }
}

///|
test "continue statement" {
  let f = parse_f("continue\n")
  match f.stmts()[0] {
    SContinue(_) => ()
    _ => fail("expected SContinue")
  }
}

///|
test "return with value" {
  let f = parse_f("return 42\n")
  match f.stmts()[0] {
    SReturn(Some(ELiteral(LitInt(42N), _)), _) => ()
    _ => fail("expected SReturn(42)")
  }
}

///|
test "return without value" {
  let f = parse_f("return\n")
  match f.stmts()[0] {
    SReturn(None, _) => ()
    _ => fail("expected SReturn(None)")
  }
}

///|
test "simple assignment" {
  let f = parse_f("x = 1\n")
  match f.stmts()[0] {
    SAssign(EIdent("x", _), ELiteral(LitInt(1N), _), _) => ()
    _ => fail("expected x = 1")
  }
}

///|
test "augmented assignment plus-equals" {
  let f = parse_f("x += 1\n")
  match f.stmts()[0] {
    SAugAssign(EIdent("x", _), AugAdd, ELiteral(LitInt(1N), _), _) => ()
    _ => fail("expected x += 1")
  }
}

///|
test "expression statement" {
  let f = parse_f("f()\n")
  match f.stmts()[0] {
    SExpr(ECall(EIdent("f", _), _, _)) => ()
    _ => fail("expected SExpr(f())")
  }
}

// --- Compound statements ---

///|
test "if statement with single-line body" {
  let f = parse_f("if x:\n  pass\n")
  match f.stmts()[0] {
    SIf(EIdent("x", _), body, else_body, _) => {
      assert_eq(body.length(), 1)
      assert_eq(else_body.length(), 0)
    }
    _ => fail("expected if statement")
  }
}

///|
test "if else statement" {
  let f = parse_f("if x:\n  pass\nelse:\n  pass\n")
  match f.stmts()[0] {
    SIf(_, true_body, false_body, _) => {
      assert_eq(true_body.length(), 1)
      assert_eq(false_body.length(), 1)
    }
    _ => fail("expected if-else")
  }
}

///|
test "for loop" {
  let f = parse_f("for x in lst:\n  pass\n")
  match f.stmts()[0] {
    SFor(EIdent("x", _), EIdent("lst", _), body, _) =>
      assert_eq(body.length(), 1)
    _ => fail("expected for loop")
  }
}

///|
test "while loop" {
  let f = parse_f("while True:\n  pass\n")
  match f.stmts()[0] {
    SWhile(EIdent("True", _), body, _) => assert_eq(body.length(), 1)
    _ => fail("expected while loop")
  }
}

///|
test "function definition with no params" {
  let f = parse_f("def f():\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, body, _) => {
      assert_eq(params.length(), 0)
      assert_eq(body.length(), 1)
    }
    _ => fail("expected def f()")
  }
}

///|
test "function definition with param and default" {
  let f = parse_f("def f(x, y=1):\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, _, _) => {
      assert_eq(params.length(), 2)
      match params[0] {
        ParamIdent("x", _) => ()
        _ => fail("expected param x")
      }
      match params[1] {
        ParamDefault("y", ELiteral(LitInt(1N), _), _) => ()
        _ => fail("expected param y=1")
      }
    }
    _ => fail("expected def with params")
  }
}

///|
test "function definition with star args" {
  let f = parse_f("def f(*args):\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, _, _) => {
      assert_eq(params.length(), 1)
      match params[0] {
        ParamStarIdent("args", _) => ()
        _ => fail("expected *args param")
      }
    }
    _ => fail("expected def f(*args)")
  }
}

///|
test "function definition with kwargs" {
  let f = parse_f("def f(**kwargs):\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, _, _) =>
      match params[0] {
        ParamKwIdent("kwargs", _) => ()
        _ => fail("expected **kwargs param")
      }
    _ => fail("expected def f(**kwargs)")
  }
}

///|
test "load statement with single binding" {
  let f = parse_f("load(\"mod.star\", \"sym\")\n")
  match f.stmts()[0] {
    SLoad("mod.star", bindings, _) => {
      assert_eq(bindings.length(), 1)
      let (bind_name, original, _pos) = bindings[0]
      assert_eq(bind_name, "sym")
      assert_eq(original, "sym")
    }
    _ => fail("expected load statement")
  }
}

///|
test "load statement with aliased binding" {
  let f = parse_f("load(\"mod.star\", alias=\"sym\")\n")
  match f.stmts()[0] {
    SLoad("mod.star", bindings, _) => {
      let (bind_name, original, _pos) = bindings[0]
      assert_eq(bind_name, "alias")
      assert_eq(original, "sym")
    }
    _ => fail("expected aliased load")
  }
}

// --- Position tracking ---

///|
test "integer literal has position line 1 col 1" {
  match parse_e("42") {
    ELiteral(_, pos) => {
      assert_eq(pos.line(), 1)
      assert_eq(pos.col(), 1)
    }
    _ => fail("expected literal")
  }
}

// --- Error cases: Python constructs not allowed in Starlark ---

///|
test "import statement is rejected" {
  match @parser.parse_file("test.star", "import os\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for import statement")
  }
}

///|
test "global statement is rejected" {
  match @parser.parse_file("test.star", "global x\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for global statement")
  }
}

///|
test "raise statement is rejected" {
  match @parser.parse_file("test.star", "raise Exception()\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for raise statement")
  }
}

///|
test "class definition is rejected" {
  match @parser.parse_file("test.star", "class Foo:\n  pass\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for class definition")
  }
}

///|
test "del statement is rejected" {
  match @parser.parse_file("test.star", "del x\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for del statement")
  }
}

///|
test "print-as-statement syntax is rejected" {
  match @parser.parse_file("test.star", "print \"hello\"\n") {
    Err(_) => ()
    Ok(_) => fail("expected syntax error for print-as-statement")
  }
}

///|
test "adjacent string literals are not concatenated" {
  match @parser.parse_expr("test.star", "\"a\" \"b\"") {
    Err(_) => ()
    Ok(_) => fail("expected syntax error for adjacent string literals")
  }
  match @parser.parse_file("test.star", "x = \"a\" \"b\"\n") {
    Err(_) => ()
    Ok(_) => fail("expected syntax error for adjacent string literals in stmt")
  }
}

///|
test "malformed keyword argument is rejected" {
  let msg = parse_e_err("f(a.b=1)")
  if !msg.contains("keyword argument must have form name=expr") {
    fail("expected malformed-kwarg error, got: \{msg}")
  }
}

// --- Non-associative comparison operators ---

///|
fn parse_e_err(src : String) -> String {
  match @parser.parse_expr("test.star", src) {
    Err(e) => e.msg()
    Ok(_) => ""
  }
}

///|
test "chained == == is rejected as non-associative" {
  let msg = parse_e_err("0 == 1 == 2")
  if !msg.contains("== does not associate with ==") {
    fail("expected non-associative error, got: \{msg}")
  }
}

///|
test "chained comparison error reports the position past the operator" {
  // starlark-go reports at the scanner position one past the second operator.
  // For "0 <= i < n" the second operator "<" ends at col 9.
  match @parser.parse_expr("test.star", "0 <= i < n") {
    Err(e) => assert_eq(e.pos().col(), 9)
    Ok(_) => fail("expected non-associative error")
  }
}

///|
test "chained <= < is rejected as non-associative" {
  let msg = parse_e_err("0 <= i < n")
  if !msg.contains("<= does not associate with <") {
    fail("expected non-associative error, got: \{msg}")
  }
}

///|
test "chained in not-in is rejected as non-associative" {
  let msg = parse_e_err("a in b not in c")
  if !msg.contains("in does not associate with not in") {
    fail("expected non-associative error, got: \{msg}")
  }
}

///|
test "parenthesized comparisons are allowed" {
  match @parser.parse_expr("test.star", "(0 == 1) == 2") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
  match @parser.parse_expr("test.star", "0 == (1 == 2)") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
fn parse_f_err(src : String) -> String {
  match @parser.parse_file("test.star", src) {
    Err(e) => e.msg()
    Ok(_) => ""
  }
}

// --- Python constructs not supported in Starlark ---

///|
test "is operator is rejected" {
  let msg = parse_e_err("x is y")
  if !msg.contains("'is' operator is not allowed") {
    fail("expected 'is' rejection, got: \{msg}")
  }
}

///|
test "is not operator is rejected" {
  let msg = parse_e_err("x is not y")
  if !msg.contains("'is' operator is not allowed") {
    fail("expected 'is not' rejection, got: \{msg}")
  }
}

///|
test "type annotation in function parameter is rejected" {
  let msg = parse_f_err("def f(x: int): pass\n")
  if !msg.contains("type annotations are not allowed") {
    fail("expected annotation rejection, got: \{msg}")
  }
}

///|
test "annotated assignment is rejected" {
  let msg = parse_f_err("x: int = 1\n")
  if !msg.contains("type annotations are not allowed") {
    fail("expected annotation rejection, got: \{msg}")
  }
}

///|
test "starred target in tuple unpacking LHS is rejected" {
  let msg = parse_f_err("a, *b = [1, 2]\n")
  if !msg.contains("got '*', want primary expression") {
    fail("expected starred target rejection, got: \{msg}")
  }
}

///|
test "star in expression position reports want primary expression" {
  let msg = parse_e_err("[*x]")
  if !msg.contains("got '*', want primary expression") {
    fail("expected primary-expression error, got: \{msg}")
  }
}

///|
test "double-star in expression position reports want primary expression" {
  let msg = parse_e_err("[**x]")
  if !msg.contains("got '**', want primary expression") {
    fail("expected primary-expression error, got: \{msg}")
  }
}

///|
test "walrus operator := is rejected" {
  let msg = parse_f_err("x := 5\n")
  if !msg.contains("walrus operator") && !msg.contains(":=") {
    fail("expected walrus rejection, got: \{msg}")
  }
}

// --- AST walker ---

///|
test "walk: visits all idents in assignment" {
  let file = parse_f("x = 1\n")
  let idents : Array[String] = []
  @syntax.walk_file(file, fn(node) {
    match node {
      Some(@syntax.Node::NExpr(@syntax.Expr::EIdent(name, _))) =>
        idents.push(name)
      _ => ()
    }
    true
  })
  if !idents.contains("x") {
    fail("expected ident 'x', got: [\{idents.join(", ")}]")
  }
}

///|
test "walk: visitor returning false skips children" {
  let file = parse_f("def f(x):\n  y = x + 1\n")
  let visited : Array[String] = []
  @syntax.walk_file(file, fn(node) {
    match node {
      Some(@syntax.Node::NStmt(@syntax.Stmt::SDef(name, _, _, _))) => {
        visited.push("def:\{name}")
        false
      }
      Some(@syntax.Node::NExpr(@syntax.Expr::EIdent(name, _))) => {
        visited.push("ident:\{name}")
        true
      }
      _ => true
    }
  })
  if visited.contains("ident:x") || visited.contains("ident:y") {
    fail("expected no traversal inside def body, got: [\{visited.join(", ")}]")
  }
}

///|
test "walk: visits all clauses in comprehension" {
  let expr = parse_e("[x for x in xs if x > 0]")
  let kinds : Array[String] = []
  @syntax.walk_expr(expr, fn(node) {
    match node {
      Some(@syntax.Node::NCompClause(@syntax.CompClause::ClauseFor(_, _, _))) =>
        kinds.push("for")
      Some(@syntax.Node::NCompClause(@syntax.CompClause::ClauseIf(_, _))) =>
        kinds.push("if")
      _ => ()
    }
    true
  })
  assert_eq(kinds.join(","), "for,if")
}

// --- None, True, False are pre-declared identifiers (spec §Identifiers) ---

///|
test "parser: None is accepted as a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(None): pass\n")
  assert_true(result is Ok(_))
}

///|
test "parser: True is accepted as a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(True): pass\n")
  assert_true(result is Ok(_))
}

///|
test "parser: False is accepted as a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(False): pass\n")
  assert_true(result is Ok(_))
}

///|
test "parser: None with default is accepted as a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(None=0): pass\n")
  assert_true(result is Ok(_))
}

///|
test "parser: None True False parse as identifier expressions" {
  match parse_e("None") {
    EIdent("None", _) => ()
    _ => fail("expected EIdent(\"None\")")
  }
  match parse_e("True") {
    EIdent("True", _) => ()
    _ => fail("expected EIdent(\"True\")")
  }
  match parse_e("False") {
    EIdent("False", _) => ()
    _ => fail("expected EIdent(\"False\")")
  }
}

///|
test "load with zero imported symbols is rejected" {
  match @parser.parse_file("test.star", "load(\"m\")\n") {
    Err(e) => assert_true(e.msg().contains("must import at least 1 symbol"))
    Ok(_) => fail("expected error for load with no symbols")
  }
}

///|
test "load with at least one symbol parses" {
  match @parser.parse_file("test.star", "load(\"m\", \"a\")\n") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.to_string()}")
  }
}

///|
test "unparenthesized tuple with trailing comma is rejected" {
  match @parser.parse_file("test.star", "x, = 1,\n") {
    Err(e) =>
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
    Ok(_) => fail("expected error for trailing comma")
  }
}

///|
test "parenthesized singleton tuple with trailing comma is allowed" {
  match @parser.parse_file("test.star", "x = (1,)\n") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.to_string()}")
  }
}

///|
test "for-loop target with binary operator is rejected" {
  match @parser.parse_file("test.star", "for a + b in xs:\n  pass\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for non-primary for-target")
  }
}

///|
test "comprehension target with binary operator is rejected" {
  match @parser.parse_expr("test.star", "[x for a + b in xs]") {
    Err(_) => ()
    Ok(_) => fail("expected error for non-primary comprehension target")
  }
}

///|
test "for-loop with index/attribute targets parses" {
  match @parser.parse_file("test.star", "for a[0], b.c in xs:\n  pass\n") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.to_string()}")
  }
}

// --- Parser error message parity ---

///|
test "conditional expression without else clause produces correct message" {
  match @parser.parse_expr("test.star", "x if y") {
    Err(e) =>
      assert_true(
        e.msg().contains("conditional expression without else clause"),
      )
    Ok(_) => fail("expected error for conditional without else")
  }
}

///|
test "load unquoted original name produces correct message" {
  match @parser.parse_file("test.star", "load(\"m\", x=originalname)\n") {
    Err(e) =>
      assert_true(
        e.msg().contains("original name of loaded symbol must be quoted"),
      )
    Ok(_) => fail("expected error for unquoted original name")
  }
}

///|
test "parser: expect uses single-quoted punctuation in error message" {
  // def f : pass → got ':', want '('
  match @parser.parse_file("test.star", "def f : pass\n") {
    Err(e) => assert_true(e.msg().contains("got ':', want '('"))
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: expect uses single-quoted ] in error message" {
  // x = [1, 2 → got end of file, want ']'
  match @parser.parse_file("test.star", "x = [1, 2\n") {
    Err(e) => assert_true(e.msg().contains("want ']'"))
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: compound opener at EOF is classified UnexpectedEof" {
  for src in ["def f():", "if True:", "for x in y:"] {
    match @parser.parse_file("<repl>", src) {
      Err(e) => assert_true(e.kind() is UnexpectedEof)
      Ok(_) => fail("expected error for \{src}")
    }
  }
}

///|
test "parser: unclosed bracket at EOF is classified UnexpectedEof" {
  for src in ["(1 +", "[1,"] {
    match @parser.parse_file("<repl>", src) {
      Err(e) => assert_true(e.kind() is UnexpectedEof)
      Ok(_) => fail("expected error for \{src}")
    }
  }
}

///|
test "parser: unterminated string is classified UnterminatedString" {
  match @parser.parse_file("<repl>", "'''abc") {
    Err(e) => assert_true(e.kind() is UnterminatedString)
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: a genuine non-EOF syntax error is classified Other" {
  // got '*', want primary expression — the offending token is not EOF.
  match @parser.parse_file("<repl>", "1 + * 2") {
    Err(e) => assert_true(e.kind() is Other)
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: newline expectation uses got-want order" {
  // print 1 2 → got int literal, want newline
  match @parser.parse_file("test.star", "print 1 2\n") {
    Err(e) =>
      assert_true(
        e.msg().contains("got int literal") && e.msg().contains("want newline"),
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: newline expectation quotes punctuation" {
  // a = b = 5 → got '=', want newline
  match @parser.parse_file("test.star", "a = b = 5\n") {
    Err(e) =>
      assert_true(
        e.msg().contains("got '='") && e.msg().contains("want newline"),
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: def with keyword name reports 'not an identifier'" {
  match @parser.parse_file("test.star", "def pass(): pass\n") {
    Err(e) => assert_true(e.msg().contains("not an identifier"))
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: def with keyword param reports 'not an identifier'" {
  match @parser.parse_file("test.star", "def f(load): pass\n") {
    Err(e) => assert_true(e.msg().contains("not an identifier"))
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: comprehension clause error includes alternatives" {
  // _ = [x for x in a if b else c] → should say want ']', for, or if
  match @parser.parse_file("test.star", "_ = [x for x in a if b else c]\n") {
    Err(e) => assert_true(e.msg().contains("for, or if"))
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: 'not' not followed by 'in' uses got/want format" {
  // _ = a + b not c → Go: got identifier, want in
  match @parser.parse_file("test.star", "_ = a + b not c\n") {
    Err(e) =>
      assert_true(
        e.msg().contains("got identifier") && e.msg().contains("want in"),
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "scanner: invalid int literal reported at start position" {
  // 012834 → error at 1:1, not 1:7
  match @parser.parse_file("foo.star", "012834\n") {
    Err(e) => assert_eq(e.pos().to_string(), "foo.star:1:1")
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: load non-string operand reports correct message" {
  // load("", 1) → load operand must be "name" or localname="name" (got int literal)
  match @parser.parse_file("test.star", "load(\"\", 1)\n") {
    Err(e) =>
      assert_true(
        e.msg().contains("load operand must be") &&
        e.msg().contains("got int literal"),
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: load ident without = reports correct message" {
  // load("a", x) → load operand must be "x" or x="originalname"
  match @parser.parse_file("test.star", "load(\"a\", x)\n") {
    Err(e) => assert_true(e.msg().contains("load operand must be"))
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: load non-string first arg reports correct message" {
  // load(1, 2) → first operand of load statement must be a string literal
  match @parser.parse_file("test.star", "load(1, 2)\n") {
    Err(e) =>
      assert_true(
        e
        .msg()
        .contains("first operand of load statement must be a string literal"),
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: bare * followed by non-comma token reports 'want ,'" {
  // def f(a, *-b, c): pass -> ":1:11: got '-', want ','"
  match @parser.parse_file("test.star", "def f(a, *-b, c): pass\n") {
    Err(e) => {
      assert_true(e.msg().contains("want ','"))
      assert_true(!e.msg().contains("want ')'"))
    }
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: missing separator between def params reports want ',' not want ')'" {
  match @parser.parse_file("test.star", "def f(a b): pass\n") {
    Err(e) => {
      assert_true(e.msg().contains("got identifier, want ','"))
      assert_true(!e.msg().contains("want ')'"))
    }
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: missing separator between non-first def params reports got X want ','" {
  match @parser.parse_file("test.star", "def f(a, b c): pass\n") {
    Err(e) => assert_true(e.msg().contains("got identifier, want ','"))
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: missing separator between call args reports want ',' not want ')'" {
  match @parser.parse_file("test.star", "f(1 2)\n") {
    Err(e) => {
      assert_true(e.msg().contains("want ','"))
      assert_true(!e.msg().contains("want ')'"))
    }
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: missing colon in dict literal reports want ':' not want '}'" {
  match @parser.parse_file("test.star", "x = {1 2}\n") {
    Err(e) => {
      assert_true(e.msg().contains("want ':'"))
      assert_true(!e.msg().contains("want '}'"))
    }
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: missing separator between lambda params reports want ',' not want ':'" {
  match @parser.parse_file("test.star", "f = lambda a b: a\n") {
    Err(e) => {
      assert_true(e.msg().contains("got identifier, want ','"))
      assert_true(!e.msg().contains("want ':'"))
    }
    Ok(_) => fail("expected error")
  }
}

///|
test "if statement with multiple elif branches is parsed as a single top-level SIf node" {
  // Exercises the recursive elif-branch parse path in the parser.
  let f = parse_f(
    "if False:\n  r = 1\nelif False:\n  r = 2\nelif True:\n  r = 3\nelse:\n  r = 4\n",
  )
  assert_eq(f.stmts().length(), 1)
  match f.stmts()[0] {
    @syntax.Stmt::SIf(_, _, _, _) => ()
    _ => fail("expected SIf")
  }
}

///|
test "Python keywords not allowed in Starlark are each rejected" {
  let cases = [
    ("nonlocal x\n", "nonlocal"),
    ("try:\n  pass\n", "try"),
    ("with x:\n  pass\n", "with"),
    ("async def f(): pass\n", "async"),
    ("yield 1\n", "yield"),
  ]
  for pair in cases {
    let (src, kw) = pair
    match @parser.parse_file("test.star", src) {
      Err(_) => ()
      Ok(_) => fail("expected parse error for keyword: \{kw}")
    }
  }
}

///|
test "semicolon separates two small statements on one line" {
  let f = parse_f("a = 1; b = 2\n")
  assert_eq(f.stmts().length(), 2)
}

///|
test "trailing semicolon before end of line is accepted and does not add a statement" {
  let f = parse_f("a = 1; b = 2;\n")
  assert_eq(f.stmts().length(), 2)
}

///|
test "load statement accepts trailing comma before closing paren" {
  match @parser.parse_file("test.star", "load(\"m.star\", \"x\",)\n") {
    Ok(f) =>
      match f.stmts()[0] {
        @syntax.Stmt::SLoad(_, bindings, _) => assert_eq(bindings.length(), 1)
        _ => fail("expected SLoad")
      }
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

// --- Ternary expression as call argument ---

///|
test "ternary arg starting with ident parses as ECond" {
  match parse_e("f(x if True else 0)") {
    ECall(_, args, _) => {
      assert_eq(args.length(), 1)
      match args[0] {
        ArgPos(
          ECond(EIdent("x", _), EIdent("True", _), ELiteral(LitInt(0N), _), _)
        ) => ()
        _ => fail("expected ArgPos(ECond(x, True, 0))")
      }
    }
    _ => fail("expected ECall")
  }
}

///|
test "ternary arg starting with ident followed by binary expr parses as ECond" {
  match parse_e("f(a if a < b else b)") {
    ECall(_, args, _) => {
      assert_eq(args.length(), 1)
      match args[0] {
        ArgPos(ECond(EIdent("a", _), _, EIdent("b", _), _)) => ()
        _ => fail("expected ArgPos(ECond(a, a < b, b))")
      }
    }
    _ => fail("expected ECall")
  }
}

///|
test "ternary arg as first of multiple args parses correctly" {
  match parse_e("f(x if c else y, 5)") {
    ECall(_, args, _) => {
      assert_eq(args.length(), 2)
      match args[0] {
        ArgPos(ECond(EIdent("x", _), _, EIdent("y", _), _)) => ()
        _ => fail("expected first arg to be ECond")
      }
      match args[1] {
        ArgPos(ELiteral(LitInt(5N), _)) => ()
        _ => fail("expected second arg to be 5")
      }
    }
    _ => fail("expected ECall")
  }
}

// --- Trailing comma rejection ---

///|
test "subscript trailing comma is rejected" {
  match @parser.parse_expr("test.star", "a[1,]") {
    Err(e) =>
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
    Ok(_) => fail("expected error for trailing comma in subscript")
  }
}

///|
test "subscript multi-index tuple key is accepted" {
  match @parser.parse_expr("test.star", "a[1, 2]") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "subscript multi-index with trailing comma is rejected" {
  match @parser.parse_expr("test.star", "a[1, 2,]") {
    Err(e) =>
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
    Ok(_) => fail("expected error for trailing comma in subscript")
  }
}

///|
test "subscript single index is accepted" {
  match @parser.parse_expr("test.star", "a[1]") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "subscript slice is accepted" {
  match @parser.parse_expr("test.star", "a[1:2]") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "subscript tuple lower-bound slice is accepted" {
  match @parser.parse_expr("test.star", "a[1, 2:]") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "subscript tuple lower-bound slice with end is accepted" {
  match @parser.parse_expr("test.star", "a[1, 2:3]") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "subscript tuple lower-bound slice with step is accepted" {
  match @parser.parse_expr("test.star", "a[1, 2:3:4]") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "lambda trailing comma before colon is rejected" {
  match @parser.parse_expr("test.star", "lambda x,: x") {
    Err(_) => ()
    Ok(_) => fail("expected error for trailing comma in lambda params")
  }
}

///|
test "lambda multi-param trailing comma before colon is rejected" {
  match @parser.parse_expr("test.star", "lambda x, y,: x") {
    Err(_) => ()
    Ok(_) => fail("expected error for trailing comma in lambda params")
  }
}

///|
test "lambda without trailing comma is accepted" {
  match @parser.parse_expr("test.star", "lambda x, y: x") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "for-loop target with trailing comma is rejected" {
  match @parser.parse_file("test.star", "for x, in xs:\n  pass\n") {
    Err(e) =>
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
    Ok(_) => fail("expected error for trailing comma in for-target")
  }
}

///|
test "for-loop multi-target with trailing comma is rejected" {
  match @parser.parse_file("test.star", "for x, y, in xs:\n  pass\n") {
    Err(e) =>
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
    Ok(_) => fail("expected error for trailing comma in for-target")
  }
}

///|
test "for-loop multi-target without trailing comma is accepted" {
  match @parser.parse_file("test.star", "for x, y in xs:\n  pass\n") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "comprehension target with trailing comma is rejected" {
  match @parser.parse_expr("test.star", "[x for y, in xs]") {
    Err(e) =>
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
    Ok(_) => fail("expected error for trailing comma in comprehension target")
  }
}

///|
test "for-loop bare-tuple iterable parses correctly" {
  match @parser.parse_file("test.star", "for x in 1, 2, 3:\n  pass\n") {
    Ok(f) =>
      match f.stmts()[0] {
        @syntax.Stmt::SFor(_, @syntax.Expr::ETuple(items, _), _, _) =>
          assert_eq(items.length(), 3)
        _ => fail("expected SFor with ETuple iterable")
      }
    Err(e) => fail("unexpected parse error: \{e.msg()}")
  }
}

///|
test "for-loop tuple-unpacking over bare-tuple iterable parses correctly" {
  match
    @parser.parse_file("test.star", "for x, y in (1, 2), (3, 4):\n  pass\n") {
    Ok(f) =>
      match f.stmts()[0] {
        @syntax.Stmt::SFor(_, @syntax.Expr::ETuple(items, _), _, _) =>
          assert_eq(items.length(), 2)
        _ => fail("expected SFor with ETuple iterable")
      }
    Err(e) => fail("unexpected parse error: \{e.msg()}")
  }
}

///|
test "for-loop bare-tuple iterable with trailing comma is rejected" {
  match @parser.parse_file("test.star", "for x in 1, 2,:\n  pass\n") {
    Err(_) => ()
    Ok(_) => fail("expected parse error for trailing comma in for-iterable")
  }
}

///|
test "comprehension bare-tuple iterable is still rejected" {
  match @parser.parse_expr("test.star", "[x for x in 1, 2, 3]") {
    Err(_) => ()
    Ok(_) =>
      fail("expected parse error for bare tuple in comprehension iterable")
  }
}

///|
test "comprehension if-clause lambda body conditional is rejected" {
  match
    @parser.parse_expr("test.star", "[a for b in c if lambda: d if e else f]") {
    Err(_) => ()
    Ok(_) =>
      fail(
        "expected syntax error for conditional in lambda body inside if-clause",
      )
  }
}

///|
test "comprehension if-clause lambda body without conditional is accepted" {
  match @parser.parse_expr("test.star", "[a for b in c if lambda: d]") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "comprehension if-clause nested lambda body conditional is rejected" {
  match
    @parser.parse_expr(
      "test.star", "[a for b in c if lambda: lambda: d if e else f]",
    ) {
    Err(_) => ()
    Ok(_) =>
      fail(
        "expected syntax error for conditional in nested lambda body inside if-clause",
      )
  }
}

///|
test "lambda body conditional outside comprehension is accepted" {
  match @parser.parse_expr("test.star", "lambda: d if e else f") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "ternary arg with method call on ident parses as ECond" {
  match parse_e("f(s.upper() if flag else s)") {
    ECall(_, args, _) => {
      assert_eq(args.length(), 1)
      match args[0] {
        ArgPos(
          ECond(
            ECall(EDot(EIdent("s", _), "upper", _), upper_args, _),
            EIdent("flag", _),
            EIdent("s", _),
            _
          )
        ) => assert_eq(upper_args.length(), 0)
        _ => fail("expected ArgPos(ECond(s.upper(), flag, s))")
      }
    }
    _ => fail("expected ECall")
  }
}

// --- Depth guard ---

///|
test "deeply nested list exceeding depth limit returns a parse error" {
  let n = 210
  let src = "[".repeat(n) + "1" + "]".repeat(n)
  match @parser.parse_expr("test.star", src) {
    Err(e) => assert_true(e.msg().contains("expression nesting too deep"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep list nesting")
  }
}

///|
test "deeply nested parens exceeding depth limit returns a parse error" {
  let n = 210
  let src = "(".repeat(n) + "1" + ")".repeat(n)
  match @parser.parse_expr("test.star", src) {
    Err(e) => assert_true(e.msg().contains("expression nesting too deep"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep paren nesting")
  }
}

///|
test "long not-chain exceeding depth limit returns a parse error" {
  let n = 210
  let src = "not ".repeat(n) + "True"
  match @parser.parse_expr("test.star", src) {
    Err(e) => assert_true(e.msg().contains("expression nesting too deep"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep not chain")
  }
}

///|
test "long unary-minus chain exceeding depth limit returns a parse error" {
  let n = 210
  let src = "-".repeat(n) + "1"
  match @parser.parse_expr("test.star", src) {
    Err(e) => assert_true(e.msg().contains("expression nesting too deep"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep unary minus chain")
  }
}

///|
test "normal nesting well within depth limit parses successfully" {
  let n = 50
  let src = "[".repeat(n) + "1" + "]".repeat(n)
  match @parser.parse_expr("test.star", src) {
    Ok(_) => ()
    Err(e) => fail("unexpected error for shallow nesting: \{e.msg()}")
  }
}

///|
test "nested lambdas in comprehension if-clause exceeding depth limit returns a parse error" {
  let n = 210
  let lambdas = "lambda: ".repeat(n) + "1"
  let src = "[x for x in [1] if \{lambdas}]"
  match @parser.parse_file("test.star", src) {
    Err(e) => assert_true(e.msg().contains("expression nesting too deep"))
    Ok(_) =>
      fail(
        "expected depth-limit error for \{n}-deep lambda chain in comprehension if-clause",
      )
  }
}

///|
test "deeply nested dict literals exceeding depth limit returns a parse error" {
  let n = 210
  let src = "{0: ".repeat(n) + "0" + "}".repeat(n)
  match @parser.parse_expr("test.star", src) {
    Err(e) => assert_true(e.msg().contains("expression nesting too deep"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep dict nesting")
  }
}

///|
test "deeply nested call chains exceeding depth limit returns a parse error" {
  let n = 210
  let src = "f(".repeat(n) + "0" + ")".repeat(n)
  match @parser.parse_expr("test.star", src) {
    Err(e) => assert_true(e.msg().contains("expression nesting too deep"))
    Ok(_) => fail("expected depth-limit error for \{n}-deep call chain")
  }
}

///|
test "parser: got-want error anchors after the unexpected token" {
  // go: `foo bar` at 1:8 (one past end of 'bar'), not 1:5 (start of 'bar')
  match @parser.parse_file("test.star", "foo bar\n") {
    Err(e) => {
      assert_true(e.msg().contains("got identifier"))
      assert_eq(e.pos().to_string(), "test.star:1:8")
    }
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: conditional without else anchors at the if token" {
  // go: `x = 1 if 2` at 1:7 (start of 'if'), not 1:11 (after condition)
  match @parser.parse_file("test.star", "x = 1 if 2\n") {
    Err(e) => {
      assert_true(
        e.msg().contains("conditional expression without else clause"),
      )
      assert_eq(e.pos().to_string(), "test.star:1:7")
    }
    Ok(_) => fail("expected error")
  }
}

///|
test "parser: unparenthesized trailing comma anchors at the comma" {
  // go: `a, = 1,` at 1:2 (the trailing comma), not 1:4 (token after comma)
  match @parser.parse_file("test.star", "a, = 1,\n") {
    Err(e) => {
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
      assert_eq(e.pos().to_string(), "test.star:1:2")
    }
    Ok(_) => fail("expected error")
  }
}
