# ADB и доступ к устройству

← [К оглавлению](../README.md)

Это отправная точка. Без ADB нельзя проверить пакеты, подписи, порты и состояние загрузчика. Root для аудита не нужен.

## Сначала убедитесь, что у вас H726

`getprop` на HY350 Max врёт: `ro.product.model=rk3566_rgo`, `ro.board.platform=hermes`, фингерпринт от Rockchip. Не определяйте процессор по этим строкам.

Проверки, которым можно верить:

```sh
adb shell getprop ro.boot.hardware          # sun50iw15p1
adb shell getprop ro.build.flavor           # h726_p1-user
adb shell getprop ro.build.product          # h726-p1
adb shell getprop ro.product.firmware       # H726-android14-v1.0
adb shell getprop ro.sys.cputype            # QuadCore-H726
adb shell cat /proc/device-tree/compatible   # allwinner,h726, arm,sun50iw15p1
adb shell uname -a                           # 5.15.167 ... armv7l
```

Плата `h726_p1` — это HY350 Max. Плата `h726_p2` — HY300 Max / HY300 Pro. **Прошивки между ними несовместимы.**

## Включение отладки

На проекторе:

1. Настройки → Система → О устройстве.
2. Семь раз нажать на «Номер сборки» (`Projector_...`).
3. Вернуться в Настройки → Система → Для разработчиков.
4. Включить «Отладка по USB» и «Отладка по беспроводной сети».

Для USB-кабеля нужен кабель USB-A ↔ USB-A (или OTG-переходник, если порт работает как устройство). При первом подключении на экране появится запрос авторизации RSA — примите его.

```sh
adb devices -l
# 192.168.1.50:5555  device  product:rk3566_rgo model:rk3566_rgo ...
```

Если устройство в состоянии `unauthorized`, а диалог не появляется — см. раздел [«Если авторизация зависает»](#если-авторизация-зависает).

## ADB по Wi-Fi (штатный pairing)

Начиная с Android 11 используется не `adb tcpip 5555`, а штатная отладка по Wi-Fi с pairing-кодом. На проверенной сборке HY350 Max этот способ работает.

На проекторе: «Отладка по беспроводной сети» → «Сопряжение с устройством». Появятся `IP:порт` и 6-значный код.

На компьютере:

```sh
adb pair 192.168.1.50:<pair_port> <код>
# Successfully paired to 192.168.1.50:<pair_port> [guid=adb-...]

adb mdns services
# _adb-tls-connect._tcp  192.168.1.50:5555

adb connect 192.168.1.50:5555
adb devices -l
```

Порт сопряжения и порт подключения — **разные**. Порт pairing обычно случайный, а порт `adb connect` часто `:5555`. Если `adb mdns services` ничего не показывает, посмотрите порт на экране «Отладка по беспроводной сети» или попробуйте `:5555`.

После pairing компьютер сохраняет ключ. При смене компьютера pairing нужно пройти заново.

> На проверенном экземпляре pairing прошёл сразу, а `adb connect :5555` поднялся без запроса подтверждения. Это не гарантирует того же на другой ревизии.

## ADB по сети без pairing

Классический способ:

```sh
adb tcpip 5555
adb connect 192.168.1.50:5555
```

`adb tcpip` перезапускает `adbd` и может разорвать USB-канал. Если в этот момент у проектора нет сети, вы потеряете оба транспорта. Сначала убедитесь, что Wi-Fi работает, и держите под рукой пульт/мышь.

Для постоянного порта (требуется root или правка прошивки):

```sh
setprop persist.adb.tcp.port 5555
```

Но на стоковой сборке `ro.adb.secure=1` и `ro.debuggable=0`, поэтому рассчитывать на это без правки `build.prop` не стоит.

## Если авторизация зависает

Публичный отчёт по HY350 Max описывает ревизию, где `adbd` слушает `:5555`, TCP-соединение устанавливается, но диалог авторизации подавлен и handshake висит. Штатный pairing там не помогал. Решение автора — правка образа:

```properties
ro.secure=0
ro.adb.secure=0
ro.debuggable=1
service.adb.tcp.port=5555
persist.adb.tcp.port=5555
```

в `/system/build.prop` внутри `system_a.img`.

**Это серьёзное ослабление безопасности.** Такой проектор пускает любого в LAN в root-ADB без пароля. Делайте это только в изолированном VLAN и никогда не распространяйте такой образ.

На проверенной сборке `Projector_20260821.111618` этого не потребовалось: работала штатная отладка по Wi-Fi. Если у вас другая сборка, сначала попробуйте pairing, потом USB, и только потом правку образа.

## Полезные команды аудита

```sh
# пакеты и пути
adb shell pm list packages -f
adb shell pm list packages -3
adb shell pm list packages -d

# подробности пакета, UID, подпись, права
adb shell dumpsys package com.hy.storeos
adb shell dumpsys package com.hy.hyotaupdate
adb shell dumpsys package com.android.vending

# кто слушает порты
adb shell ss -tunlp

# активные соединения
adb shell ss -tunp

# свойства, экран, память
adb shell getprop
adb shell wm size
adb shell free -m
adb shell df -h

# SELinux и AVB
adb shell getenforce
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.veritymode
```

## Отключите OTA до начала работ

На HY350 Max OTA-пакет называется `com.hy.hyotaupdate` и работает под `android.uid.system`. Он может вернуть стоковые компоненты и сбросить изменения:

```sh
adb shell pm disable-user --user 0 com.hy.hyotaupdate
```

Проверка:

```sh
adb shell pm list packages -d
```

Побочный эффект: перестанут приходить штатные обновления. Для устройства с заводским BADBOX это скорее плюс, но решайте сами.

## Гигиена

- Не оставляйте `:5555` открытым в основной сети без необходимости.
- После работ выключите «Отладку по беспроводной сети».
- Не публикуйте серийный номер, MAC и реальный LAN-IP.
- Если ADB не нужен постоянно, используйте его только с изолированного компьютера/VLAN.

---

Дальше: [Аудит BADBOX 2.0](../AUDIT/security.md)
