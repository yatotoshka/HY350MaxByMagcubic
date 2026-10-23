#!/usr/bin/env bash
#
# collect_info.sh — собрать обезличенную информацию о HY350 Max по ADB.
#
# Использование:
#   ./collect_info.sh                    # adb из PATH
#   ADB=/path/to/adb ./collect_info.sh
#   SERIAL=192.168.1.50:5555 ./collect_info.sh
#
# Скрипт не печатает серийный номер и MAC и не читает /data.
# В выводе ss будут IP-адреса (локальный и пиры) — проверьте его перед
# публикацией.

set -u

ADB="${ADB:-adb}"
if [ -n "${SERIAL:-}" ]; then
  ADB_ARGS=(-s "$SERIAL")
else
  ADB_ARGS=()
fi

run() {
  "$ADB" "${ADB_ARGS[@]}" shell "$@" 2>/dev/null || true
}

section() {
  printf '\n===== %s =====\n' "$1"
}

section "build"
run 'getprop ro.build.flavor; getprop ro.build.product; getprop ro.product.firmware'
run 'getprop ro.build.version.release; getprop ro.build.version.sdk; getprop ro.build.id'
run 'getprop ro.build.date; getprop ro.build.description'

section "hardware"
run 'getprop ro.boot.hardware; getprop ro.hardware; getprop ro.sys.cputype'
run 'getprop ro.boot.dramsize; getprop ro.boot.dramfreq; getprop ro.product.cpu.abilist'
run 'uname -a'
run 'cat /proc/device-tree/compatible | tr "\0" "\n"'

section "boot / avb / selinux"
run 'getprop ro.boot.verifiedbootstate; getprop ro.boot.flash.locked; getprop ro.boot.veritymode; getprop ro.boot.selinux'
run 'getenforce'

section "display / storage"
run 'wm size; wm density'
run 'df -h /data / 2>/dev/null'
run 'free -m'

section "packages (vendor / suspicious)"
run 'pm list packages -f | grep -Ei "storeos|hyota|htc|hotack|vending|tubesky|magcubic|screensaver|toofifi|mphotool"'

section "packages (third-party)"
run 'pm list packages -3'

section "packages (disabled)"
run 'pm list packages -d'

section "package details"
run 'dumpsys package com.hy.storeos | grep -E "appId=|sharedUser=|codePath=|versionName=|versionCode=|flags=|signatures=" | head -20'
run 'dumpsys package com.hy.hyotaupdate | grep -E "appId=|sharedUser=|codePath=|versionName=|versionCode=|flags=|signatures=" | head -20'
run 'dumpsys package com.android.vending | grep -A20 "Package \\[com.android.vending\\]" | head -25'

section "listeners"
run 'ss -tunlp'

section "connections"
run 'ss -tunp'

section "props (selected, no identifiers)"
run 'getprop | grep -Ei "persist.sys.(defappstore|storechannel|homePackage|settings_package)|ro.boot.slot_suffix|ro.boot.dynamic_partitions"'

printf '\nГотово. Проверьте вывод перед публикацией.\n'
