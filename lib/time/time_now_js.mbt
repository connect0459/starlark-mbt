///|
extern "js" fn js_date_now_ms() -> Double = "() => Date.now()"

///|
pub fn get_unix_time_now() -> (Int64, Int) {
  let ms = js_date_now_ms()
  let sec = (ms / 1000.0).to_int64()
  let nsec = (ms % 1000.0 * 1_000_000.0).to_int()
  (sec, nsec)
}
