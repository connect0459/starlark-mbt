///|
priv enum Signal {
  SigNormal
  SigBreak
  SigContinue
  SigReturn(@value.Value)
}

///|
priv suberror EvalErr {
  EvalErr(@errors.EvalError)
}
