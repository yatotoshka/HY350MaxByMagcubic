# BADBOX 2.0 и безопасность HY350 Max

← [К оглавлению](../README.md) · [Индекс аудита](README.md)

В проверенной прошивке HY350 Max обнаружен dropper, соответствующий семейству **BADBOX 2.0**: `com.hy.storeos`. На этом экземпляре у него system UID, права на установку и удаление пакетов, `BootReceiver` и канал тихой установки `appstore.hanychx.com`. Активного residential-proxy (SOAX) и представления устройства как `ADT-3` на проверенном экземпляре не наблюдалось: это данные публичных отчётов по другим ревизиям.

Главный вывод: **dropper здесь называется `com.hy.storeos`**, а не `com.htc.storeos`, как в публичном отчёте. Это то же семейство, но другие имена и другой канал OTA. Удаление только пользовательского APK проблему не решает: заводская копия лежит в `/product`, а обновление — в `/data`.

## Что именно установлено

### `com.hy.storeos` — dropper

| Параметр | Значение |
| --- | --- |
| Заводской путь | `/product/app/HY_StoreOs_QZ/HY_StoreOs_QZ.apk` |
| Текущий путь | `/data/app/~~.../com.hy.storeos-.../base.apk` |
| Тип | `UPDATED_SYSTEM_APP` (обновление системного приложения) |
| UID | 1000, `android.uid.system` |
| Версия в `/product` | `versionCode=127`, `versionName=2608201644` |
| Версия в `/data` | `versionCode=135`, `versionName=2609042030` |
| Установлено | 22.10.2026 21:35:31 (обновление после загрузки) |
| Подпись | AOSP test key: `CN=Android, O=Android, OU=Android, L=Mountain View, ST=California, C=US` |
| SHA-256 APK из `/data` | `3f0d4dfea5905b109a537d0368d8ba8da7b492c8c814f4bd78f16be3dd389876` |
| SHA-256 APK из `/product` | `859558ab8a67021ab9499def7f0d8acbb3dd0103db173eaa680dd1b4ab16a0f5` |

С `com.hy.hyotaupdate` его роднит не только UID: в `dumpsys package` у обоих одинаковый отпечаток подписи `signatures:[b4addb29]`. Это части одного вендорского OTA-контура.

Права, которые делают его опасным:

```
INSTALL_PACKAGES
DELETE_PACKAGES
MOVE_PACKAGE
WRITE_SECURE_SETTINGS
WRITE_DEVICE_CONFIG
CLEAR_APP_USER_DATA
CHANGE_COMPONENT_ENABLED_STATE
RECEIVE_BOOT_COMPLETED
REQUEST_INSTALL_PACKAGES
MANAGE_EXTERNAL_STORAGE
```

Компоненты: `MainActivity`, `PrivacyPolicyActivity`, `BootReceiver`, `StartAppService`, `ExportService`, `PublicRequestService`, `FileProvider`. Схема `market:` и настройка `persist.sys.defappstore=com.hy.storeos` делают его магазином по умолчанию.

Домены внутри APK:

- `https://appstore.hanychx.com/device/channel/check`
- `https://appstore.hanychx.com/device/sign/app/list`
- `https://appstore.hanychx.com/device/sign/app/update/check`
- `https://appstore.hanychx.com/device/app/install/report`
- `https://ota.hanychx.com/api/ota/check`
- `http://faq.hanychx.com/static/privacy_policy/...`

Именно `appstore.hanychx.com` — канал тихой установки, а `ota.hanychx.com` — канал возврата после сброса.

### `com.hy.hyotaupdate` — OTA

| Параметр | Значение |
| --- | --- |
| Путь | `/product/app/HY_OtaUpdate_QZ/HY_OtaUpdate_QZ.apk` |
| UID | 1000, `android.uid.system` |
| Версия | `versionCode=10`, `versionName=2608191543` |
| Подпись | AOSP test key |
| Домены | `https://ota.hanychx.com/api/ota/check`, `https://ota.hanychx.com/api/ota/upgradeResult` |

Пакет умеет `RECEIVE_BOOT_COMPLETED`, `RECOVERY`, `RESTART_PACKAGES`, `SYSTEM_ALERT_WINDOW` и имеет сервисы `DownloadService`, `ReBootService`, `UpgradeStateService`, `UpgradeRemindService`. Это не «безобидный апдейтер», а механизм закрепления.

### `com.android.vending` / Tubesky — проверяйте подпись

| Параметр | Значение |
| --- | --- |
| Путь | `/product/priv-app/Tubesky/Tubesky.apk` |
| Пакет | `com.android.vending` |
| Версия | `34.1.09-23 [8] [PR] 501915548` |
| Подпись на проверенном экземпляре | **Google Inc.** (`O=Google Inc., OU=Android, CN=Android`) |
| GMS | `com.google.android.gms` присутствует |

Публичный отчёт по другой ревизии называет Tubesky «фейковым Play Store». На сборке `Projector_20260821.111618` APK подписан ключом Google и выглядит как настоящий Play Store. **Не удаляйте `com.android.vending` вслепую.** Сначала проверьте сертификат:

