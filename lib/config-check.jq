# Validates kiosk.yaml (as JSON from yq). Prints one line per finding: "ERROR: ..." or "WARN: ...".
# Used by kioskctl check / apply / doctor.
def err($m): "ERROR: \($m)";
def wrn($m): "WARN: \($m)";
def is_time: type == "string" and test("^([01][0-9]|2[0-3]):[0-5][0-9]$");
def is_interval: type == "string" and test("^[0-9]+(s|m|h|min)?$");
def is_name: type == "string" and test("^[a-z0-9_-]+$");
def is_bool: type == "boolean";
def unknown($path; $allowed): if type == "object" then (keys - $allowed)[] | wrn("\($path): unknown key '\(.)'") else empty end;
def want_bool($path): if . != null and (is_bool | not) then err("\($path) must be true or false") else empty end;
def want_str($path): if . != null and type != "string" then err("\($path) must be a string") else empty end;
def want_enum($path; $vals): if . != null and (. as $v | $vals | index($v) | not) then err("\($path) must be one of \($vals | join(", "))") else empty end;
def want_interval($path): if . != null and (is_interval | not) then err("\($path) must be like 30s, 5m, 2h") else empty end;

# top level
unknown("top level"; ["device","display","touch","audio","chrome","performance","apps","network","services","schedule","security","persistence"]),
(.device | unknown("device"; ["id"])), (.device.id | want_str("device.id")),
(.display | unknown("display"; ["background","tearfree","outputs"])),
(.display.tearfree | want_bool("display.tearfree")),
(.display.outputs // [] | if type != "array" then err("display.outputs must be a list") else
    to_entries[] | .key as $i | .value |
    (unknown("display.outputs[\($i)]"; ["name","primary","mode","pos","rotate","rate","enabled","transform"])),
    (if .name == null then err("display.outputs[\($i)]: name required") else empty end),
    (.rotate | want_enum("display.outputs[\($i)].rotate"; ["normal","left","right","inverted"])),
    (.pos | if . != null and (tostring | test("^[0-9]+x[0-9]+$") | not) then err("display.outputs[\($i)].pos must be like 1920x0") else empty end),
    (.enabled | want_bool("display.outputs[\($i)].enabled")), (.primary | want_bool("display.outputs[\($i)].primary"))
  end),
(.touch | unknown("touch"; ["output"])),
(.audio | unknown("audio"; ["sink","volume"])),
(.audio.volume | if . != null and (type != "number" or . < 0 or . > 100) then err("audio.volume must be 0-100") else empty end),
(.chrome | unknown("chrome"; ["gpu","flags","extensions"])),
(.chrome.gpu | want_enum("chrome.gpu"; ["auto","software"])),
(.chrome.flags | if . != null and (type != "array" or (map(type == "string") | all | not)) then err("chrome.flags must be a list of strings") else empty end),
(.chrome.extensions // [] | if type != "array" then err("chrome.extensions must be a list") else
    to_entries[] | .key as $i | .value |
    (unknown("chrome.extensions[\($i)]"; ["name","id"])),
    (if (.name == null and .id == null) then err("chrome.extensions[\($i)]: name or id required") else empty end),
    (if .name != null and (.name | is_name | not) then err("chrome.extensions[\($i)].name must be [a-z0-9_-]") else empty end),
    (if .id != null and (.id | tostring | test("^[a-p]{32}$") | not) then err("chrome.extensions[\($i)].id must be 32 letters a-p") else empty end)
  end),
(.performance | unknown("performance"; ["gpu_min_freq","low_latency"])),
(.performance.gpu_min_freq | if . != null and (. != "auto" and . != "max" and (tostring | test("^[0-9]+$") | not)) then err("performance.gpu_min_freq must be auto, max or a number") else empty end),
(.performance.low_latency | want_bool("performance.low_latency")),
# apps
(.apps // [] | if type != "array" then err("apps must be a list") else
    (map(.name) | group_by(.) | map(select(length > 1) | .[0]) | .[] | err("apps: duplicate name '\(.)'")),
    (to_entries[] | .key as $i | .value | ("apps[\($i)]" + (if .name then " (\(.name))" else "" end)) as $p |
      (if (.name | is_name | not) then err("\($p): name required, [a-z0-9_-]") else empty end),
      (.type | if . == null then err("\($p): type required") else want_enum("\($p).type"; ["web","static","video","slideshow","launcher"]) end),
      (.geometry | if . != null and . != "fullscreen" and (tostring | test("^[0-9]+x[0-9]+\\+[0-9]+\\+[0-9]+$") | not) then err("\($p).geometry must be fullscreen or WxH+X+Y") else empty end),
      (.port | if . != null and (type != "number" or . < 1024 or . > 65535) then err("\($p).port must be 1024-65535") else empty end),
      (.update_interval | if . != null and . != 0 and (tostring | is_interval | not) then err("\($p).update_interval must be 0 or like 15m") else empty end),
      (.update_on_boot | want_bool("\($p).update_on_boot")),
      (.on_app_change | want_enum("\($p).on_app_change"; ["restart","reload","none"])),
      (.on_data_change | want_enum("\($p).on_data_change"; ["restart","reload","none"])),
      (if .type == "web" and .url == null then err("\($p): url required for type web") else empty end),
      (if .type == "static" and .path == null and .repo == null then err("\($p): path or repo required for type static") else empty end),
      (if (.type == "video" or .type == "slideshow") and .path == null then err("\($p): path required") else empty end),
      (if .type == "launcher" and .command == null then err("\($p): command required for type launcher") else empty end),
      (if .type == "static" and .data != null then
          (.data | if type != "array" then err("\($p).data must be a list") else
            (if length > 5 then err("\($p).data: at most 5 data repos") else empty end),
            (map(.name) | group_by(.) | map(select(length > 1) | .[0]) | .[] | err("\($p).data: duplicate name '\(.)'")),
            (to_entries[] | .key as $j | .value |
              (unknown("\($p).data[\($j)]"; ["name","repo","branch","subdir","url","lfs","on_change"])),
              (if (.name | is_name | not) then err("\($p).data[\($j)]: name required, [a-z0-9_-]") else empty end),
              (if .repo == null then err("\($p).data[\($j)]: repo required") else empty end),
              (.lfs | want_bool("\($p).data[\($j)].lfs")),
              (.on_change | want_enum("\($p).data[\($j)].on_change"; ["restart","reload","none"])))
          end)
        else empty end),
      (if .type != "static" and (.data != null or .data_repo != null) then wrn("\($p): data repos are only used by type static") else empty end)
    )
  end),
