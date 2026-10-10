#!/usr/bin/env bash
# Aetherfall Android emulator QA for v0.3.2 rig, gait and visual silhouette.
set -euo pipefail
mkdir -p qa-results

# Keep logs even if a foreground check fails before the final capture.
function save_diagnostics() {
  adb logcat -d -v threadtime > qa-results/full-logcat.txt 2>/dev/null || true
  adb shell dumpsys activity activities > qa-results/activity.txt 2>/dev/null || true
}
trap save_diagnostics EXIT

function verify_foreground() {
  if ! adb shell pidof com.demetrecerrone.aetherfall >/dev/null 2>&1; then
    echo "QA_APP_EXITED: Aetherfall process is not running." | tee -a qa-results/test-summary.txt
    return 1
  fi
  if ! adb shell dumpsys activity activities | grep -Eq "topResumedActivity=.*com[.]demetrecerrone[.]aetherfall/"; then
    echo "QA_NOT_FOREGROUND: Aetherfall is not the Android foreground activity." | tee -a qa-results/test-summary.txt
    return 1
  fi
}
APK="${APK:-builds/Aetherfall-v0.3.2-emulator-x86_64-debug.apk}"
test -s "$APK"
adb wait-for-device
echo "=== Android device ===" | tee qa-results/test-summary.txt
adb shell getprop ro.build.version.release | tee -a qa-results/test-summary.txt
adb shell getprop ro.product.cpu.abi | tee -a qa-results/test-summary.txt
adb shell getprop ro.hardware | tee -a qa-results/test-summary.txt
adb install -r "$APK"

# Configure display *before* starting Godot; changing rotation during startup
# caused emulator GodotActivity destruction and a SIGKILL in an earlier run.
adb shell settings put system accelerometer_rotation 0
adb shell wm size 1600x900
adb shell wm density 240
adb shell settings put secure immersive_mode_confirmations confirmed || true
sleep 9
adb logcat -c
adb shell am force-stop com.demetrecerrone.aetherfall || true
adb shell am start -n com.demetrecerrone.aetherfall/com.godot.game.GodotAppLauncher
sleep 25
verify_foreground

function cap() {
  local name="$1"
  verify_foreground
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
adb shell input touchscreen tap 1310 690
sleep 0.35
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
adb shell input touchscreen tap 1395 420
sleep 2
cap 06_studio_hairstyle_changed
adb shell input touchscreen tap 1525 110
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
if grep -Eq 'SceneShaderGLES3: Program linking failed|Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS|QueuePresentKHR failed|Vulkan:.*Failed' qa-results/full-logcat.txt; then
  echo "QA_RENDER_FAILED: emulator shaders failed, scene is not visually testable." | tee -a qa-results/test-summary.txt
  exit 1
fi
python3 tools/verify_emulator_frames.py qa-results 2>&1 | tee -a qa-results/test-summary.txt
echo "QA_OK: game remained open and captured visible changing scenes." | tee -a qa-results/test-summary.txt
ls -lh qa-results/ | tee -a qa-results/test-summary.txt
