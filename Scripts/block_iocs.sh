#!/usr/bin/env bash
#
# block_iocs.sh — шаблон блокировки hardcoded C2 IP на Linux-шлюзе.
#
# Запускать на роутере/шлюзе, через который ходит проектор, от root.
# Замените цепочку FORWARD, если у вас другая схема (например, nftables).
#
# Использование:
#   sudo ./block_iocs.sh 192.168.1.50 --apply
#   sudo ./block_iocs.sh 192.168.1.50 --remove
#
# IP-адреса читаются из ../iocs/ips.txt.
# Это дополнение к DNS-блокировке, а не замена ей: домены и IP нужно
# блокировать одновременно.

set -eu

PROJ="${1:-}"
ACTION="${2:-}"

if [ -z "$PROJ" ] || [ -z "$ACTION" ]; then
  echo "Использование: $0 <ip-проектора> --apply|--remove" >&2
  exit 2
fi

case "$ACTION" in
  --apply|--remove) ;;
  *) echo "Второй аргумент: --apply или --remove" >&2; exit 2 ;;
esac

if ! command -v iptables >/dev/null 2>&1; then
  echo "iptables не найден. Адаптируйте скрипт под nftables/firewalld." >&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
IPS_FILE="$SCRIPT_DIR/../iocs/ips.txt"

if [ ! -r "$IPS_FILE" ]; then
  echo "Не найден $IPS_FILE" >&2
  exit 1
fi

# Берём только первый столбец, отбрасываем комментарии и пустые строки.
mapfile -t IPS < <(awk '!/^[[:space:]]*#/ && NF {print $1}' "$IPS_FILE")

if [ "${#IPS[@]}" -eq 0 ]; then
  echo "В $IPS_FILE нет IP" >&2
  exit 1
fi

for ip in "${IPS[@]}"; do
  if [ "$ACTION" = "--apply" ]; then
    # -C проверяет, нет ли уже правила, чтобы не плодить дубликаты.
    if iptables -C FORWARD -s "$PROJ" -d "$ip" -j DROP 2>/dev/null; then
      echo "уже заблокирован: $ip"
    else
      iptables -I FORWARD -s "$PROJ" -d "$ip" -j DROP
      echo "заблокирован: $ip"
    fi
  else
    while iptables -C FORWARD -s "$PROJ" -d "$ip" -j DROP 2>/dev/null; do
      iptables -D FORWARD -s "$PROJ" -d "$ip" -j DROP
      echo "разблокирован: $ip"
    done
  fi
done

echo
echo "Текущие правила для $PROJ:"
iptables -S FORWARD | grep -- "$PROJ" || true
echo
echo "Правила iptables не сохраняются после перезагрузки роутера."
echo "Сохраните их средствами вашей прошивки (iptables-save/uci/firewall)."