# network, services
(.network | unknown("network"; ["wifi"])),
(.network.wifi // [] | if type != "array" then err("network.wifi must be a list") else
    (if length > 3 then err("network.wifi: at most 3 entries") else empty end),
    (.[] | if (is_name | not) then err("network.wifi: '\(.)' must be [a-z0-9_-]") else empty end)
  end),
(.services | unknown("services"; ["tunnel","usb_action","monitoring","telegram","scheduler","health","updates"])),
(.services // {} | to_entries[] | .key as $s | .value | if type == "object" then (.enabled | want_bool("services.\($s).enabled")) else err("services.\($s) must be a map") end),
(.services.tunnel | unknown("services.tunnel"; ["enabled","host","port","user","remote_port"])),
(.services.tunnel | if .enabled == true and (.host == null or .host == "") then err("services.tunnel.host required when enabled") else empty end),
(.services.monitoring | unknown("services.monitoring"; ["enabled","url","interval"])),
(.services.monitoring | if .enabled == true and (.url == null or .url == "") then err("services.monitoring.url required when enabled") else empty end),
(.services.monitoring.interval | want_interval("services.monitoring.interval")),
(.services.telegram | unknown("services.telegram"; ["enabled","chat_id","interval","on_boot"])),
(.services.telegram | if .enabled == true and (.chat_id == null or .chat_id == "") then err("services.telegram.chat_id required when enabled") else empty end),
(.services.telegram.interval | want_interval("services.telegram.interval")),
(.services.scheduler | unknown("services.scheduler"; ["enabled","off_action"])),
(.services.scheduler.off_action | want_enum("services.scheduler.off_action"; ["screen","apps","shutdown"])),
(.services.health | unknown("services.health"; ["enabled","interval","checks","min_stddev"])),
(.services.health.interval | want_interval("services.health.interval")),
(.services.health.checks // [] | .[] | want_enum("services.health.checks"; ["window","title","http","screen"])),
(.services.updates | unknown("services.updates"; ["enabled","security_only","reboot"])),
(.services.updates.security_only | want_bool("services.updates.security_only")),
(.services.updates.reboot | if . != null and . != "" and (is_time | not) then err("services.updates.reboot must be HH:MM or empty") else empty end),
(.services.usb_action | unknown("services.usb_action"; ["enabled"])),
# schedule, security, persistence
(.schedule // {} | if type != "object" then err("schedule must be a map") else
    to_entries[] | .key as $d | 
    (if ($d | test("^(mon|tue|wed|thu|fri|sat|sun|daily)(-(mon|tue|wed|thu|fri|sat|sun))?$") | not) then err("schedule: '\($d)' is not a day, range (mon-fri) or daily") else empty end),
    (.value | unknown("schedule.\($d)"; ["on","off","true","false"])),   # PyYAML reads on/off as booleans
    (.value | .on, .off, .["true"], .["false"] | if . != null and (is_time | not) then err("schedule.\($d): times must be HH:MM") else empty end)
  end),
(if .services.scheduler.enabled == true and ((.schedule // {}) | length) == 0 then wrn("scheduler enabled but schedule is empty") else empty end),
(.security | unknown("security"; ["disable_usb_storage"])),
(.security.disable_usb_storage | want_bool("security.disable_usb_storage")),
(if .security.disable_usb_storage == true and .services.usb_action.enabled == true then err("security.disable_usb_storage and services.usb_action cannot both be on") else empty end),
(.persistence | unknown("persistence"; ["mode"])),
(.persistence.mode | want_enum("persistence.mode"; ["rw","locked","data","data+journal"]))
