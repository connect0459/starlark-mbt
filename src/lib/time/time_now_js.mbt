///|
extern "js" fn js_date_now_ms() -> Double = "() => Date.now()"

///|
pub fn get_unix_time_now() -> (Int64, Int) {
  let ms_i = js_date_now_ms().to_int64()
  let sec = ms_i / 1000L
  let nsec = (ms_i % 1000L * 1_000_000L).to_int()
  (sec, nsec)
}
