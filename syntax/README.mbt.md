# `syntax` package

AST node types for the Starlark language. Import `connect0459/starlark/syntax` to work
with parsed source trees: inspect nodes, walk the tree, or build ASTs for testing.

Obtain a `File` by calling `@eval.parse_file`; use the node types and walker functions
to analyse or transform it.

## Key types and functions

| Symbol | Description |
| :--- | :--- |
| `File` | Top-level parsed file (path + statement list) |
| `Expr` | Expression node (24 variants) |
| `Stmt` | Statement node (12 variants) |
| `Param` / `Arg` / `CompClause` | Parameter, call argument, comprehension clause |
| `LiteralVal` / `BinaryOp` / `UnaryOp` / `AugOp` | Leaf enums |
| `Node` | Visitor wrapper covering all node kinds |
| `walk_file` / `walk_stmt` / `walk_expr` | Depth-first tree traversal |
| `stmt_pos` / `expr_pos` | Source position of any node |

## Quick start

Building a `File` directly for tests (bypassing the parser):

```mbt check
///|
test {
  let pos = @errors.Position::new("<test>", 1, 1)
  let stmt = @syntax.Stmt::SPass(pos)
  let file = @syntax.File::new("<test>", [stmt])
  assert_eq(file.path(), "<test>")
  assert_eq(file.stmts().length(), 1)
}
```

Collecting identifiers from an expression node:

```mbt check
///|
test {
  let pos = @errors.Position::new("<e>", 1, 1)
  let lhs = @syntax.Expr::EIdent("x", pos)
  let rhs = @syntax.Expr::EIdent("y", pos)
  let expr = @syntax.Expr::EBinary(lhs, @syntax.BinaryOp::OpAdd, rhs, pos)
  let names : Array[String] = []
  @syntax.walk_expr(expr, fn(node) {
    match node {
      Some(@syntax.Node::NExpr(@syntax.Expr::EIdent(name, _))) =>
        names.push(name)
      _ => ()
    }
    true
  })
  assert_true(names == ["x", "y"])
}
```

Parsing from source requires `@eval.parse_file` / `@eval.parse_expr`.
