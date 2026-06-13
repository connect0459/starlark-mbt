// Starlark recursive-descent parser.
// Converts a token stream (via Scanner) into a syntax.File AST.

///|
suberror ParseErr {
  ParseErr(@errors.SyntaxError)
}

///|
// Wasm/JS target (macOS arm64, V8) overflows the call stack at ~176 levels of
// bracket nesting (each level adds ~15 wasm frames; ~1 MB wasm stack). 80 gives
// a comfortable margin for all four backends while still allowing any
// realistically nested Starlark program.
// ref: <https://github.com/connect0459/starlark-mbt/issues/174>.
let max_expr_depth : Int = 80

///|
struct Parser {
  scanner : @lexer.Scanner
  mut tok : @lexer.Token
  mut pos : @errors.Position
  // Set while parsing a for/comprehension loop-variable list so the `in`
  // keyword that terminates the target is not consumed as an `in` comparison
  // operator inside the target expression.
  mut no_in : Bool
  mut expr_depth : Int
}

///|
fn Parser::new(filename : String, source : String) -> Parser raise ParseErr {
  let scanner = @lexer.Scanner::new(filename, source)
  let p : Parser = {
    scanner,
    tok: @lexer.Token::EOF,
    pos: @errors.Position::new(filename, 0, 0),
    no_in: false,
    expr_depth: 0,
  }
  p.advance()
  p
}

///|
fn Parser::advance(self : Parser) -> Unit raise ParseErr {
  match self.scanner.next_token() {
    Err(e) => raise ParseErr(e)
    Ok(st) => {
      self.tok = st.token()
      self.pos = st.pos()
    }
  }
}

///|
fn Parser::syntax_error(self : Parser, msg : String) -> @errors.SyntaxError {
  @errors.SyntaxError::with_kind(self.pos, msg, self.eof_kind())
}

///|
/// Builds a syntax error at the scanner's current read position (one past the
/// current token), matching starlark-go errors that use `scanner.pos`.
fn Parser::scanner_error(self : Parser, msg : String) -> @errors.SyntaxError {
  @errors.SyntaxError::with_kind(self.scanner.position(), msg, self.eof_kind())
}

///|
/// Builds a syntax error at a caller-supplied position.
fn Parser::syntax_error_at(
  self : Parser,
  pos : @errors.Position,
  msg : String,
) -> @errors.SyntaxError {
  @errors.SyntaxError::with_kind(pos, msg, self.eof_kind())
}

///|
/// Classifies an error raised at the current token: `UnexpectedEof` when the
/// parser has reached the end of input (the input may complete with more
/// lines), otherwise `Other`.
fn Parser::eof_kind(self : Parser) -> @errors.SyntaxErrorKind {
  if self.tok == @lexer.Token::EOF {
    @errors.SyntaxErrorKind::UnexpectedEof
  } else {
    @errors.SyntaxErrorKind::Other
  }
}

///|
fn Parser::bump_depth(self : Parser) -> Unit raise ParseErr {
  self.expr_depth += 1
  if self.expr_depth > max_expr_depth {
    raise ParseErr(self.syntax_error("expression nesting too deep"))
  }
}

///|
fn Parser::pop_depth(self : Parser) -> Unit {
  self.expr_depth -= 1
}

///|
fn Parser::expect(
  self : Parser,
  expected : @lexer.Token,
) -> Unit raise ParseErr {
  if self.tok != expected {
    raise ParseErr(
      self.scanner_error(
        "got \{self.tok.go_string()}, want \{expected.go_string()}",
      ),
    )
  }
  self.advance()
}

///|
fn Parser::expect_ident(
  self : Parser,
) -> (String, @errors.Position) raise ParseErr {
  match self.tok {
    @lexer.Token::Ident(name) => {
      let p = self.pos
      self.advance()
      (name, p)
    }
    _ => raise ParseErr(self.syntax_error("not an identifier"))
  }
}

///|
fn Parser::consume_newlines(self : Parser) -> Unit raise ParseErr {
  while self.tok == @lexer.Token::Newline {
    self.advance()
  }
}

// ---- Public API ----

///|
/// Parses a complete Starlark source file and returns its AST,
/// or a `SyntaxError` if the source is ill-formed.
///
/// Parameters:
///
/// - `filename` : The source file name, recorded in all position values.
/// - `source` : The UTF-8 source text to parse.
///
/// Returns `Ok(File)` with the parsed AST, or `Err(SyntaxError)` if parsing fails.
pub fn parse_file(
  filename : String,
  source : String,
) -> Result[@syntax.File, @errors.SyntaxError] {
  try {
    let p = Parser::new(filename, source)
    Ok(p.parse_file_inner(filename))
  } catch {
    ParseErr(e) => Err(e)
  }
}

///|
/// Parses a single Starlark expression and returns it, or a `SyntaxError`
/// if the source is ill-formed or contains more than one expression.
///
/// Parameters:
///
/// - `filename` : The source file name, recorded in all position values.
/// - `source` : The UTF-8 source text containing exactly one expression.
///
/// Returns `Ok(Expr)` with the parsed expression, or `Err(SyntaxError)` if
/// parsing fails or trailing tokens remain after the expression.
pub fn parse_expr(
  filename : String,
  source : String,
) -> Result[@syntax.Expr, @errors.SyntaxError] {
  try {
    let p = Parser::new(filename, source)
    let e = p.parse_test()
    p.consume_newlines()
    if p.tok != @lexer.Token::EOF {
      raise ParseErr(
        p.syntax_error("got \{p.tok.to_string()}, want end of expression"),
      )
    }
    Ok(e)
  } catch {
    ParseErr(e) => Err(e)
  }
}

