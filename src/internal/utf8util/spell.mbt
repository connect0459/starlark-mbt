///|
// ASCII underscore codepoint, skipped during spell-folding.
let spell_ascii_underscore : Int = 0x5F // '_'

///|
/// Folds a string to a case-insensitive, underscore-stripped sequence of
/// codepoints for fuzzy comparison. ASCII letters are lowercased; `_` is
/// dropped; all other characters are kept as-is.
///
/// Parameters:
///
/// * `s` : The string to fold.
///
/// Returns an `Array[Int]` of folded codepoints.
pub fn spell_fold_chars(s : String) -> Array[Int] {
  let arr : Array[Int] = []
  for ch in s {
    let c = ch.to_int()
    if c == spell_ascii_underscore {
      // skip '_'
    } else if c >= ascii_upper_a && c <= ascii_upper_z {
      arr.push(c + ascii_case_shift)
    } else {
      arr.push(c)
    }
  }
  arr
}

///|
/// Computes the Levenshtein edit distance between two folded codepoint arrays,
/// bailing out early when the distance exceeds `max_dist`.
///
/// Parameters:
///
/// * `x` : Folded codepoints of the first string.
/// * `y` : Folded codepoints of the second string.
/// * `max_dist` : Upper bound; the function returns early with a value ≥
///   `max_dist` when the true distance would exceed it.
///
/// Returns the edit distance, or a value ≥ `max_dist` if the strings are
/// farther apart than the bound.
pub fn spell_levenshtein(x : Array[Int], y : Array[Int], max_dist : Int) -> Int {
  let (xs, ys) = if x.length() <= y.length() { (x, y) } else { (y, x) }
  let xl = xs.length()
  let yl = ys.length()
  let diff = yl - xl
  if diff > max_dist {
    return diff
  }
  let row = Array::make(yl + 1, 0)
  for i in 0..<(yl + 1) {
    row[i] = i
  }
  for i in 1..<(xl + 1) {
    row[0] = i
    let mut best = i
    let mut prev = i - 1
    for j in 1..<(yl + 1) {
      let sub = if xs[i - 1] != ys[j - 1] { 1 } else { 0 }
      let a = prev + sub
      let b = 1 + row[j - 1]
      let c = 1 + row[j]
      let k = if a <= b && a <= c { a } else if b <= c { b } else { c }
      prev = row[j]
      row[j] = k
      if k < best {
        best = k
      }
    }
    if best > max_dist {
      return best
    }
  }
  row[yl]
}

///|
/// Returns the best-matching candidate for `x` among `candidates`, or `""`
/// when no candidate is within half the input length (rounded up).
///
/// Comparison is case-insensitive and ignores underscores (via
/// `spell_fold_chars`). This threshold matches starlark-go's "did you mean"
/// acceptance window.
///
/// Parameters:
///
/// * `x` : The misspelled name.
/// * `candidates` : The set of valid names to search.
///
/// Returns the nearest candidate string, or `""` if none is close enough.
pub fn spell_nearest(x : String, candidates : Array[String]) -> String {
  let fx = spell_fold_chars(x)
  // Accept suggestions within half the input length (rounded up).
  let max_dist = (fx.length() + 1) / 2
  let mut best = ""
  let mut best_d = max_dist
  for c in candidates {
    let fc = spell_fold_chars(c)
    let d = spell_levenshtein(fx, fc, best_d)
    if d < best_d {
      best_d = d
      best = c
    }
  }
  best
}
