///|
/// Applies an augmented-assignment operator to `lv` and `rv`. `+=` on a list and
/// `|=` on a dict mutate the left operand in place (so aliases observe the
/// change); every other operator delegates to the corresponding binary
/// operation. Shared by the VM's `AugApply` opcode.
fn eval_aug_val(
  ctx : EvalContext,
  lv : @value.Value,
  aug_op : @syntax.AugOp,
  rv : @value.Value,
  pos : @errors.Position,
) -> @value.Value raise EvalErr {
  match (lv, aug_op) {
    (@value.Value::List(l), @syntax.AugOp::AugAdd) =>
      if rv is @value.Value::List(src) {
        let snapshot = src.copy_items()
        check(ctx, l.check_mutable("apply += to"))
        for item in snapshot {
          l.push(item) |> ignore
        }
        lv
      } else {
        match @value.iterate(rv) {
          Ok(iter) => {
            match l.check_mutable("apply += to") {
              Err(msg) => {
                iter.done()
                raise EvalErr(make_eval_error(ctx, msg))
              }
              Ok(_) => ()
            }
            while true {
              match iter.next() {
                None => break
                Some(item) => l.push(item) |> ignore
              }
            }
            iter.done()
            lv
          }
          Err(_) => eval_binary(ctx, lv, @syntax.BinaryOp::OpAdd, rv, pos)
        }
      }
    (@value.Value::Dict(ld), @syntax.AugOp::AugBitOr) =>
      match rv {
        @value.Value::Dict(rd) => {
          let pairs : Array[(@value.Value, @value.Value)] = []
          rd.each(fn(k, v) { pairs.push((k, v)) })
          for pair in pairs {
            let (k, v) = pair
            check(ctx, ld.set(k, v))
          }
          lv
        }
        _ =>
          raise EvalErr(
            make_eval_error(ctx, "unknown binary op: dict | \{rv.type_name()}"),
          )
      }
    _ => {
      let bin_op = aug_to_bin_op(aug_op)
      eval_binary(ctx, lv, bin_op, rv, pos)
    }
  }
}