// ---- File ----

///|
fn Parser::parse_file_inner(
  self : Parser,
  path : String,
) -> @syntax.File raise ParseErr {
  let stmts : Array[@syntax.Stmt] = []
  self.consume_newlines()
  while self.tok != @lexer.Token::EOF {
    let ss = self.parse_stmt()
    for s in ss {
      stmts.push(s)
    }
    self.consume_newlines()
  }
  @syntax.File::new(path, stmts)
}

// ---- Statements ----

///|
fn Parser::parse_stmt(self : Parser) -> Array[@syntax.Stmt] raise ParseErr {
  match self.tok {
    @lexer.Token::Def => [self.parse_def_stmt()]
    @lexer.Token::If => [self.parse_if_stmt()]
    @lexer.Token::For => [self.parse_for_stmt()]
    @lexer.Token::While => [self.parse_while_stmt()]
    _ => self.parse_simple_stmt()
  }
}

///|
fn Parser::parse_simple_stmt(
  self : Parser,
) -> Array[@syntax.Stmt] raise ParseErr {
  let stmts : Array[@syntax.Stmt] = []
  stmts.push(self.parse_small_stmt())
  while self.tok == @lexer.Token::Semi {
    self.advance()
    if self.tok == @lexer.Token::Newline || self.tok == @lexer.Token::EOF {
      break
    }
    stmts.push(self.parse_small_stmt())
  }
  if self.tok == @lexer.Token::Newline {
    self.advance()
  } else if self.tok != @lexer.Token::EOF && self.tok != @lexer.Token::Outdent {
    raise ParseErr(
      self.scanner_error("got \{self.tok.go_string()}, want newline"),
    )
  }
  stmts
}

///|
fn Parser::parse_small_stmt(self : Parser) -> @syntax.Stmt raise ParseErr {
  match self.tok {
    @lexer.Token::Return => self.parse_return_stmt()
    @lexer.Token::Break => {
      let p = self.pos
      self.advance()
      @syntax.Stmt::SBreak(p)
    }
    @lexer.Token::Continue => {
      let p = self.pos
      self.advance()
      @syntax.Stmt::SContinue(p)
    }
    @lexer.Token::Pass => {
      let p = self.pos
      self.advance()
      @syntax.Stmt::SPass(p)
    }
    @lexer.Token::Load => self.parse_load_stmt()
    _ => self.parse_assign_or_expr_stmt()
  }
}

///|
fn Parser::parse_return_stmt(self : Parser) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  self.advance()
  if self.tok == @lexer.Token::Newline ||
    self.tok == @lexer.Token::EOF ||
    self.tok == @lexer.Token::Semi {
    @syntax.Stmt::SReturn(None, p)
  } else {
    let e = self.parse_test_list_as_expr()
    @syntax.Stmt::SReturn(Some(e), p)
  }
}

///|
fn Parser::parse_load_stmt(self : Parser) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  self.advance()
  self.expect(@lexer.Token::LParen)
  let module_name = match self.tok {
    @lexer.Token::Str(s) => {
      self.advance()
      s
    }
    _ =>
      raise ParseErr(
        self.syntax_error(
          "first operand of load statement must be a string literal",
        ),
      )
  }
  let bindings : Array[(String, String, @errors.Position)] = []
  while self.tok == @lexer.Token::Comma {
    self.advance()
    if self.tok == @lexer.Token::RParen {
      break
    }
    match self.tok {
      @lexer.Token::Str(orig) => {
        let sym_pos = self.pos
        self.advance()
        bindings.push((orig, orig, sym_pos))
      }
      @lexer.Token::Ident(local_name) => {
        let sym_pos = self.pos
        self.advance()
        if self.tok != @lexer.Token::Assign {
          raise ParseErr(
            self.syntax_error(
              "load operand must be \"\{local_name}\" or \{local_name}=\"originalname\"",
            ),
          )
        }
        self.advance()
        match self.tok {
          @lexer.Token::Str(orig) => {
            self.advance()
            bindings.push((local_name, orig, sym_pos))
          }
          _ =>
            raise ParseErr(
              self.syntax_error(
                "original name of loaded symbol must be quoted: \{local_name}=\"originalname\"",
              ),
            )
        }
      }
      _ =>
        raise ParseErr(
          self.syntax_error(
            "load operand must be \"name\" or localname=\"name\" (got \{self.tok.to_string()})",
          ),
        )
    }
  }
  self.expect(@lexer.Token::RParen)
  if bindings.is_empty() {
    raise ParseErr(
      self.syntax_error("load statement must import at least 1 symbol"),
    )
  }
  @syntax.Stmt::SLoad(module_name, bindings, p)
}

