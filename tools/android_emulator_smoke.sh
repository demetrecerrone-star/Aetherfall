#!/usr/bin/env bash
# Aetherfall Android emulator QA. Runs inside reactivecircus/android-emulator-runner.
set -euo pipefail
mkdir -p qa-results
APK="${APK:-builds/Aetherfall-v0.3-emulator-x86_64-debug.apk}"
test -s "$APK"
adb wait-for-device
echo "=== Android device ===" | tee qa-results/test-summary.txt
adb shell getprop ro.build.version.release | tee -a qa-results/test-summary.txt
adb shell getprop ro.product.cpu.abi | tee -a qa-results/test-summary.txt
adb shell getprop ro.hardware | tee -a qa-results/test-summary.txt
adb install -r "$APK"

# Force consistent landscape 1600x900 frame geometry for reproducible touches.
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
adb shell wm size 1600x900
adb shell wm density 240
adb shell input keyevent KEYCODE_HOME
adb logcat -c
adb shell monkey -p com.demetrecerrone.aetherfall -c android.intent.category.LAUNCHER 1
sleep 12

function cap() {
  local name="$1"
  adb exec-out screencap -p > "qa-results/$name.png"
  test -s "qa-results/$name.png"
  echo "captured $name" | tee -a qa-results/test-summary.txt
}
cap 01_first_launch

# Record Aetherfall while holding the left virtual joystick forward.
# The joystick is anchored bottom-left; dragging up means walking away from camera.
adb shell screenrecord --size 1280x720 --bit-rate 2600000 --time-limit 19 /sdcard/aetherfall_movement.mp4 >/dev/null 2>&1 &
RECORD_PID=$!
sleep 2
adb shell input touchscreen swipe 130 770 130 665 3600
cap 02_after_walk
adb shell input touchscreen tap 1430 690
sleep 2
cap 03_jump
# Capture camera orbit (right half of the display).
adb shell input touchscreen swipe 1130 355 1400 365 1750
sleep 1
cap 04_rotated_camera
wait "$RECORD_PID" || true
adb pull /sdcard/aetherfall_movement.mp4 qa-results/aetherfall_movement.mp4 || true

# Character Studio: positioned right, character visible left.
adb shell input touchscreen tap 1380 85
sleep 3
cap 05_studio_open
# Cycle a hairstyle with the right arrow, then compare screenshots.
adb shell input touchscreen tap 1340 310
sleep 2
cap 06_studio_hairstyle_changed
adb shell input touchscreen tap 1480 91
sleep 1
cap 07_studio_closed

adb shell dumpsys activity activities > qa-results/activity.txt || true
adb shell dumpsys meminfo com.demetrecerrone.aetherfall > qa-results/memory.txt || true
adb logcat -d -v threadtime > qa-results/full-logcat.txt || true
grep -Ei 'FATAL EXCEPTION|signal 11|SIGSEGV|org\.godotengine.*(error|fail)|Godot.*(ERROR|SCRIPT ERROR|invalid)' qa-results/full-logcat.txt > qa-results/potential-errors.txt || true
if ! adb shell pidof com.demetrecerrone.aetherfall >/dev/null; then
  echo "QA_FAILED: game process is no longer running." | tee -a qa-results/test-summary.txt
  exit 1
fi
echo "QA_OK: Android emulator game process survived movement/jump/studio smoke test." | tee -a qa-results/test-summary.txt
ls -lh qa-results/ | tee -a qa-results/test-summary.txt