```sh
adb shell pm path com.android.vending
adb pull /product/priv-app/Tubesky/Tubesky.apk
unzip -p Tubesky.apk META-INF/CERT.RSA > cert.rsa
openssl pkcs7 -inform DER -in cert.rsa -print_certs -noout
```

Если в сертификате `O=Google Inc.` — это Play Store. Если `O=Android` (AOSP test key) или неизвестный субъект — перед вами подделка, и её можно удалять.

### Что не трогать

`com.htc.magcubicos` (`/product/app/HY_MagcubicOS`, uid 1000) — вендорский лаунчер и все настройки проектора:

- `activity.settings.CorrectionActivity` — keystone;
- `activity.settings.ProjectActivity` — режим проецирования;
- `activity.settings.InitAngleActivity`;
- `activity.settings.MainSettingActivity`.

Удаление ломает настройку изображения и домашний экран. Внутри APK встречаются строки `appstore.hanychx.com`, `hmma.baidu.com`, `dxp.baidu.com` — это телеметрия, но сам лаунчер не является dropper. Оставьте его, а домены блокируйте на DNS.

### `hotacksu`

`/system/xbin/hotacksu` — setuid-root бинарник, названный в честь того же вендора, что и `com.hotack.*` в публичных отчётах.

```sh
adb shell ls -lZ /system/xbin/hotacksu
# -rwsr-sr-x 1 root shell u:object_r:system_file:s0 ...
```

На проверенной сборке вызов из shell:

```sh
adb shell hotacksu 0 id
# hotacksu: setgid failed: Operation not permitted
```

Публичный отчёт утверждает, что на другой ревизии `hotacksu 0 id` из shell даёт root. На этой сборке прямой вызов не сработал, но бинарник остаётся в системе и SELinux здесь `Permissive`. Считайте это задней дверью, даже если конкретный вызов у вас не проходит.

### Пакеты, которые встречаются только строками

В публичном отчёте перечислены `com.htc.expandsdk`, `com.htc.eventuploadservice`, `com.hotack.writesn`, `com.hotack.silentsdk`, `com.htc.htclauncherhighenglishd08`. На проверенном экземпляре их APK не найдено. Если они есть у вас — удаляйте.

## Проверка своего устройства

```sh
# 1. Пакеты и пути
adb shell pm list packages -f | grep -Ei 'storeos|hyota|htc|hotack|vending|tubesky|magcubic|screensaver'

# 2. UID, подпись, права
adb shell dumpsys package com.hy.storeos | head -120
adb shell dumpsys package com.hy.hyotaupdate | head -100
adb shell dumpsys package com.android.vending | grep -A30 'Package \[com.android.vending\]'

# 3. Заводские копии
adb shell ls -l /product/app/HY_StoreOs_QZ /product/app/HY_OtaUpdate_QZ /product/priv-app/Tubesky

# 4. Слушатели
adb shell ss -tunlp

# 5. Что само ходит в сеть
adb shell ss -tunp
```

Признаки заражения именно этого варианта:

- `com.hy.storeos` с `sharedUser=android.uid.system` и `UPDATED_SYSTEM_APP`;
- `versionName` вида `2609...`, установленная дата позже даты сборки;
- `persist.sys.defappstore=com.hy.storeos`;
- запросы к `*.hanychx.com`;
- `com.hy.hyotaupdate` с `RECOVERY`.

## IOC

### Домены

Подтверждённые на этом устройстве:

```
hanychx.com
appstore.hanychx.com
ota.hanychx.com
faq.hanychx.com
```

Публичные IOC по HY350 Max / BADBOX 2.0 (не подтверждены на этом экземпляре):

```
api.pixelpioneerss.com
sta.smartinnovate.net
bur.thedynamicleap.com
kkoip.com
soax.com
event-api.aodintech.com
pb-api.aodintech.com
store-api.aodintech.com
cdn-store.aodintech.com
ota.triplesai.com
otaapi.triplesai.com
ota-api.aodintech.com
shortx.srafx.com
hotack.com
int.vaicore.site
int.dewrain.life
int.akisinn.info
```

Телеметрия и аналитика (блокировать по желанию, это не C2):

```
statsigapi.net
app-measurement.com
hmma.baidu.com
dxp.baidu.com
```

Кандидаты из публичных отчётов, не проанализированы:

```
ip4exordir.shop
zeromedia.cloud
zeasn.tv
```

На проверенном экземпляре подтверждены только домены `*.hanychx.com`. Полные списки — в [iocs/](../iocs/).

### IP

```
8.218.163.124      # appstore.hanychx.com
47.86.211.252      # ota.hanychx.com / faq.hanychx.com
47.96.145.84       # hanychx.com
139.199.190.220    # OTA fallback (Tencent Cloud)
128.12.122.35      # C2 geolocation
103.124.165.222    # hardcoded C2
64.32.27.247       # api.pixelpioneerss.com
```

IP могут меняться. Блокируйте и домены, и-hardcoded IP: DNS-фильтр не поймает обращение по IP.

### Функциональные домены, которые нельзя блокировать навсегда

