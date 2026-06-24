///|
fn is_valid_timezone(name : String) -> Bool {
  for z in iana_sorted {
    if z == name {
      return true
    }
  }
  false
}

///|
fn get_tz_offset_at(name : String, _unix_time : Int64) -> Int? {
  match name {
    "UTC"
    | "Etc/UTC"
    | "Etc/GMT"
    | "Etc/GMT+0"
    | "Etc/GMT-0"
    | "Etc/GMT0"
    | "Etc/Greenwich"
    | "Etc/UCT"
    | "Etc/Universal"
    | "Etc/Zulu"
    | "GMT"
    | "GMT+0"
    | "GMT-0"
    | "GMT0"
    | "Greenwich"
    | "UCT"
    | "Universal"
    | "Zulu" => Some(0)
    "US/Eastern"
    | "America/New_York"
    | "America/Detroit"
    | "America/Indiana/Indianapolis"
    | "America/Indianapolis"
    | "America/Indiana/Marengo"
    | "America/Indiana/Petersburg"
    | "America/Indiana/Vevay"
    | "America/Indiana/Vincennes"
    | "America/Indiana/Winamac"
    | "America/Kentucky/Louisville"
    | "America/Kentucky/Monticello"
    | "America/Louisville"
    | "America/Montreal"
    | "America/Nassau"
    | "America/Nipigon"
    | "America/Pangnirtung"
    | "America/Thunder_Bay"
    | "America/Toronto"
    | "Canada/Eastern"
    | "EST5EDT"
    | "US/East-Indiana"
    | "US/Michigan" => Some(-18000)
    "US/Central"
    | "America/Chicago"
    | "America/Indiana/Knox"
    | "America/Indiana/Tell_City"
    | "America/Knox_IN"
    | "America/Matamoros"
    | "America/Menominee"
    | "America/Merida"
    | "America/Monterrey"
    | "America/North_Dakota/Beulah"
    | "America/North_Dakota/Center"
    | "America/North_Dakota/New_Salem"
    | "America/Rainy_River"
    | "America/Rankin_Inlet"
    | "America/Regina"
    | "America/Resolute"
    | "America/Swift_Current"
    | "America/Winnipeg"
    | "Canada/Central"
    | "Canada/Saskatchewan"
    | "CST6CDT"
    | "US/Indiana-Starke" => Some(-21600)
    "US/Mountain"
    | "America/Boise"
    | "America/Cambridge_Bay"
    | "America/Denver"
    | "America/Edmonton"
    | "America/Inuvik"
    | "America/Ojinaga"
    | "America/Shiprock"
    | "America/Yellowknife"
    | "Canada/Mountain"
    | "MST7MDT"
    | "Navajo"
    | "US/Arizona"
    | "America/Phoenix"
    | "America/Creston" => Some(-25200)
    "US/Pacific"
    | "America/Dawson"
    | "America/Dawson_Creek"
    | "America/Ensenada"
    | "America/Fort_Nelson"
    | "America/Hermosillo"
    | "America/Los_Angeles"
    | "America/Santa_Isabel"
    | "America/Tijuana"
    | "America/Vancouver"
    | "America/Whitehorse"
    | "Canada/Pacific"
    | "Canada/Yukon"
    | "Mexico/BajaNorte"
    | "PST8PDT" => Some(-28800)
    "US/Alaska"
    | "America/Anchorage"
    | "America/Juneau"
    | "America/Metlakatla"
    | "America/Nome"
    | "America/Sitka"
    | "America/Yakutat"
    | "America/Adak" => Some(-32400)
    "US/Hawaii"
    | "America/Honolulu"
    | "Pacific/Honolulu"
    | "Pacific/Johnston"
    | "HST" => Some(-36000)
    "US/Samoa" | "Pacific/Pago_Pago" | "Pacific/Samoa" | "America/Pago_Pago" =>
      Some(-39600)
    "America/Halifax"
    | "America/Glace_Bay"
    | "America/Goose_Bay"
    | "America/Moncton"
    | "America/Thule"
    | "Canada/Atlantic" => Some(-14400)
    "America/St_Johns" | "Canada/Newfoundland" => Some(-12600)
    "America/Sao_Paulo" | "America/Bahia" | "Brazil/East" => Some(-10800)
    "America/Buenos_Aires"
    | "America/Argentina/Buenos_Aires"
    | "America/Argentina/Cordoba" => Some(-10800)
    "America/Bogota" | "America/Lima" | "America/Jamaica" | "Jamaica" =>
      Some(-18000)
    "America/Caracas" => Some(-16200)
    "America/Santiago" | "Chile/Continental" => Some(-14400)
    "Europe/London"
    | "Europe/Dublin"
    | "Europe/Lisbon"
    | "Europe/Belfast"
    | "Europe/Guernsey"
    | "Europe/Isle_of_Man"
    | "Europe/Jersey"
    | "GB"
    | "GB-Eire"
    | "WET"
    | "Eire"
    | "Iceland" => Some(0)
    "Europe/Amsterdam"
    | "Europe/Andorra"
    | "Europe/Belgrade"
    | "Europe/Berlin"
    | "Europe/Bratislava"
    | "Europe/Brussels"
    | "Europe/Budapest"
    | "Europe/Busingen"
    | "Europe/Copenhagen"
    | "Europe/Gibraltar"
    | "Europe/Ljubljana"
    | "Europe/Luxembourg"
    | "Europe/Madrid"
    | "Europe/Malta"
    | "Europe/Monaco"
    | "Europe/Oslo"
    | "Europe/Paris"
    | "Europe/Podgorica"
    | "Europe/Prague"
    | "Europe/Rome"
    | "Europe/San_Marino"
    | "Europe/Sarajevo"
    | "Europe/Skopje"
    | "Europe/Stockholm"
    | "Europe/Tirane"
    | "Europe/Vaduz"
    | "Europe/Vatican"
    | "Europe/Vienna"
    | "Europe/Warsaw"
    | "Europe/Zagreb"
    | "Europe/Zurich"
    | "MET"
    | "CET"
    | "Poland" => Some(3600)
    "Europe/Athens"
    | "Europe/Bucharest"
    | "Europe/Chisinau"
    | "Europe/Helsinki"
    | "Europe/Kiev"
    | "Europe/Kyiv"
    | "Europe/Mariehamn"
    | "Europe/Nicosia"
    | "Europe/Riga"
    | "Europe/Sofia"
    | "Europe/Tallinn"
    | "Europe/Tiraspol"
    | "Europe/Uzhgorod"
    | "Europe/Vilnius"
    | "Europe/Zaporozhye"
    | "EET"
    | "Asia/Istanbul"
    | "Europe/Istanbul"
    | "Turkey" => Some(7200)
    "Europe/Kaliningrad" => Some(7200)
    "Europe/Minsk" => Some(10800)
    "Europe/Moscow" | "Europe/Simferopol" | "Europe/Volgograd" | "W-SU" =>
      Some(10800)
    "Europe/Samara"
    | "Europe/Astrakhan"
    | "Europe/Saratov"
    | "Europe/Ulyanovsk" => Some(14400)
    "Asia/Yekaterinburg" => Some(18000)
    "Asia/Novosibirsk"
    | "Asia/Novokuznetsk"
    | "Asia/Barnaul"
    | "Asia/Tomsk"
    | "Asia/Omsk" => Some(21600)
    "Asia/Krasnoyarsk" => Some(25200)
    "Asia/Shanghai"
    | "Asia/Chongqing"
    | "Asia/Chungking"
    | "Asia/Harbin"
    | "Asia/Hong_Kong"
    | "Asia/Macao"
    | "Asia/Macau"
    | "Asia/Taipei"
    | "Asia/Ujung_Pandang"
    | "Asia/Ulaanbaatar"
    | "Asia/Ulan_Bator"
    | "PRC"
    | "Hongkong"
    | "ROC"
    | "Singapore"
    | "Asia/Singapore"
    | "Asia/Kuala_Lumpur"
    | "Asia/Kuching"
    | "Australia/Perth"
    | "Australia/West" => Some(28800)
    "Asia/Tokyo" | "Asia/Seoul" | "Japan" | "ROK" => Some(32400)
    "Australia/Sydney"
    | "Australia/Melbourne"
    | "Australia/Brisbane"
    | "Australia/Hobart"
    | "Australia/ACT"
    | "Australia/Canberra"
    | "Australia/NSW"
    | "Australia/Queensland"
    | "Australia/Tasmania"
    | "Australia/Victoria"
    | "Australia/Currie"
    | "Australia/Lindeman"
    | "Pacific/Port_Moresby" => Some(36000)
    "Australia/Darwin" | "Australia/North" => Some(34200)
    "Australia/Adelaide"
    | "Australia/Broken_Hill"
    | "Australia/South"
    | "Australia/Yancowinna" => Some(34200)
    "Pacific/Auckland" | "Pacific/Fiji" | "NZ" => Some(43200)
    "Asia/Kolkata" | "Asia/Calcutta" => Some(19800)
    "Asia/Karachi" => Some(18000)
    "Asia/Dubai"
    | "Asia/Muscat"
    | "Asia/Tbilisi"
    | "Asia/Yerevan"
    | "Asia/Baku" => Some(14400)
    "Asia/Kabul" => Some(16200)
    "Asia/Tehran" | "Iran" => Some(12600)
    "Asia/Baghdad"
    | "Asia/Aden"
    | "Asia/Kuwait"
    | "Asia/Riyadh"
    | "Asia/Qatar"
    | "Asia/Bahrain" => Some(10800)
    "Asia/Beirut"
    | "Asia/Amman"
    | "Asia/Damascus"
    | "Asia/Gaza"
    | "Asia/Hebron"
    | "Asia/Jerusalem"
    | "Asia/Tel_Aviv"
    | "Asia/Nicosia"
    | "Asia/Famagusta"
    | "Israel"
    | "Egypt" => Some(7200)
    "Africa/Cairo" => Some(7200)
    "Africa/Lagos"
    | "Africa/Bangui"
    | "Africa/Brazzaville"
    | "Africa/Douala"
    | "Africa/Kinshasa"
    | "Africa/Libreville"
    | "Africa/Luanda"
    | "Africa/Malabo"
    | "Africa/Ndjamena"
    | "Africa/Niamey"
    | "Africa/Porto-Novo"
    | "Africa/Tunis"
    | "Africa/Windhoek" => Some(3600)
    "Africa/Nairobi"
    | "Africa/Addis_Ababa"
    | "Africa/Asmara"
    | "Africa/Asmera"
    | "Africa/Dar_es_Salaam"
    | "Africa/Djibouti"
    | "Africa/Kampala"
    | "Africa/Mogadishu"
    | "Indian/Antananarivo"
    | "Indian/Comoro"
    | "Indian/Mayotte" => Some(10800)
    "Africa/Johannesburg"
    | "Africa/Gaborone"
    | "Africa/Harare"
    | "Africa/Lusaka"
    | "Africa/Maputo"
    | "Africa/Maseru"
    | "Africa/Mbabane" => Some(7200)
    "Atlantic/Reykjavik" => Some(0)
    "Atlantic/Azores" | "America/Scoresbysund" => Some(-3600)
    "Atlantic/Cape_Verde" => Some(-3600)
    "Atlantic/South_Georgia" => Some(-7200)
    "Etc/GMT+1" => Some(-3600)
    "Etc/GMT+2" => Some(-7200)
    "Etc/GMT+3" => Some(-10800)
    "Etc/GMT+4" => Some(-14400)
    "Etc/GMT+5" => Some(-18000)
    "Etc/GMT+6" => Some(-21600)
    "Etc/GMT+7" => Some(-25200)
    "Etc/GMT+8" => Some(-28800)
    "Etc/GMT+9" => Some(-32400)
    "Etc/GMT+10" => Some(-36000)
    "Etc/GMT+11" => Some(-39600)
    "Etc/GMT+12" => Some(-43200)
    "Etc/GMT-1" => Some(3600)
    "Etc/GMT-2" => Some(7200)
    "Etc/GMT-3" => Some(10800)
    "Etc/GMT-4" => Some(14400)
    "Etc/GMT-5" => Some(18000)
    "Etc/GMT-6" => Some(21600)
    "Etc/GMT-7" => Some(25200)
    "Etc/GMT-8" => Some(28800)
    "Etc/GMT-9" => Some(32400)
    "Etc/GMT-10" => Some(36000)
    "Etc/GMT-11" => Some(39600)
    "Etc/GMT-12" => Some(43200)
    "Etc/GMT-13" => Some(46800)
    "Etc/GMT-14" => Some(50400)
    _ => None
  }
}