///|
fn Parser::parse_assign_or_expr_stmt(
  self : Parser,
) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  let lhs = self.parse_test_list_as_expr()
  match self.tok {
    @lexer.Token::Assign => {
      self.advance()
      let rhs = self.parse_test_list_as_expr()
      @syntax.Stmt::SAssign(lhs, rhs, p)
    }
    @lexer.Token::PlusAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugAdd, rhs, p)
    }
    @lexer.Token::MinusAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugSub, rhs, p)
    }
    @lexer.Token::StarAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugMul, rhs, p)
    }
    @lexer.Token::SlashAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugDiv, rhs, p)
    }
    @lexer.Token::SlashSlashAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugFloorDiv, rhs, p)
    }
    @lexer.Token::PercentAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugMod, rhs, p)
    }
    @lexer.Token::AmpAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugBitAnd, rhs, p)
    }
    @lexer.Token::PipeAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugBitOr, rhs, p)
    }
    @lexer.Token::CircumflexAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugBitXor, rhs, p)
    }
    @lexer.Token::LtLtAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugLShift, rhs, p)
    }
    @lexer.Token::GtGtAssign => {
      self.advance()
      let rhs = self.parse_test()
      @syntax.Stmt::SAugAssign(lhs, @syntax.AugOp::AugRShift, rhs, p)
    }
    _ => @syntax.Stmt::SExpr(lhs)
  }
}

// ---- Compound statements ----

///|
fn Parser::parse_def_stmt(self : Parser) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  self.advance()
  let (name, _) = self.expect_ident()
  self.expect(@lexer.Token::LParen)
  let params = self.parse_params()
  self.expect(@lexer.Token::RParen)
  self.expect(@lexer.Token::Colon)
  let body = self.parse_suite()
  @syntax.Stmt::SDef(name, params, body, p)
}

///|
fn Parser::parse_if_stmt(self : Parser) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  self.advance()
  let cond = self.parse_test()
  self.expect(@lexer.Token::Colon)
  let true_body = self.parse_suite()
  let false_body : Array[@syntax.Stmt] = []
  if self.tok == @lexer.Token::Elif {
    false_body.push(self.parse_elif_branch())
  } else if self.tok == @lexer.Token::Else {
    self.advance()
    self.expect(@lexer.Token::Colon)
    let eb = self.parse_suite()
    for s in eb {
      false_body.push(s)
    }
  }
  @syntax.Stmt::SIf(cond, true_body, false_body, p)
}

///|
fn Parser::parse_elif_branch(self : Parser) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  self.advance()
  let cond = self.parse_test()
  self.expect(@lexer.Token::Colon)
  let true_body = self.parse_suite()
  let false_body : Array[@syntax.Stmt] = []
  if self.tok == @lexer.Token::Elif {
    false_body.push(self.parse_elif_branch())
  } else if self.tok == @lexer.Token::Else {
    self.advance()
    self.expect(@lexer.Token::Colon)
    let eb = self.parse_suite()
    for s in eb {
      false_body.push(s)
    }
  }
  @syntax.Stmt::SIf(cond, true_body, false_body, p)
}

///|
fn Parser::parse_for_stmt(self : Parser) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  self.advance()
  let saved_no_in = self.no_in
  self.no_in = true
  let vars = self.parse_expr_list_as_expr()
  self.no_in = saved_no_in
  self.expect(@lexer.Token::In)
  let iter = self.parse_test_list_as_expr()
  self.expect(@lexer.Token::Colon)
  let body = self.parse_suite()
  @syntax.Stmt::SFor(vars, iter, body, p)
}

///|
fn Parser::parse_while_stmt(self : Parser) -> @syntax.Stmt raise ParseErr {
  let p = self.pos
  self.advance()
  let cond = self.parse_test()
  self.expect(@lexer.Token::Colon)
  let body = self.parse_suite()
  @syntax.Stmt::SWhile(cond, body, p)
}

///|
fn Parser::parse_suite(self : Parser) -> Array[@syntax.Stmt] raise ParseErr {
  if self.tok == @lexer.Token::Newline {
    self.advance()
    if self.tok != @lexer.Token::Indent {
      raise ParseErr(self.syntax_error("expected indented block"))
    }
    self.advance()
    let stmts : Array[@syntax.Stmt] = []
    while self.tok != @lexer.Token::Outdent && self.tok != @lexer.Token::EOF {
      let ss = self.parse_stmt()
      for s in ss {
        stmts.push(s)
      }
      self.consume_newlines()
    }
    if self.tok == @lexer.Token::Outdent {
      self.advance()
    }
    stmts
  } else {
    self.parse_simple_stmt()
  }
}

// ---- Parameters ----

///|
fn Parser::parse_params(self : Parser) -> Array[@syntax.Param] raise ParseErr {
  let params : Array[@syntax.Param] = []
  if self.tok == @lexer.Token::RParen {
    return params
  }
  params.push(self.parse_param())
  if self.tok == @lexer.Token::Colon {
    raise ParseErr(
      self.syntax_error("type annotations are not allowed in Starlark"),
    )
  }
  while self.tok != @lexer.Token::RParen && self.tok != @lexer.Token::EOF {
    self.expect(@lexer.Token::Comma)
    if self.tok == @lexer.Token::RParen {
      break
    }
    params.push(self.parse_param())
    if self.tok == @lexer.Token::Colon {
      raise ParseErr(
        self.syntax_error("type annotations are not allowed in Starlark"),
      )
    }
  }
  params
}

///|
fn Parser::parse_param(self : Parser) -> @syntax.Param raise ParseErr {
  let p = self.pos
  match self.tok {
    @lexer.Token::StarStar => {
      self.advance()
      let (name, _) = self.expect_ident()
      @syntax.Param::ParamKwIdent(name, p)
    }
    @lexer.Token::Star => {
      self.advance()
      match self.tok {
        @lexer.Token::Ident(name) => {
          self.advance()
          @syntax.Param::ParamStarIdent(name, p)
        }
        _ => @syntax.Param::ParamStarBare(p)
      }
    }
    @lexer.Token::Ident(name) => {
      self.advance()
      if self.tok == @lexer.Token::Assign {
        self.advance()
        let default = self.parse_test()
        @syntax.Param::ParamDefault(name, default, p)
      } else {
        @syntax.Param::ParamIdent(name, p)
      }
    }
    _ => raise ParseErr(self.syntax_error("not an identifier"))
  }
}

