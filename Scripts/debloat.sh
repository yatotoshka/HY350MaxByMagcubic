#!/usr/bin/env bash
#
# debloat.sh — скрыть/отключить известные BADBOX-компоненты HY350 Max.
#
# ВАЖНО:
#   - Это НЕ удаляет заводские копии из /product. После factory reset
#     dropper вернётся. Полное удаление — только правка образа (см. Root/).
#   - com.android.vending НЕ трогается: на проверенной сборке это настоящий
#     Play Store, подписанный Google.
#   - com.htc.magcubicos НЕ трогается: это лаунчер и настройки проектора.
#
# Использование:
#   ./debloat.sh --dry-run          # показать команды
#   ./debloat.sh --apply            # выполнить
#   ./debloat.sh --restore          # включить обратно
#
# Переменные:
#   ADB=/path/to/adb
#   SERIAL=192.168.1.50:5555

set -u

ADB="${ADB:-adb}"
if [ -n "${SERIAL:-}" ]; then
  ADB_ARGS=(-s "$SERIAL")
else
  ADB_ARGS=()
fi

DRY_RUN=0
MODE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --apply)   MODE="apply" ;;
    --restore) MODE="restore" ;;
    -h|--help)
      awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $arg" >&2
      exit 2
      ;;
  esac
done

if [ -z "$MODE" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    MODE="apply"
  else
    echo "Укажите --dry-run, --apply или --restore" >&2
    exit 2
  fi
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'adb %s shell %s\n' "${ADB_ARGS[*]}" "$*"
    return 0
  fi
  "$ADB" "${ADB_ARGS[@]}" shell "$@" || true
}

# Пакеты dropper/OTA. Добавляйте сюда только то, что проверили на своём устройстве.
TARGETS="
com.hy.storeos
com.hy.hyotaupdate
com.htc.storeos
com.htc.htcotaupdate
"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "== режим: $MODE (dry-run) =="
else
  echo "== режим: $MODE =="
fi

if [ "$MODE" = "restore" ]; then
  for pkg in $TARGETS; do
    echo "-- $pkg"
    run "pm enable --user 0 $pkg"
    run "pm install-existing --user 0 $pkg"
  done
  echo "Готово. Проверьте: adb shell pm list packages -d"
  exit 0
fi

for pkg in $TARGETS; do
  if ! "$ADB" "${ADB_ARGS[@]}" shell pm list packages 2>/dev/null | grep -q "package:$pkg$"; then
    echo "-- $pkg: не установлен, пропуск"
    continue
  fi
  echo "-- $pkg"
  # Сначала скрываем для пользователя, затем отключаем на случай, если
  # uninstall не сработал (updated system app).
  run "pm uninstall --user 0 $pkg"
  run "pm disable-user --user 0 $pkg"
done

echo
echo "Проверка:"
"$ADB" "${ADB_ARGS[@]}" shell 'pm list packages | grep -E "storeos|hyota|htc.storeos|htc.htcotaupdate"' || true
"$ADB" "${ADB_ARGS[@]}" shell 'pm list packages -d' || true
echo
echo "Напоминание: заводские копии остались в /product. Полная очистка — через образ."
