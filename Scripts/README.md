# Скрипты

← [К оглавлению](../README.md)

Скрипты намеренно простые: их можно прочитать целиком перед запуском. Ни один не содержит паролей, MAC, серийников или IP проверенного устройства. `collect_info.sh` выводит IP из `ss` — проверьте вывод перед публикацией.

## На компьютере

| Файл | Что делает | Где применяется |
| --- | --- | --- |
| [`collect_info.sh`](collect_info.sh) | собирает обезличенный отчёт по ADB | аудит, issue, сравнение сборок |
| [`debloat.sh`](debloat.sh) | скрывает/отключает известные BADBOX-пакеты | [Аудит](../AUDIT/security.md) |
| [`block_iocs.sh`](block_iocs.sh) | шаблон iptables-правил для hardcoded C2 | [Аудит](../AUDIT/security.md) |

### `collect_info.sh`

```sh
./collect_info.sh
# или
SERIAL=192.168.1.50:5555 ./collect_info.sh
```

Печатает сборку, железо, AVB/SELinux, экран, память, пакеты, слушатели и соединения. **Проверьте вывод перед публикацией**: в `ss` будут локальный IP проектора и адреса других устройств.

### `debloat.sh`

```sh
./debloat.sh --dry-run     # только показать команды
./debloat.sh --apply       # выполнить
./debloat.sh --restore     # включить пакеты обратно
```

Что делает:

- `pm uninstall --user 0` и `pm disable-user --user 0` для `com.hy.storeos`, `com.hy.hyotaupdate`, `com.htc.storeos`, `com.htc.htcotaupdate`;
- **не трогает** `com.android.vending` и `com.htc.magcubicos`;
- печатает результат и напоминает, что заводские копии остались в `/product`.

`--apply` — это временная мера. Полное удаление требует правки образа, см. [Root](../Root/README.md).

### `block_iocs.sh`

Запускать на шлюзе/роутере, а не на проекторе:

```sh
sudo ./block_iocs.sh 192.168.1.50 --apply
sudo ./block_iocs.sh 192.168.1.50 --remove
```

Читает IP из [`../iocs/ips.txt`](../iocs/ips.txt), добавляет `DROP` в `FORWARD` для трафика проектора к этим адресам. Правила не сохраняются после перезагрузки роутера; сохраните их средствами прошивки. Если у вас nftables/firewalld — адаптируйте.

## На устройстве

| Файл | Что делает | Где применяется |
| --- | --- | --- |
| [`netwatch.sh`](netwatch.sh) | пассивный лог исходящих соединений | [Аудит](../AUDIT/security.md) |

```sh
adb push netwatch.sh /data/local/tmp/
adb shell 'nohup sh /data/local/tmp/netwatch.sh >/dev/null 2>&1 &'

# посмотреть
adb shell 'tail -n 50 /data/local/tmp/netwatch.log'

# остановить
adb shell 'ps -A -o PID,ARGS | grep netwatch'
adb shell 'kill -9 <pid>'
```

Пишет в `/data/local/tmp/netwatch.log`, опрос раз в 20 секунд, не переживает перезагрузку. Без root имена процессов в `ss` могут быть пустыми — смотрите хотя бы адреса и порты.

## Чего здесь нет

- Готовых образов `update.img` и `boot0`: они привязаны к конкретной сборке и плате.
- Автоматического удаления пакетов из `/product`: для этого нужен разбор и пересборка `super`.
- Скачивания APK: ставьте приложения из доверенных источников.

## Проверка синтаксиса

```sh
bash -n collect_info.sh debloat.sh block_iocs.sh
shellcheck collect_info.sh debloat.sh block_iocs.sh
# netwatch.sh — /system/bin/sh, проверяйте на устройстве
```