// ---- Expressions ----

///|
fn Parser::parse_test_list_as_expr(
  self : Parser,
) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let first = self.parse_test()
  if self.tok != @lexer.Token::Comma {
    return first
  }
  let items : Array[@syntax.Expr] = [first]
  while self.tok == @lexer.Token::Comma {
    let comma_pos = self.pos
    self.advance()
    if terminates_expr_list(self.tok) {
      raise ParseErr(
        self.syntax_error_at(
          comma_pos, "unparenthesized tuple with trailing comma",
        ),
      )
    }
    items.push(self.parse_test())
  }
  @syntax.Expr::ETuple(items, p)
}

///|
fn terminates_expr_list(tok : @lexer.Token) -> Bool {
  match tok {
    @lexer.Token::EOF
    | @lexer.Token::Newline
    | @lexer.Token::Semi
    | @lexer.Token::Outdent
    | @lexer.Token::Assign
    | @lexer.Token::RParen
    | @lexer.Token::RBrack
    | @lexer.Token::RBrace => true
    _ => false
  }
}

///|
// Parses for-loop / comprehension target variables. Targets are restricted to
// primary-with-suffix expressions (identifiers, `x.attr`, `x[i]`, groupings).
// This rejects targets like `for a + b in xs`, which would otherwise parse as a
// binary expression.
fn Parser::parse_expr_list_as_expr(
  self : Parser,
) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let first = self.parse_primary()
  if self.tok != @lexer.Token::Comma {
    return first
  }
  let items : Array[@syntax.Expr] = [first]
  while self.tok == @lexer.Token::Comma {
    let comma_pos = self.pos
    self.advance()
    if self.tok == @lexer.Token::In || is_stmt_terminator(self.tok) {
      raise ParseErr(
        self.syntax_error_at(
          comma_pos, "unparenthesized tuple with trailing comma",
        ),
      )
    }
    items.push(self.parse_primary())
  }
  @syntax.Expr::ETuple(items, p)
}

///|
fn is_stmt_terminator(tok : @lexer.Token) -> Bool {
  match tok {
    @lexer.Token::Newline => true
    @lexer.Token::EOF => true
    @lexer.Token::Semi => true
    @lexer.Token::Outdent => true
    _ => false
  }
}

///|
fn Parser::parse_test_no_cond(self : Parser) -> @syntax.Expr raise ParseErr {
  self.bump_depth()
  let result = if self.tok == @lexer.Token::Lambda {
    self.parse_lambda_expr_no_cond()
  } else {
    self.parse_or_test()
  }
  self.pop_depth()
  result
}

///|
fn Parser::parse_lambda_expr_no_cond(
  self : Parser,
) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  self.advance()
  let params = if self.tok == @lexer.Token::Colon {
    []
  } else {
    self.parse_lambda_params()
  }
  self.expect(@lexer.Token::Colon)
  let body = self.parse_test_no_cond()
  @syntax.Expr::ELambda(params, body, p)
}

///|
/// Parses a single Starlark "test" expression (the outermost expression
/// precedence level, covering lambda, if-expr, and binary/unary operators).
///
/// Parameters:
///
/// - `self` : The parser whose token stream is consumed.
///
/// Returns the parsed `Expr` node.
pub fn Parser::parse_test(self : Parser) -> @syntax.Expr raise ParseErr {
  self.bump_depth()
  let result = if self.tok == @lexer.Token::Lambda {
    self.parse_lambda_expr()
  } else {
    let p = self.pos
    let e = self.parse_or_test()
    self.finish_cond_tail_from(e, p)
  }
  self.pop_depth()
  result
}

///|
fn Parser::finish_cond_tail_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  if self.tok == @lexer.Token::If {
    let if_pos = self.pos
    self.advance()
    let cond = self.parse_or_test()
    if self.tok != @lexer.Token::Else {
      raise ParseErr(
        self.syntax_error_at(
          if_pos, "conditional expression without else clause",
        ),
      )
    }
    self.advance()
    let else_e = self.parse_test()
    @syntax.Expr::ECond(e, cond, else_e, p)
  } else {
    e
  }
}

///|
fn Parser::parse_lambda_expr(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  self.advance()
  let params = if self.tok == @lexer.Token::Colon {
    []
  } else {
    self.parse_lambda_params()
  }
  self.expect(@lexer.Token::Colon)
  let body = self.parse_test()
  @syntax.Expr::ELambda(params, body, p)
}

///|
fn Parser::parse_lambda_params(
  self : Parser,
) -> Array[@syntax.Param] raise ParseErr {
  let params : Array[@syntax.Param] = []
  params.push(self.parse_param())
  while self.tok != @lexer.Token::Colon && self.tok != @lexer.Token::EOF {
    self.expect(@lexer.Token::Comma)
    params.push(self.parse_param())
  }
  params
}

///|
fn Parser::parse_or_test(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_and_test()
  while self.tok == @lexer.Token::Or {
    self.advance()
    let r = self.parse_and_test()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpOr, r, p)
  }
  e
}

