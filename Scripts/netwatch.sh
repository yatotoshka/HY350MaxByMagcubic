#!/system/bin/sh
#
# netwatch.sh — пассивный лог исходящих соединений на устройстве.
#
# Запуск:
#   adb push netwatch.sh /data/local/tmp/
#   adb shell 'nohup sh /data/local/tmp/netwatch.sh >/dev/null 2>&1 &'
#
# Лог: /data/local/tmp/netwatch.log
# Остановка:
#   adb shell 'ps -A -o PID,ARGS | grep netwatch'
#   adb shell 'kill -9 <pid>'
#
# Скрипт не требует root, но без root имена процессов в ss могут быть пустыми.
# Рост лога — примерно 1–2 КБ на замер; при интервале 20 с это десятки МБ
# за неделю. Следите за свободным местом.

LOG="${LOG:-/data/local/tmp/netwatch.log}"
INTERVAL="${INTERVAL:-20}"

echo "# netwatch started $(date) interval=${INTERVAL}s" >> "$LOG"

while true; do
  {
    echo "== $(date '+%Y-%m-%d %H:%M:%S') =="
    # Отбрасываем loopback, заголовок и пустые строки.
    ss -tunp 2>/dev/null | awk 'NR>1 && $0 !~ /127\.0\.0\.1|\[::1\]|0\.0\.0\.0:5353|\[::\]:5353/'
  } >> "$LOG" 2>&1
  sleep "$INTERVAL"
done