`server.mphotool.com` нужен для активации AirPlay/DLNA после прошивки. Разрешите его на ~30 секунд, дождитесь активации, затем можете блокировать. Если заблокировать до активации, приёмники останутся выключенными, а в logcat будет `ProcActive: getActivated() isActived=0`.

## Удаление

### Вариант 1. Быстро, через ADB (неполное)

```sh
# Скрыть dropper для пользователя 0
adb shell pm uninstall --user 0 com.hy.storeos

# Отключить OTA, чтобы не вернул
adb shell pm disable-user --user 0 com.hy.hyotaupdate

# Проверить
adb shell pm list packages | grep -E 'storeos|hyota'
adb shell pm list packages -d
```

Если `pm uninstall` не сработал:

```sh
adb shell pm disable-user --user 0 com.hy.storeos
```

Если нужно откатить обновление к заводской версии (чтобы хотя бы убрать `/data`-копию):

```sh
adb shell pm uninstall-system-updates com.hy.storeos
```

**Ограничения:**

- заводская копия остаётся в `/product`;
- `com.hy.hyotaupdate` может вернуть обновление, если его не отключить;
- после factory reset dropper снова активен;
- `persist.sys.defappstore` продолжает указывать на удалённый пакет, возможны ошибки при открытии магазина.

### Вариант 2. Полное удаление из образа

Только этот способ удаляет dropper навсегда. Нужны `update.img` вашей сборки, `lpunpack`/`lpmake`, `debugfs` и пересборка Allwinner-контейнера. Пошагово — во внешних инструкциях: [HY300Pro → Root](https://github.com/Vadim000009/HY300ProByMagcubic/tree/main/Root) (та же платформа H726) и [hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal).

Кратко:

```sh
# product_a.img — здесь лежат APK
debugfs -w -R "rm /app/HY_StoreOs_QZ/HY_StoreOs_QZ.apk" product_a.img
debugfs -w -R "rm /app/HY_OtaUpdate_QZ/HY_OtaUpdate_QZ.apk" product_a.img
```

Перед прошивкой обязательно отключите AVB-проверку (`vbmeta` flags `0 -> 3`) и поднимите дату в `sunxi_version.fex`, иначе загрузчик откажется принимать образ.

## Сетевая изоляция

Даже после очистки устройства:

- выведите проектор в отдельный **IoT VLAN**;
- заблокируйте `IoT → основная LAN`;
- DHCP-DNS указывайте на Pi-hole с [денилистом](../iocs/pihole-denylist.txt);
- заблокируйте на шлюзе обращения проектора к внешним `:53` и `:853`, чтобы он не обходил DNS;
- заблокируйте hardcoded IP из [iocs/ips.txt](../iocs/ips.txt) на файрволе;
- не блокируйте `server.mphotool.com` до активации кастинга.

Пример правил на Linux-шлюзе (замените `192.168.1.50` на IP проектора):

```sh
PROJ=192.168.1.50
for ip in 8.218.163.124 47.86.211.252 47.96.145.84 \
          139.199.190.220 128.12.122.35 103.124.165.222 64.32.27.247; do
  iptables -I FORWARD -s "$PROJ" -d "$ip" -j DROP
done
```

На роутере с dnsmasq можно добавить:

```conf
address=/hanychx.com/0.0.0.0
address=/aodintech.com/0.0.0.0
address=/triplesai.com/0.0.0.0
address=/pixelpioneerss.com/0.0.0.0
address=/smartinnovate.net/0.0.0.0
address=/thedynamicleap.com/0.0.0.0
address=/kkoip.com/0.0.0.0
address=/soax.com/0.0.0.0
address=/srafx.com/0.0.0.0
address=/hotack.com/0.0.0.0
address=/vaicore.site/0.0.0.0
address=/dewrain.life/0.0.0.0
address=/akisinn.info/0.0.0.0
```

После правки перезагрузите dnsmasq, иначе правила не применятся. Проверьте, что случайный поддомен возвращает `0.0.0.0`:

```sh
nslookup random.hanychx.com 192.168.1.1
```

## Что ещё отключить

На проверенном экземпляре уже отключены:

```
com.toofifi.lineserver
com.htc.hyk_pcba
com.mphotool.usbcastserver
```

Если не пользуетесь встроенной заставкой, можно отключить `com.htc.screensaver`. Не отключайте `com.htc.magcubicos` — вместе с ним уйдут keystone и настройки изображения.

## Оговорки

- Один снимок `ss` ничего не доказывает. Вредоносное ПО может спать сутками. Запускайте [netwatch](../Scripts/netwatch.sh) на несколько дней.
- Состав прошивок меняется. Наличие/отсутствие `com.htc.storeos` или `com.hy.storeos` зависит от сборки.
- `SELinux=Permissive` и разблокированный загрузчик — это заводское состояние, а не следствие ваших действий. Оно делает закрепление вредоносного кода проще.
- AOSP test key сам по себе не является признаком malware: им подписаны и системные вендорские приложения. Смотрите на UID, права, домены и поведение.

---

Дальше: [Root](../Root/README.md)
