#!/usr/bin/env bash
set -euo pipefail

APK=/tmp/gapguard-src/GapGuardAndroid/app/build/outputs/apk/debug/app-debug.apk
PKG=de.bentropie.gapguard

adb install -r "$APK"
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS || true
adb shell am force-stop "$PKG" || true
adb shell am start -W -n "$PKG/.MainActivity" | tee /tmp/gapguard-am-start.txt
grep -q 'Status: ok' /tmp/gapguard-am-start.txt
sleep 2
test -n "$(adb shell pidof "$PKG" | tr -d '\r')"

dump_ui() {
  adb shell uiautomator dump /sdcard/window.xml >/dev/null
  adb pull /sdcard/window.xml /tmp/window.xml >/dev/null
}

scroll_to_top() {
  for _ in $(seq 1 10); do
    adb shell input swipe 540 700 540 1900 180 >/dev/null
  done
  sleep 1
}

find_text_coords() {
  local wanted="$1"
  python3 - "$wanted" <<'PY'
import re, sys, xml.etree.ElementTree as ET
wanted=sys.argv[1]
root=ET.parse('/tmp/window.xml').getroot()
for n in root.iter('node'):
    if n.attrib.get('text') == wanted:
        m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.attrib.get('bounds',''))
        if m:
            x1,y1,x2,y2=map(int,m.groups())
            if x2>x1 and y2>y1 and y2>0:
                print((x1+x2)//2, (y1+y2)//2)
                raise SystemExit(0)
raise SystemExit(1)
PY
}

ensure_text_visible() {
  local wanted="$1"
  local tries=0
  while [ "$tries" -lt 14 ]; do
    dump_ui
    if find_text_coords "$wanted" >/dev/null 2>&1; then
      return 0
    fi
    adb shell input swipe 540 1800 540 700 260 >/dev/null
    sleep 1
    tries=$((tries+1))
  done
  echo "Could not find visible text: $wanted" >&2
  cp /tmp/window.xml /tmp/gapguard-window-failure.xml || true
  return 1
}

tap_text() {
  local wanted="$1"
  ensure_text_visible "$wanted"
  dump_ui
  local coords
  coords=$(find_text_coords "$wanted")
  adb shell input tap $coords
  sleep 1
}

tap_first_edit() {
  dump_ui
  local coords
  coords=$(python3 <<'PY'
import re, xml.etree.ElementTree as ET
root=ET.parse('/tmp/window.xml').getroot()
for n in root.iter('node'):
    if n.attrib.get('class') == 'android.widget.EditText':
        m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.attrib.get('bounds',''))
        if m:
            x1,y1,x2,y2=map(int,m.groups())
            if x2>x1 and y2>y1 and y2>0:
                print((x1+x2)//2, (y1+y2)//2)
                raise SystemExit(0)
raise SystemExit(1)
PY
)
  adb shell input tap $coords
  sleep 1
}

tap_dialog_positive() {
  dump_ui
  cp /tmp/window.xml /tmp/gapguard-booking-dialog.xml
  local coords
  coords=$(python3 <<'PY'
import re, xml.etree.ElementTree as ET
root=ET.parse('/tmp/window.xml').getroot()
buttons=[]
for n in root.iter('node'):
    if n.attrib.get('class') == 'android.widget.Button' and n.attrib.get('clickable') == 'true':
        m=re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.attrib.get('bounds',''))
        if m:
            x1,y1,x2,y2=map(int,m.groups())
            if x2>x1 and y2>y1:
                buttons.append(((x1+x2)//2,(y1+y2)//2,n.attrib.get('text','')))
if not buttons:
    raise SystemExit('No clickable dialog buttons found')
# Android AlertDialog places the positive action at the right edge in LTR layouts.
x,y,text=max(buttons, key=lambda b:b[0])
print(x,y)
PY
)
  adb shell input tap $coords
  sleep 1
}

# Cold start succeeded above. Find the calibration section inside the scrollable UI.
scroll_to_top
ensure_text_visible 'Restwert übernehmen'
dump_ui
cp /tmp/window.xml /tmp/gapguard-window-calibration.xml

# Calibrate at zero and start the user-controlled foreground service.
tap_first_edit
adb shell input keyevent KEYCODE_MOVE_END >/dev/null || true
adb shell input text 0
adb shell input keyevent KEYCODE_BACK
sleep 1
tap_text 'Restwert übernehmen'
tap_text 'Tracking starten'
sleep 3

adb shell dumpsys activity services "$PKG" | tee /tmp/gapguard-services.txt
grep -q 'TrackerService' /tmp/gapguard-services.txt

adb shell run-as "$PKG" cat shared_prefs/gap_guard_state.xml | tr -d '\r' | tee /tmp/gapguard-runtime-prefs.xml
grep -q 'name="calibrated" value="true"' /tmp/gapguard-runtime-prefs.xml
grep -q 'name="tracker_running" value="true"' /tmp/gapguard-runtime-prefs.xml

# Ensure default warning thresholds are actual EditText values, not mere hints.
ensure_text_visible '850'
ensure_text_visible '250'
echo 'PASS: default warning thresholds rendered as real values'

# Capture runtime events. Emulators may not expose a mobile-radio counter; record that honestly.
adb shell run-as "$PKG" cat files/events.csv 2>/dev/null | tr -d '\r' | tee /tmp/gapguard-runtime-events.csv || true
if grep -q 'estimated_depleted' /tmp/gapguard-runtime-events.csv; then
  echo 'RUNTIME_MOBILE_COUNTER=available' | tee /tmp/gapguard-runtime-capability.txt

  # Exercise complete local depletion -> confirmed +1 GB transition.
  tap_text '+1 GB wurde erfolgreich gebucht'
  tap_dialog_positive
  sleep 2
  adb shell run-as "$PKG" cat files/events.csv | tr -d '\r' | tee /tmp/gapguard-runtime-events.csv
  grep -q 'booked_1gb' /tmp/gapguard-runtime-events.csv
  grep -q 'gap_seconds=' /tmp/gapguard-runtime-events.csv
  adb shell run-as "$PKG" cat shared_prefs/gap_guard_state.xml | tr -d '\r' | tee /tmp/gapguard-runtime-prefs.xml
  grep -q 'name="booked_bytes" value="1000000000"' /tmp/gapguard-runtime-prefs.xml
  grep -q 'name="used_bytes" value="0"' /tmp/gapguard-runtime-prefs.xml
else
  echo 'RUNTIME_MOBILE_COUNTER=unavailable_on_emulator' | tee /tmp/gapguard-runtime-capability.txt
fi

# Recalibration while tracking must preserve the service-running state.
scroll_to_top
tap_text 'Restwert übernehmen'
sleep 1
adb shell run-as "$PKG" cat shared_prefs/gap_guard_state.xml | tr -d '\r' | tee /tmp/gapguard-runtime-prefs-after-recal.xml
grep -q 'name="tracker_running" value="true"' /tmp/gapguard-runtime-prefs-after-recal.xml

# No fatal app process crash should have occurred during the smoke path.
test -n "$(adb shell pidof "$PKG" | tr -d '\r')"
adb logcat -d -t 500 | grep -E 'FATAL EXCEPTION|AndroidRuntime' | grep "$PKG" > /tmp/gapguard-fatal-log.txt && {
  cat /tmp/gapguard-fatal-log.txt >&2
  exit 1
} || true

echo 'PASS: Android emulator install/start/UI/service/state smoke test'