///|
let iana_sorted : FixedArray[String] = [
  "Africa/Abidjan", "Africa/Accra", "Africa/Addis_Ababa", "Africa/Algiers", "Africa/Asmara",
  "Africa/Asmera", "Africa/Bamako", "Africa/Bangui", "Africa/Banjul", "Africa/Bissau",
  "Africa/Blantyre", "Africa/Brazzaville", "Africa/Bujumbura", "Africa/Cairo", "Africa/Casablanca",
  "Africa/Ceuta", "Africa/Conakry", "Africa/Dakar", "Africa/Dar_es_Salaam", "Africa/Djibouti",
  "Africa/Douala", "Africa/El_Aaiun", "Africa/Freetown", "Africa/Gaborone", "Africa/Harare",
  "Africa/Johannesburg", "Africa/Juba", "Africa/Kampala", "Africa/Khartoum", "Africa/Kigali",
  "Africa/Kinshasa", "Africa/Lagos", "Africa/Libreville", "Africa/Lome", "Africa/Luanda",
  "Africa/Lubumbashi", "Africa/Lusaka", "Africa/Malabo", "Africa/Maputo", "Africa/Maseru",
  "Africa/Mbabane", "Africa/Mogadishu", "Africa/Monrovia", "Africa/Nairobi", "Africa/Ndjamena",
  "Africa/Niamey", "Africa/Nouakchott", "Africa/Ouagadougou", "Africa/Porto-Novo",
  "Africa/Sao_Tome", "Africa/Timbuktu", "Africa/Tripoli", "Africa/Tunis", "Africa/Windhoek",
  "America/Adak", "America/Anchorage", "America/Anguilla", "America/Antigua", "America/Araguaina",
  "America/Argentina/Buenos_Aires", "America/Argentina/Catamarca", "America/Argentina/ComodRivadavia",
  "America/Argentina/Cordoba", "America/Argentina/Jujuy", "America/Argentina/La_Rioja",
  "America/Argentina/Mendoza", "America/Argentina/Rio_Gallegos", "America/Argentina/Salta",
  "America/Argentina/San_Juan", "America/Argentina/San_Luis", "America/Argentina/Tucuman",
  "America/Argentina/Ushuaia", "America/Aruba", "America/Asuncion", "America/Atikokan",
  "America/Atka", "America/Bahia", "America/Bahia_Banderas", "America/Barbados",
  "America/Belem", "America/Belize", "America/Blanc-Sablon", "America/Boa_Vista",
  "America/Bogota", "America/Boise", "America/Buenos_Aires", "America/Cambridge_Bay",
  "America/Campo_Grande", "America/Cancun", "America/Caracas", "America/Catamarca",
  "America/Cayenne", "America/Cayman", "America/Chicago", "America/Chihuahua", "America/Ciudad_Juarez",
  "America/Coral_Harbour", "America/Cordoba", "America/Costa_Rica", "America/Coyhaique",
  "America/Creston", "America/Cuiaba", "America/Curacao", "America/Danmarkshavn",
  "America/Dawson", "America/Dawson_Creek", "America/Denver", "America/Detroit",
  "America/Dominica", "America/Edmonton", "America/Eirunepe", "America/El_Salvador",
  "America/Ensenada", "America/Fort_Nelson", "America/Fort_Wayne", "America/Fortaleza",
  "America/Glace_Bay", "America/Godthab", "America/Goose_Bay", "America/Grand_Turk",
  "America/Grenada", "America/Guadeloupe", "America/Guatemala", "America/Guayaquil",
  "America/Guyana", "America/Halifax", "America/Havana", "America/Hermosillo", "America/Indiana/Indianapolis",
  "America/Indiana/Knox", "America/Indiana/Marengo", "America/Indiana/Petersburg",
  "America/Indiana/Tell_City", "America/Indiana/Vevay", "America/Indiana/Vincennes",
  "America/Indiana/Winamac", "America/Indianapolis", "America/Inuvik", "America/Iqaluit",
  "America/Jamaica", "America/Jujuy", "America/Juneau", "America/Kentucky/Louisville",
  "America/Kentucky/Monticello", "America/Knox_IN", "America/Kralendijk", "America/La_Paz",
  "America/Lima", "America/Los_Angeles", "America/Louisville", "America/Lower_Princes",
  "America/Maceio", "America/Managua", "America/Manaus", "America/Marigot", "America/Martinique",
  "America/Matamoros", "America/Mazatlan", "America/Mendoza", "America/Menominee",
  "America/Merida", "America/Metlakatla", "America/Mexico_City", "America/Miquelon",
  "America/Moncton", "America/Monterrey", "America/Montevideo", "America/Montreal",
  "America/Montserrat", "America/Nassau", "America/New_York", "America/Nipigon",
  "America/Nome", "America/Noronha", "America/North_Dakota/Beulah", "America/North_Dakota/Center",
  "America/North_Dakota/New_Salem", "America/Nuuk", "America/Ojinaga", "America/Panama",
  "America/Pangnirtung", "America/Paramaribo", "America/Phoenix", "America/Port-au-Prince",
  "America/Port_of_Spain", "America/Porto_Acre", "America/Porto_Velho", "America/Puerto_Rico",
  "America/Punta_Arenas", "America/Rainy_River", "America/Rankin_Inlet", "America/Recife",
  "America/Regina", "America/Resolute", "America/Rio_Branco", "America/Rosario",
  "America/Santa_Isabel", "America/Santarem", "America/Santiago", "America/Santo_Domingo",
  "America/Sao_Paulo", "America/Scoresbysund", "America/Shiprock", "America/Sitka",
  "America/St_Barthelemy", "America/St_Johns", "America/St_Kitts", "America/St_Lucia",
  "America/St_Thomas", "America/St_Vincent", "America/Swift_Current", "America/Tegucigalpa",
  "America/Thule", "America/Thunder_Bay", "America/Tijuana", "America/Toronto", "America/Tortola",
  "America/Vancouver", "America/Virgin", "America/Whitehorse", "America/Winnipeg",
  "America/Yakutat", "America/Yellowknife", "Antarctica/Casey", "Antarctica/Davis",
  "Antarctica/DumontDUrville", "Antarctica/Macquarie", "Antarctica/Mawson", "Antarctica/McMurdo",
  "Antarctica/Palmer", "Antarctica/Rothera", "Antarctica/South_Pole", "Antarctica/Syowa",
  "Antarctica/Troll", "Antarctica/Vostok", "Arctic/Longyearbyen", "Asia/Aden", "Asia/Almaty",
  "Asia/Amman", "Asia/Anadyr", "Asia/Aqtau", "Asia/Aqtobe", "Asia/Ashgabat", "Asia/Ashkhabad",
  "Asia/Atyrau", "Asia/Baghdad", "Asia/Bahrain", "Asia/Baku", "Asia/Bangkok", "Asia/Barnaul",
  "Asia/Beirut", "Asia/Bishkek", "Asia/Brunei", "Asia/Calcutta", "Asia/Chita", "Asia/Choibalsan",
  "Asia/Chongqing", "Asia/Chungking", "Asia/Colombo", "Asia/Dacca", "Asia/Damascus",
  "Asia/Dhaka", "Asia/Dili", "Asia/Dubai", "Asia/Dushanbe", "Asia/Famagusta", "Asia/Gaza",
  "Asia/Harbin", "Asia/Hebron", "Asia/Ho_Chi_Minh", "Asia/Hong_Kong", "Asia/Hovd",
  "Asia/Irkutsk", "Asia/Istanbul", "Asia/Jakarta", "Asia/Jayapura", "Asia/Jerusalem",
  "Asia/Kabul", "Asia/Kamchatka", "Asia/Karachi", "Asia/Kashgar", "Asia/Kathmandu",
  "Asia/Katmandu", "Asia/Khandyga", "Asia/Kolkata", "Asia/Krasnoyarsk", "Asia/Kuala_Lumpur",
  "Asia/Kuching", "Asia/Kuwait", "Asia/Macao", "Asia/Macau", "Asia/Magadan", "Asia/Makassar",
  "Asia/Manila", "Asia/Muscat", "Asia/Nicosia", "Asia/Novokuznetsk", "Asia/Novosibirsk",
  "Asia/Omsk", "Asia/Oral", "Asia/Phnom_Penh", "Asia/Pontianak", "Asia/Pyongyang",
  "Asia/Qatar", "Asia/Qostanay", "Asia/Qyzylorda", "Asia/Rangoon", "Asia/Riyadh",
  "Asia/Saigon", "Asia/Sakhalin", "Asia/Samarkand", "Asia/Seoul", "Asia/Shanghai",
  "Asia/Singapore", "Asia/Srednekolymsk", "Asia/Taipei", "Asia/Tashkent", "Asia/Tbilisi",
  "Asia/Tehran", "Asia/Tel_Aviv", "Asia/Thimbu", "Asia/Thimphu", "Asia/Tokyo", "Asia/Tomsk",
  "Asia/Ujung_Pandang", "Asia/Ulaanbaatar", "Asia/Ulan_Bator", "Asia/Urumqi", "Asia/Ust-Nera",
  "Asia/Vientiane", "Asia/Vladivostok", "Asia/Yakutsk", "Asia/Yangon", "Asia/Yekaterinburg",
  "Asia/Yerevan", "Atlantic/Azores", "Atlantic/Bermuda", "Atlantic/Canary", "Atlantic/Cape_Verde",
  "Atlantic/Faeroe", "Atlantic/Faroe", "Atlantic/Jan_Mayen", "Atlantic/Madeira",
  "Atlantic/Reykjavik", "Atlantic/South_Georgia", "Atlantic/St_Helena", "Atlantic/Stanley",
  "Australia/ACT", "Australia/Adelaide", "Australia/Brisbane", "Australia/Broken_Hill",
  "Australia/Canberra", "Australia/Currie", "Australia/Darwin", "Australia/Eucla",
  "Australia/Hobart", "Australia/LHI", "Australia/Lindeman", "Australia/Lord_Howe",
  "Australia/Melbourne", "Australia/NSW", "Australia/North", "Australia/Perth", "Australia/Queensland",
  "Australia/South", "Australia/Sydney", "Australia/Tasmania", "Australia/Victoria",
  "Australia/West", "Australia/Yancowinna", "Brazil/Acre", "Brazil/DeNoronha", "Brazil/East",
  "Brazil/West", "CET", "CST6CDT", "Canada/Atlantic", "Canada/Central", "Canada/Eastern",
  "Canada/Mountain", "Canada/Newfoundland", "Canada/Pacific", "Canada/Saskatchewan",
  "Canada/Yukon", "Chile/Continental", "Chile/EasterIsland", "Cuba", "EET", "EST",
  "EST5EDT", "Egypt", "Eire", "Etc/GMT", "Etc/GMT+0", "Etc/GMT+1", "Etc/GMT+10",
  "Etc/GMT+11", "Etc/GMT+12", "Etc/GMT+2", "Etc/GMT+3", "Etc/GMT+4", "Etc/GMT+5",
  "Etc/GMT+6", "Etc/GMT+7", "Etc/GMT+8", "Etc/GMT+9", "Etc/GMT-0", "Etc/GMT-1", "Etc/GMT-10",
  "Etc/GMT-11", "Etc/GMT-12", "Etc/GMT-13", "Etc/GMT-14", "Etc/GMT-2", "Etc/GMT-3",
  "Etc/GMT-4", "Etc/GMT-5", "Etc/GMT-6", "Etc/GMT-7", "Etc/GMT-8", "Etc/GMT-9", "Etc/GMT0",
  "Etc/Greenwich", "Etc/UCT", "Etc/UTC", "Etc/Universal", "Etc/Zulu", "Europe/Amsterdam",
  "Europe/Andorra", "Europe/Astrakhan", "Europe/Athens", "Europe/Belfast", "Europe/Belgrade",
  "Europe/Berlin", "Europe/Bratislava", "Europe/Brussels", "Europe/Bucharest", "Europe/Budapest",
  "Europe/Busingen", "Europe/Chisinau", "Europe/Copenhagen", "Europe/Dublin", "Europe/Gibraltar",
  "Europe/Guernsey", "Europe/Helsinki", "Europe/Isle_of_Man", "Europe/Istanbul",
  "Europe/Jersey", "Europe/Kaliningrad", "Europe/Kiev", "Europe/Kirov", "Europe/Kyiv",
  "Europe/Lisbon", "Europe/Ljubljana", "Europe/London", "Europe/Luxembourg", "Europe/Madrid",
  "Europe/Malta", "Europe/Mariehamn", "Europe/Minsk", "Europe/Monaco", "Europe/Moscow",
  "Europe/Nicosia", "Europe/Oslo", "Europe/Paris", "Europe/Podgorica", "Europe/Prague",
  "Europe/Riga", "Europe/Rome", "Europe/Samara", "Europe/San_Marino", "Europe/Sarajevo",
  "Europe/Saratov", "Europe/Simferopol", "Europe/Skopje", "Europe/Sofia", "Europe/Stockholm",
  "Europe/Tallinn", "Europe/Tirane", "Europe/Tiraspol", "Europe/Ulyanovsk", "Europe/Uzhgorod",
  "Europe/Vaduz", "Europe/Vatican", "Europe/Vienna", "Europe/Vilnius", "Europe/Volgograd",
  "Europe/Warsaw", "Europe/Zagreb", "Europe/Zaporozhye", "Europe/Zurich", "GB", "GB-Eire",
  "GMT", "GMT+0", "GMT-0", "GMT0", "Greenwich", "HST", "Hongkong", "Iceland", "Indian/Antananarivo",
  "Indian/Chagos", "Indian/Christmas", "Indian/Cocos", "Indian/Comoro", "Indian/Kerguelen",
  "Indian/Mahe", "Indian/Maldives", "Indian/Mauritius", "Indian/Mayotte", "Indian/Reunion",
  "Iran", "Israel", "Jamaica", "Japan", "Kwajalein", "Libya", "MET", "MST", "MST7MDT",
  "Mexico/BajaNorte", "Mexico/BajaSur", "Mexico/General", "NZ", "NZ-CHAT", "Navajo",
  "PRC", "PST8PDT", "Pacific/Apia", "Pacific/Auckland", "Pacific/Bougainville", "Pacific/Chatham",
  "Pacific/Chuuk", "Pacific/Easter", "Pacific/Efate", "Pacific/Enderbury", "Pacific/Fakaofo",
  "Pacific/Fiji", "Pacific/Funafuti", "Pacific/Galapagos", "Pacific/Gambier", "Pacific/Guadalcanal",
  "Pacific/Guam", "Pacific/Honolulu", "Pacific/Johnston", "Pacific/Kanton", "Pacific/Kiritimati",
  "Pacific/Kosrae", "Pacific/Kwajalein", "Pacific/Majuro", "Pacific/Marquesas", "Pacific/Midway",
  "Pacific/Nauru", "Pacific/Niue", "Pacific/Norfolk", "Pacific/Noumea", "Pacific/Pago_Pago",
  "Pacific/Palau", "Pacific/Pitcairn", "Pacific/Pohnpei", "Pacific/Ponape", "Pacific/Port_Moresby",
  "Pacific/Rarotonga", "Pacific/Saipan", "Pacific/Samoa", "Pacific/Tahiti", "Pacific/Tarawa",
  "Pacific/Tongatapu", "Pacific/Truk", "Pacific/Wake", "Pacific/Wallis", "Pacific/Yap",
  "Poland", "Portugal", "ROC", "ROK", "Singapore", "Turkey", "UCT", "US/Alaska",
  "US/Aleutian", "US/Arizona", "US/Central", "US/East-Indiana", "US/Eastern", "US/Hawaii",
  "US/Indiana-Starke", "US/Michigan", "US/Mountain", "US/Pacific", "US/Samoa", "UTC",
  "Universal", "W-SU", "WET", "Zulu",
]

///|
fn get_tz_abbr_at(name : String, unix_time : Int64) -> (Int, String)? {
  match get_tz_offset_at(name, unix_time) {
    Some(offset) => Some((offset, tz_name_from_offset(offset)))
    None => None
  }
}

///|
fn get_local_tz_at(_unix_time : Int64) -> (Int, String)? {
  Some((0, "UTC"))
}