///|
fn Parser::parse_and_test(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_not_test()
  while self.tok == @lexer.Token::And {
    self.advance()
    let r = self.parse_not_test()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpAnd, r, p)
  }
  e
}

///|
fn Parser::parse_not_test(self : Parser) -> @syntax.Expr raise ParseErr {
  if self.tok == @lexer.Token::Not {
    self.bump_depth()
    let p = self.pos
    self.advance()
    let e = self.parse_not_test()
    self.pop_depth()
    return @syntax.Expr::EUnary(@syntax.UnaryOp::OpNot, e, p)
  }
  self.parse_comparison()
}

///|
fn Parser::parse_comparison(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_bitor_expr()
  let mut prev_op_str : String? = None
  while true {
    let cur_str : String? = match self.tok {
      @lexer.Token::Lt => Some("<")
      @lexer.Token::Le => Some("<=")
      @lexer.Token::Gt => Some(">")
      @lexer.Token::Ge => Some(">=")
      @lexer.Token::Eql => Some("==")
      @lexer.Token::Neq => Some("!=")
      @lexer.Token::In => if self.no_in { None } else { Some("in") }
      @lexer.Token::NotIn => if self.no_in { None } else { Some("not in") }
      @lexer.Token::Not => if self.no_in { None } else { Some("not in") }
      _ => None
    }
    let cur_str = match cur_str {
      None => break
      Some(s) => s
    }
    match prev_op_str {
      Some(prev) =>
        raise ParseErr(
          self.scanner_error(
            "\{prev} does not associate with \{cur_str} (use parens)",
          ),
        )
      None => ()
    }
    let op : @syntax.BinaryOp = match self.tok {
      @lexer.Token::Lt => @syntax.BinaryOp::OpLt
      @lexer.Token::Le => @syntax.BinaryOp::OpLe
      @lexer.Token::Gt => @syntax.BinaryOp::OpGt
      @lexer.Token::Ge => @syntax.BinaryOp::OpGe
      @lexer.Token::Eql => @syntax.BinaryOp::OpEq
      @lexer.Token::Neq => @syntax.BinaryOp::OpNe
      @lexer.Token::In => @syntax.BinaryOp::OpIn
      @lexer.Token::NotIn => @syntax.BinaryOp::OpNotIn
      @lexer.Token::Not => {
        self.advance()
        if self.tok != @lexer.Token::In {
          raise ParseErr(
            self.scanner_error("got \{self.tok.go_string()}, want in"),
          )
        }
        @syntax.BinaryOp::OpNotIn
      }
      _ => break
    }
    prev_op_str = Some(cur_str)
    self.advance()
    let r = self.parse_bitor_expr()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::parse_bitor_expr(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_bitxor_expr()
  while self.tok == @lexer.Token::Pipe {
    self.advance()
    let r = self.parse_bitxor_expr()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpBitOr, r, p)
  }
  e
}

///|
fn Parser::parse_bitxor_expr(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_bitand_expr()
  while self.tok == @lexer.Token::Circumflex {
    self.advance()
    let r = self.parse_bitand_expr()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpBitXor, r, p)
  }
  e
}

///|
fn Parser::parse_bitand_expr(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_shift_expr()
  while self.tok == @lexer.Token::Amp {
    self.advance()
    let r = self.parse_shift_expr()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpBitAnd, r, p)
  }
  e
}

