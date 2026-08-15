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
  for _ in $(seq 1 8); do
    adb shell input swipe 540 700 540 1900 220 >/dev/null
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

tap_text() {
  local wanted="$1"
  local tries=0
  while [ "$tries" -lt 12 ]; do
    dump_ui
    local coords
    if coords=$(find_text_coords "$wanted"); then
      adb shell input tap $coords
      sleep 1
      return 0
    fi
    adb shell input swipe 540 1800 540 700 300 >/dev/null
    sleep 1
    tries=$((tries+1))
  done
  echo "Could not find/tap text: $wanted" >&2
  cp /tmp/window.xml "/tmp/gapguard-window-failure.xml" || true
  return 1
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

# Verify the first actionable control rather than relying on a decorative title in the accessibility tree.
scroll_to_top
dump_ui
cp /tmp/window.xml /tmp/gapguard-window-initial.xml
grep -q 'text="Restwert übernehmen"' /tmp/window.xml

# Ensure default threshold values are actual EditText values, not merely hints.
for wanted in 850 250; do
  found=0
  for _ in $(seq 1 12); do
    dump_ui
    if grep -q "text=\"$wanted\"" /tmp/window.xml; then
      found=1
      break
    fi
    adb shell input swipe 540 1800 540 700 300 >/dev/null
    sleep 1
  done
  test "$found" -eq 1
done

echo 'PASS: default warning thresholds rendered as real values'

# Calibrate at zero and start the user-controlled foreground service.
scroll_to_top
tap_first_edit
adb shell input text 0
adb shell input keyevent KEYCODE_BACK
sleep 1
tap_text 'Restwert übernehmen'
tap_text 'Tracking starten'
sleep 3

adb shell dumpsys activity services "$PKG" | tee /tmp/gapguard-services.txt
grep -q 'TrackerService' /tmp/gapguard-services.txt

# Capture state. Android emulators may not expose a mobile radio counter; that branch is recorded, not faked.
adb shell run-as "$PKG" cat files/events.csv 2>/dev/null | tr -d '\r' | tee /tmp/gapguard-runtime-events.csv || true
adb shell run-as "$PKG" cat shared_prefs/gap_guard_state.xml | tr -d '\r' | tee /tmp/gapguard-runtime-prefs.xml
grep -q 'name="tracker_running" value="true"' /tmp/gapguard-runtime-prefs.xml

if grep -q 'estimated_depleted' /tmp/gapguard-runtime-events.csv; then
  echo 'RUNTIME_MOBILE_COUNTER=available' | tee /tmp/gapguard-runtime-capability.txt
  tap_text '+1 GB wurde erfolgreich gebucht'
  tap_text 'Ja, erfolgreich'
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

# Recalibration while tracking must preserve the running-state flag.
scroll_to_top
tap_text 'Restwert übernehmen'
sleep 1
adb shell run-as "$PKG" cat shared_prefs/gap_guard_state.xml | tr -d '\r' | tee /tmp/gapguard-runtime-prefs-after-recal.xml
grep -q 'name="tracker_running" value="true"' /tmp/gapguard-runtime-prefs-after-recal.xml

echo 'PASS: Android emulator install/start/UI/service/state smoke test'