///|
fn Parser::parse_shift_expr(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_arith_expr()
  while true {
    let op = match self.tok {
      @lexer.Token::LtLt => @syntax.BinaryOp::OpLShift
      @lexer.Token::GtGt => @syntax.BinaryOp::OpRShift
      _ => break
    }
    self.advance()
    let r = self.parse_arith_expr()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::parse_arith_expr(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_term()
  while true {
    let op = match self.tok {
      @lexer.Token::Plus => @syntax.BinaryOp::OpAdd
      @lexer.Token::Minus => @syntax.BinaryOp::OpSub
      _ => break
    }
    self.advance()
    let r = self.parse_term()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::parse_term(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  let mut e = self.parse_factor()
  while true {
    let op = match self.tok {
      @lexer.Token::Star => @syntax.BinaryOp::OpMul
      @lexer.Token::Slash => @syntax.BinaryOp::OpDiv
      @lexer.Token::SlashSlash => @syntax.BinaryOp::OpFloorDiv
      @lexer.Token::Percent => @syntax.BinaryOp::OpMod
      _ => break
    }
    self.advance()
    let r = self.parse_factor()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::parse_factor(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  match self.tok {
    @lexer.Token::Plus => {
      self.bump_depth()
      self.advance()
      let e = self.parse_factor()
      self.pop_depth()
      @syntax.Expr::EUnary(@syntax.UnaryOp::OpPlus, e, p)
    }
    @lexer.Token::Minus => {
      self.bump_depth()
      self.advance()
      let e = self.parse_factor()
      self.pop_depth()
      @syntax.Expr::EUnary(@syntax.UnaryOp::OpMinus, e, p)
    }
    @lexer.Token::Tilde => {
      self.bump_depth()
      self.advance()
      let e = self.parse_factor()
      self.pop_depth()
      @syntax.Expr::EUnary(@syntax.UnaryOp::OpBitNot, e, p)
    }
    _ => self.parse_primary()
  }
}

///|
fn Parser::parse_primary(self : Parser) -> @syntax.Expr raise ParseErr {
  let mut e = self.parse_atom()
  while true {
    match self.tok {
      @lexer.Token::Dot => {
        let p = self.pos
        self.advance()
        let (name, _) = self.expect_ident()
        e = @syntax.Expr::EDot(e, name, p)
      }
      @lexer.Token::LBrack => {
        let p = self.pos
        self.advance()
        e = self.parse_subscript_tail(e, p)
      }
      @lexer.Token::LParen => {
        let p = self.pos
        self.advance()
        let args = self.parse_call_args()
        self.expect(@lexer.Token::RParen)
        e = @syntax.Expr::ECall(e, args, p)
      }
      _ => break
    }
  }
  e
}

///|
fn Parser::parse_subscript_tail(
  self : Parser,
  obj : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  if self.tok == @lexer.Token::Colon {
    let slice = self.parse_slice_from_colon(obj, None, p)
    self.expect(@lexer.Token::RBrack)
    slice
  } else {
    let idx = self.parse_test()
    if self.tok == @lexer.Token::Colon {
      let slice = self.parse_slice_from_colon(obj, Some(idx), p)
      self.expect(@lexer.Token::RBrack)
      slice
    } else if self.tok == @lexer.Token::Comma {
      let elems : Array[@syntax.Expr] = [idx]
      while self.tok == @lexer.Token::Comma {
        let comma_pos = self.pos
        self.advance()
        if self.tok == @lexer.Token::RBrack {
          raise ParseErr(
            self.syntax_error_at(
              comma_pos, "unparenthesized tuple with trailing comma",
            ),
          )
        }
        elems.push(self.parse_test())
      }
      if self.tok == @lexer.Token::Colon {
        let tuple_lo = @syntax.Expr::ETuple(elems, p)
        let slice = self.parse_slice_from_colon(obj, Some(tuple_lo), p)
        self.expect(@lexer.Token::RBrack)
        slice
      } else {
        self.expect(@lexer.Token::RBrack)
        let tuple_key = @syntax.Expr::ETuple(elems, p)
        @syntax.Expr::EIndex(obj, tuple_key, p)
      }
    } else {
      self.expect(@lexer.Token::RBrack)
      @syntax.Expr::EIndex(obj, idx, p)
    }
  }
}

///|
fn Parser::parse_slice_from_colon(
  self : Parser,
  obj : @syntax.Expr,
  lo : @syntax.Expr?,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  self.advance()
  let hi = if self.tok == @lexer.Token::RBrack ||
    self.tok == @lexer.Token::Colon {
    None
  } else {
    Some(self.parse_test())
  }
  let step = if self.tok == @lexer.Token::Colon {
    self.advance()
    if self.tok == @lexer.Token::RBrack {
      None
    } else {
      Some(self.parse_test())
    }
  } else {
    None
  }
  @syntax.Expr::ESlice(obj, lo, hi, step, p)
}

///|
fn Parser::parse_call_args(self : Parser) -> Array[@syntax.Arg] raise ParseErr {
  let args : Array[@syntax.Arg] = []
  if self.tok == @lexer.Token::RParen {
    return args
  }
  args.push(self.parse_call_arg())
  while self.tok != @lexer.Token::RParen && self.tok != @lexer.Token::EOF {
    self.expect(@lexer.Token::Comma)
    if self.tok == @lexer.Token::RParen {
      break
    }
    args.push(self.parse_call_arg())
  }
  args
}

///|
fn Parser::parse_call_arg(self : Parser) -> @syntax.Arg raise ParseErr {
  let p = self.pos
  match self.tok {
    @lexer.Token::StarStar => {
      self.advance()
      let e = self.parse_test()
      @syntax.Arg::ArgKwArgs(e)
    }
    @lexer.Token::Star => {
      self.advance()
      let e = self.parse_test()
      @syntax.Arg::ArgStarArgs(e)
    }
    @lexer.Token::Ident(name) => {
      self.advance()
      if self.tok == @lexer.Token::Assign {
        self.advance()
        let v = self.parse_test()
        @syntax.Arg::ArgKw(name, v, p)
      } else {
        // The ident-positional path bypasses parse_test, so guard depth here to
        // prevent stack overflow on deeply chained calls like f(f(f(...))).
        self.bump_depth()
        let ident_expr = @syntax.Expr::EIdent(name, p)
        let e = self.finish_primary_from_expr(ident_expr)
        let full = self.finish_test_from(e, p)
        self.pop_depth()
        self.reject_malformed_kwarg()
        @syntax.Arg::ArgPos(full)
      }
    }
    _ => {
      let e = self.parse_test()
      self.reject_malformed_kwarg()
      @syntax.Arg::ArgPos(e)
    }
  }
}

///|
fn Parser::reject_malformed_kwarg(self : Parser) -> Unit raise ParseErr {
  if self.tok == @lexer.Token::Assign {
    raise ParseErr(
      self.syntax_error("keyword argument must have form name=expr"),
    )
  }
}

///|
fn Parser::finish_primary_from_expr(
  self : Parser,
  e : @syntax.Expr,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while true {
    match self.tok {
      @lexer.Token::Dot => {
        let pp = self.pos
        self.advance()
        let (name, _) = self.expect_ident()
        e = @syntax.Expr::EDot(e, name, pp)
      }
      @lexer.Token::LBrack => {
        let pp = self.pos
        self.advance()
        e = self.parse_subscript_tail(e, pp)
      }
      @lexer.Token::LParen => {
        let pp = self.pos
        self.advance()
        let args = self.parse_call_args()
        self.expect(@lexer.Token::RParen)
        e = @syntax.Expr::ECall(e, args, pp)
      }
      _ => break
    }
  }
  e
}

///|
fn Parser::finish_full_expr(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let e1 = self.finish_term_from(e, p)
  let e2 = self.finish_arith_from(e1, p)
  let e3 = self.finish_shift_from(e2, p)
  let e4 = self.finish_bitand_from(e3, p)
  let e5 = self.finish_bitxor_from(e4, p)
  let e6 = self.finish_bitor_from(e5, p)
  let e7 = self.finish_comparison_from(e6, p)
  let e8 = self.finish_and_from(e7, p)
  self.finish_or_from(e8, p)
}

///|
fn Parser::finish_test_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let or_e = self.finish_full_expr(e, p)
  self.finish_cond_tail_from(or_e, p)
}

///|
fn Parser::finish_term_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while true {
    let op = match self.tok {
      @lexer.Token::Star => @syntax.BinaryOp::OpMul
      @lexer.Token::Slash => @syntax.BinaryOp::OpDiv
      @lexer.Token::SlashSlash => @syntax.BinaryOp::OpFloorDiv
      @lexer.Token::Percent => @syntax.BinaryOp::OpMod
      _ => break
    }
    self.advance()
    let r = self.parse_factor()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::finish_arith_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while true {
    let op = match self.tok {
      @lexer.Token::Plus => @syntax.BinaryOp::OpAdd
      @lexer.Token::Minus => @syntax.BinaryOp::OpSub
      _ => break
    }
    self.advance()
    let r = self.parse_term()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::finish_shift_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while true {
    let op = match self.tok {
      @lexer.Token::LtLt => @syntax.BinaryOp::OpLShift
      @lexer.Token::GtGt => @syntax.BinaryOp::OpRShift
      _ => break
    }
    self.advance()
    let r = self.parse_arith_expr()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::finish_bitand_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while self.tok == @lexer.Token::Amp {
    self.advance()
    let r = self.parse_shift_expr()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpBitAnd, r, p)
  }
  e
}

///|
fn Parser::finish_bitxor_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while self.tok == @lexer.Token::Circumflex {
    self.advance()
    let r = self.parse_bitand_expr()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpBitXor, r, p)
  }
  e
}

///|
fn Parser::finish_bitor_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while self.tok == @lexer.Token::Pipe {
    self.advance()
    let r = self.parse_bitxor_expr()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpBitOr, r, p)
  }
  e
}

///|
fn Parser::finish_comparison_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  let mut prev_op_str : String? = None
  while true {
    let cur_str : String? = match self.tok {
      @lexer.Token::Lt => Some("<")
      @lexer.Token::Le => Some("<=")
      @lexer.Token::Gt => Some(">")
      @lexer.Token::Ge => Some(">=")
      @lexer.Token::Eql => Some("==")
      @lexer.Token::Neq => Some("!=")
      @lexer.Token::In => if self.no_in { None } else { Some("in") }
      @lexer.Token::NotIn => if self.no_in { None } else { Some("not in") }
      @lexer.Token::Not => if self.no_in { None } else { Some("not in") }
      _ => None
    }
    let cur_str = match cur_str {
      None => break
      Some(s) => s
    }
    match prev_op_str {
      Some(prev) =>
        raise ParseErr(
          self.scanner_error(
            "\{prev} does not associate with \{cur_str} (use parens)",
          ),
        )
      None => ()
    }
    let op : @syntax.BinaryOp = match self.tok {
      @lexer.Token::Lt => @syntax.BinaryOp::OpLt
      @lexer.Token::Le => @syntax.BinaryOp::OpLe
      @lexer.Token::Gt => @syntax.BinaryOp::OpGt
      @lexer.Token::Ge => @syntax.BinaryOp::OpGe
      @lexer.Token::Eql => @syntax.BinaryOp::OpEq
      @lexer.Token::Neq => @syntax.BinaryOp::OpNe
      @lexer.Token::In => @syntax.BinaryOp::OpIn
      @lexer.Token::NotIn => @syntax.BinaryOp::OpNotIn
      @lexer.Token::Not => {
        self.advance()
        if self.tok != @lexer.Token::In {
          raise ParseErr(
            self.scanner_error("got \{self.tok.go_string()}, want in"),
          )
        }
        @syntax.BinaryOp::OpNotIn
      }
      _ => break
    }
    prev_op_str = Some(cur_str)
    self.advance()
    let r = self.parse_bitor_expr()
    e = @syntax.Expr::EBinary(e, op, r, p)
  }
  e
}

///|
fn Parser::finish_and_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while self.tok == @lexer.Token::And {
    self.advance()
    let r = self.parse_not_test()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpAnd, r, p)
  }
  e
}

///|
fn Parser::finish_or_from(
  self : Parser,
  e : @syntax.Expr,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  let mut e = e
  while self.tok == @lexer.Token::Or {
    self.advance()
    let r = self.parse_and_test()
    e = @syntax.Expr::EBinary(e, @syntax.BinaryOp::OpOr, r, p)
  }
  e
}

// ---- Atoms ----

///|
fn Parser::parse_atom(self : Parser) -> @syntax.Expr raise ParseErr {
  let p = self.pos
  match self.tok {
    @lexer.Token::Int(n) => {
      self.advance()
      @syntax.Expr::ELiteral(@syntax.LiteralVal::LitInt(n), p)
    }
    @lexer.Token::Float(f) => {
      self.advance()
      @syntax.Expr::ELiteral(@syntax.LiteralVal::LitFloat(f), p)
    }
    @lexer.Token::Str(s) => {
      self.advance()
      @syntax.Expr::ELiteral(@syntax.LiteralVal::LitString(s), p)
    }
    @lexer.Token::Bytes(b) => {
      self.advance()
      @syntax.Expr::ELiteral(@syntax.LiteralVal::LitBytes(b), p)
    }
    @lexer.Token::Ident(name) => {
      self.advance()
      @syntax.Expr::EIdent(name, p)
    }
    @lexer.Token::LParen => self.parse_paren_expr(p)
    @lexer.Token::LBrack => self.parse_list_or_comp(p)
    @lexer.Token::LBrace => self.parse_dict_or_set(p)
    _ =>
      raise ParseErr(
        self.syntax_error(
          "got \{self.tok.go_string()}, want primary expression",
        ),
      )
  }
}

///|
fn Parser::parse_paren_expr(
  self : Parser,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  self.advance()
  if self.tok == @lexer.Token::RParen {
    self.advance()
    return @syntax.Expr::ETuple([], p)
  }
  let first = self.parse_test()
  if self.tok == @lexer.Token::Comma {
    let items : Array[@syntax.Expr] = [first]
    while self.tok == @lexer.Token::Comma {
      self.advance()
      if self.tok == @lexer.Token::RParen {
        break
      }
      items.push(self.parse_test())
    }
    self.expect(@lexer.Token::RParen)
    @syntax.Expr::ETuple(items, p)
  } else {
    self.expect(@lexer.Token::RParen)
    first
  }
}

///|
fn Parser::parse_list_or_comp(
  self : Parser,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  self.advance()
  if self.tok == @lexer.Token::RBrack {
    self.advance()
    return @syntax.Expr::EList([], p)
  }
  let first = self.parse_test()
  if self.tok == @lexer.Token::For {
    let clauses = self.parse_comp_clauses()
    self.expect(@lexer.Token::RBrack)
    @syntax.Expr::EListComp(first, clauses, p)
  } else {
    let items : Array[@syntax.Expr] = [first]
    while self.tok == @lexer.Token::Comma {
      self.advance()
      if self.tok == @lexer.Token::RBrack {
        break
      }
      items.push(self.parse_test())
    }
    self.expect(@lexer.Token::RBrack)
    @syntax.Expr::EList(items, p)
  }
}

///|
fn Parser::parse_dict_or_set(
  self : Parser,
  p : @errors.Position,
) -> @syntax.Expr raise ParseErr {
  self.advance()
  if self.tok == @lexer.Token::RBrace {
    self.advance()
    return @syntax.Expr::EDict([], p)
  }
  let first = self.parse_test()
  if self.tok == @lexer.Token::Colon {
    self.advance()
    let val = self.parse_test()
    if self.tok == @lexer.Token::For {
      let clauses = self.parse_comp_clauses()
      self.expect(@lexer.Token::RBrace)
      @syntax.Expr::EDictComp(first, val, clauses, p)
    } else {
      let pairs : Array[(@syntax.Expr, @syntax.Expr)] = [(first, val)]
      while self.tok == @lexer.Token::Comma {
        self.advance()
        if self.tok == @lexer.Token::RBrace {
          break
        }
        let k = self.parse_test()
        self.expect(@lexer.Token::Colon)
        let v = self.parse_test()
        pairs.push((k, v))
      }
      self.expect(@lexer.Token::RBrace)
      @syntax.Expr::EDict(pairs, p)
    }
  } else if self.tok == @lexer.Token::For {
    let clauses = self.parse_comp_clauses()
    self.expect(@lexer.Token::RBrace)
    @syntax.Expr::ESetComp(first, clauses, p)
  } else {
    if self.tok != @lexer.Token::Comma &&
      self.tok != @lexer.Token::RBrace &&
      self.tok != @lexer.Token::EOF {
      self.expect(@lexer.Token::Colon)
    }
    let items : Array[@syntax.Expr] = [first]
    while self.tok == @lexer.Token::Comma {
      self.advance()
      if self.tok == @lexer.Token::RBrace {
        break
      }
      items.push(self.parse_test())
    }
    self.expect(@lexer.Token::RBrace)
    @syntax.Expr::ESet(items, p)
  }
}

///|
fn Parser::parse_comp_clauses(
  self : Parser,
) -> Array[@syntax.CompClause] raise ParseErr {
  let clauses : Array[@syntax.CompClause] = []
  while true {
    match self.tok {
      @lexer.Token::For => {
        let pp = self.pos
        self.advance()
        let saved_no_in = self.no_in
        self.no_in = true
        let vars = self.parse_expr_list_as_expr()
        self.no_in = saved_no_in
        self.expect(@lexer.Token::In)
        let iter = self.parse_or_test()
        clauses.push(@syntax.CompClause::ClauseFor(vars, iter, pp))
      }
      @lexer.Token::If => {
        let pp = self.pos
        self.advance()
        let cond = self.parse_test_no_cond()
        clauses.push(@syntax.CompClause::ClauseIf(cond, pp))
      }
      @lexer.Token::RBrack | @lexer.Token::RBrace | @lexer.Token::RParen =>
        break
      _ =>
        raise ParseErr(
          self.scanner_error(
            "got \{self.tok.go_string()}, want ']', for, or if",
          ),
        )
    }
  }
  clauses
}
