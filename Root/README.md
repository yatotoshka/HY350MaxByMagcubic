# Прошивка, очистка и восстановление

← [К оглавлению](../README.md) · [Аудит](../AUDIT/security.md)

Этот раздел описывает полную очистку заводского образа HY350 Max от BADBOX 2.0 и получение root. Root здесь возможен **только через пересборку `update.img` и прошивку через FEL**: штатного пути без перепрошивки нет. Рецепт **не проверен автором на устройстве из этого репозитория**: он собран по публичному отчёту [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal) и по данным, снятым с проверенного экземпляра. Всё, что ниже, может отличаться на вашей сборке.

> **Root без полной пересборки и перепрошивки получить невозможно.** На этой сборке `adb root` отвечает `adbd cannot run as root in production builds`, `su` в системе нет, а fastboot/recovery с ADB sideload отсутствуют. Если root нужен — только патч `init_boot`/`system` и заливка образа через FEL. Готовая инструкция для той же платформы H726: [Vadim000009/HY300ProByMagcubic → Root](https://github.com/Vadim000009/HY300ProByMagcubic/tree/main/Root).

> **Прошивка стирает `/data` и может кирпичнуть устройство.** Сделайте дамп и сохраните исходный `update.img` в двух местах. Восстановление — FEL + PhoenixSuit/PhoenixUSBPro.

## Проверка платы

HY350 Max — это `h726_p1`. Не прошивайте образ для `h726_p2`: это другая плата, и перекрёстная прошивка — самый вероятный способ получить кирпич.

Проверка:

```sh
adb shell getprop ro.build.flavor
adb shell getprop ro.build.product
adb shell cat /proc/device-tree/compatible
adb shell getprop ro.boot.hardware
```

На проверенном экземпляре:

```
h726_p1-user
h726-p1
allwinner,h726 / arm,sun50iw15p1
sun50iw15p1
```

## Где взять стоковую прошивку

Репозиторий не распространяет бинарники. Скачайте образ у вендора:

- HY350 Max (`h726_p1`): <https://www.magcubic-support.com/newsinfo/3145143.html>
- Общий индекс прошивок: <https://www.magcubic-support.com/xw>

Проверьте, что образ соответствует вашей сборке. Вендорская страница может отдавать образ старше установленного, а загрузчик HY350 Max отказывается шить образ с датой **равной или более старой, чем установленная**. Об этом ниже.

## Разметка проверенного устройства

Наблюдаемая разметка `by-name`:

```
bootloader_a/b   p1/p2
env_a/b          p3/p4
boot_a/b         p5/p6
vendor_boot_a/b  p7/p8
init_boot_a/b    p9/p10
super            p11
misc             p12
vbmeta_a/b       p13/p14
vbmeta_system_a/b p15/p16
vbmeta_vendor_a/b p17/p18
frp              p19
empty            p20
metadata         p21
treadahead       p22
private          p23
dtbo_a/b         p24/p25
media_data       p26   (монтируется как /oem)
Reserve0_a/b     p27/p28
userdata         p29
```

Публичный отчёт утверждает, что раздела `oem` нет. На этой сборке `/oem` есть и смонтирован с `media_data` (`mmcblk0p26`). Это ещё одна причина проверять разметку своего образа, а не полагаться на чужую.

`super` — динамический раздел с `system_a`, `vendor_a`, `product_a`. В рантайме они видны как `dm-0`, `dm-1`, `dm-2`.

## Что понадобится

| Инструмент | Зачем |
| --- | --- |
| `update.img` вашей сборки | исходный образ |
| `lpunpack` / `lpmake` | разбор и сборка `super` |
| `simg2img` / `img2simg` | sparse ↔ raw |
| `debugfs` (e2fsprogs) | удаление файлов из ext4 без mount |
| Allwinner-упаковщик IMAGEWTY | `awimg.py` или аналог |
| PhoenixSuit / PhoenixUSBPro | восстановление через FEL |
| Python 3 | для `awimg.py` |

В репозитории, взятом за основу, есть [`Scripts/awimg.py`](https://github.com/Vadim000009/HY300ProByMagcubic/blob/main/Scripts/awimg.py) для контейнера IMAGEWTY. Его можно взять за основу, но **проверьте на своём образе**:

- смещения записей выравниваются вверх до 1024 байт;
- каждый `V*.fex` хранит контрольную сумму парного файла: сумма 32-битных little-endian слов (с нулевым дополнением в конце) по модулю 2³²;
- тест «распаковать → собрать без замен» должен дать **байт-в-байт** исходный файл. Если не даёт — инструмент не подходит.

## 1. Распаковка

```sh
./awimg.py list update.img
./awimg.py extract update.img ./unpacked/
```

`extract` пишет в каталог все `.fex`, а не один выбранный файл.

```sh
# super.fex — Android sparse image
od -A d -t x1 -N 4 ./unpacked/super.fex
# 3a ff 26 ed — sparse

simg2img ./unpacked/super.fex super.raw
lpunpack super.raw ./super_out
# super_out/system_a.img, vendor_a.img, product_a.img
```

Проверьте, что это ваш образ:

```sh
grep -a -m1 -E 'allwinner,h726|sun50iw15' ./unpacked/sunxi.fex
```

Если видите `h713` или `sun50iw12p1` — образ от другого устройства, не прошивайте.

## 2. Удаление BADBOX

На проверенной сборке malice лежит в `product_a`:

```sh
# Посмотреть, что есть
debugfs -R "ls -l /app" product_a.img
debugfs -R "ls -l /priv-app" product_a.img

# Удалить dropper и OTA
debugfs -w -R "rm /app/HY_StoreOs_QZ/HY_StoreOs_QZ.apk" product_a.img
debugfs -w -R "rm /app/HY_OtaUpdate_QZ/HY_OtaUpdate_QZ.apk" product_a.img
```

Если в вашем образе есть `StoreOs_QZ`, `HtcOtaUpdate_QZ`, `Tubesky` — удаляйте и их:

```sh
debugfs -w -R "rm /app/StoreOs_QZ/StoreOs_QZ.apk" product_a.img
debugfs -w -R "rm /app/HtcOtaUpdate_QZ/HtcOtaUpdate_QZ.apk" product_a.img
debugfs -w -R "rm /priv-app/Tubesky/Tubesky.apk" product_a.img
```

**Не удаляйте `HY_MagcubicOS` / `com.htc.magcubicos`.** Это лаунчер и настройки изображения.

**С `Tubesky` сначала проверьте подпись.** Если APK подписан Google Inc. — это настоящий Play Store, и его удаление лишит вас магазина. Если AOSP test key или неизвестный ключ — это подделка, удаляйте.

Опционально, но непроверено: удалить `hotacksu` из `system_a`:

```sh
debugfs -w -R "rm /system/xbin/hotacksu" system_a.img
```

Публичный отчёт не подтверждает, что от этого ничего не зависит. Сначала проверьте на копии.

Сборка `super` обратно:

```sh
# Вариант 1: lpmake по манифесту, затем img2simg
# Вариант 2: записать изменённый раздел обратно в super.raw по смещению и сделать img2simg
img2simg super.new.raw super.new.fex
```

Публичный отчёт использовал `dd` по смещению сектора `2682880` для `product_a`. Если не уверены в смещении, используйте `lpmake`/`lpdump`, а не «магическое число».

## 3. Отключение AVB

Если изменить `super`, загрузчик отвергнет образ, пока включена проверка. В `vbmeta` нужно выставить флаги `verification + hashtree disabled`:

```
flags: 0 -> 3
смещение 123 (0x7B) = 0x03
```

Публичный отчёт указывает, что offsets `120–123` содержат поле flags. Проверьте на своём `vbmeta.fex`:

```sh
xxd -s 0x78 -l 8 vbmeta.fex
```

Не копируйте слепо `0x78`/`0x7B`: сначала убедитесь, что структура совпадает. После правки пересоберите образ и прошейте.

> `ro.boot.veritymode=enforcing` на проверенном устройстве означает, что dm-verity включён. Правка `vbmeta` нужна именно для того, чтобы изменённый `super` загрузился.

## 4. Обход version lock

Загрузчик HY350 Max не принимает образ, дата сборки которого **равна или более старая, чем дата установленной прошивки**. Если у вас сборка `Projector_20260821.111618`, а вендор отдаёт `Projector_20260113...`, образ не встанет.

`sunxi_version.fex` — текстовый файл из 40 байт: две одинаковые строки по 20 байт.

```sh
# Посмотреть
cat unpacked/sunxi_version.fex

# Сделать новую дату (ровно 40 байт)
printf '2027-12-31 23:59:59\n2027-12-31 23:59:59\n' > sunxi_version_new.fex
wc -c sunxi_version_new.fex   # 40

./awimg.py replace update.img sunxi_version.fex sunxi_version_new.fex out.img
```

Дату нужно поднимать **при каждой перепрошивке**, если текущая установленная сборка новее образа.

## 5. Сборка и прошивка

```sh
./awimg.py replace update.img super.fex super.new.fex out1.img
./awimg.py replace out1.img vbmeta.fex vbmeta.new.fex out2.img
./awimg.py replace out2.img sunxi_version.fex sunxi_version_new.fex update_clean.img
```

Проверьте итог:

```sh
./awimg.py extract update_clean.img check/
ls -l check/
# super.fex, vbmeta.fex, sunxi_version.fex должны быть вашими,
# остальные — совпадать с исходными
```

### Запись через USB

1. Отформатируйте флешку в **FAT32, MBR**, один раздел.
2. Создайте каталог `/update/` и положите туда `update.img`.
3. Вставьте флешку в USB-A проектора.
4. Зажмите кнопку питания, пока светодиод не сменит цвет с красного на синий. Начнётся прошивка.

Замечания из публичного отчёта:

- прошивка **стирает `/data`** — приложения, настройки и активация кастинга пропадут;
- прогресс может дойти до 100% и зависнуть на час. Не выдёргивайте питание, пока шкала не заполнится полностью. Если зависло после 100% — выньте флешку и передёрните питание;
- не прерывайте запись, пока идёт прогресс.

## 6. Восстановление через FEL

FEL — аварийный загрузчик в кристалле Allwinner. Он жив, пока жив процессор, и не зависит от Android.

1. Обесточьте проектор.
2. Зажмите сервисную кнопку FEL (обычно под разъёмом USB / в отверстии).
3. Подключите USB к компьютеру и подайте питание.
4. Отпустите кнопку.
5. В Windows должен появиться `VID_1F3A / PID_EFE8`; установите драйвер из комплекта PhoenixUSBPro.
6. В PhoenixUSBPro выберите исходный `update.img`, нажмите Start, затем переведите плату в FEL.

Публичный отчёт предупреждает: `sunxi-fel` на macOS не определил H726. Если FEL не виден — проверьте драйвер, кабель и порядок «кнопка зажата до питания». Плата H726 может работать от одного USB; основное питание нужно светодиоду.

## 7. Root: только через перепрошивку

**Root без пересборки и прошивки не ставится.** Проверено на этой сборке:

- `ro.build.type=user`, `ro.build.tags=release-keys`, `ro.debuggable=0`; `adb root` возвращает `adbd cannot run as root in production builds`;
- `su` нет в `/system/bin`, `/system/xbin`, `/sbin`, `/debug_ramdisk`; Magisk/SuperSU не установлены;
- нет fastboot и recovery с ADB sideload — запись разделов возможна только через FEL и `update.img`;
- `ro.boot.verifiedbootstate=orange` и `ro.boot.flash.locked=0` не дают shell прав на запись в `/system` или `boot`;
- вендорский setuid-бинарник `hotacksu` на этой сборке не сработал (`setgid failed`), хотя на другой ревизии даёт root; полагаться на него нельзя.

Рабочий путь — пропатчить `init_boot.fex` в Magisk, поправить `vbmeta` и прошить образ. Пошагово для H726: [Vadim000009/HY300ProByMagcubic → Root](https://github.com/Vadim000009/HY300ProByMagcubic/tree/main/Root). Инструкция написана для HY300 Pro: сверьте `h726_p1`/`h726_p2`, разметку и `init_boot` со своим образом.

### Вариант: root-ADB через build.prop

Если нужен именно root-ADB, а не Magisk, публичный отчёт предлагает вшить в `system_a.img:/system/build.prop`:

```properties
ro.secure=0
ro.adb.secure=0
ro.debuggable=1
service.adb.tcp.port=5555
persist.adb.tcp.port=5555
```

> **Это делает проектор открытым root-ADB ящиком для всей LAN.** Только изолированный VLAN. Не распространяйте такой образ.

Особенности из отчёта:

- `/system` может быть заполнен на 100%; тогда строки `ro.secure=1` → `ro.secure=0` и `ro.adb.secure=1` → `ro.adb.secure=0` правятся **на месте**, без изменения размера файла.
- `debugfs rm` + `write` теряет режим файла и SELinux-xattr. Сохраните и восстановите их:

```sh
debugfs -R "stat /system/build.prop" system_a.img
debugfs -R "ea_get -f label.bin /system/build.prop security.selinux" system_a.img

debugfs -w -R "rm /system/build.prop" system_a.img
debugfs -w -R "write build.prop /system/build.prop" system_a.img
debugfs -w -R "sif /system/build.prop mode 0100600" system_a.img
debugfs -w -R "ea_set -f label.bin /system/build.prop security.selinux" system_a.img
```

- `Uid`/`Gid` должны остаться `0`.
- После каждой перепрошивки дату в `sunxi_version.fex` нужно поднимать снова.

## 8. После прошивки

Проверьте:

```sh
adb shell pm list packages | grep -E 'storeos|hyota|htc.storeos|tubesky'
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.veritymode
```

Ожидаемо:

- пакетов `com.hy.storeos`, `com.hy.hyotaupdate`, `com.htc.storeos`, `com.htc.htcotaupdate` нет;
- `com.android.vending` остаётся, если вы не удаляли настоящий Play Store;
- `com.htc.magcubicos` остаётся;
- кастинг после прошивки может быть выключен, пока не сходит на `server.mphotool.com`.

Активация кастинга:

```sh
# Разрешите server.mphotool.com на ~30 секунд
# Проверьте, что AirPlay/DLNA появились
adb shell settings get global ft_activated_data
```

Если `ft_activated_data` пуст, приёмники не активированы. Не блокируйте `mphotool.com` навсегда до первой успешной активации.

## Если что-то пошло не так

| Симптом | Что делать |
| --- | --- |
| Чёрный экран, нет загрузки | FEL + исходный `update.img` |
| Образ не принимается | поднять дату в `sunxi_version.fex` |
| Бутлуп после правки `super` | FEL + исходный образ |
| Нет ADB после прошивки | включить отладку заново / pairing |
| Нет кастинга | разрешить `server.mphotool.com`, проверить `ft_activated_data` |
| FEL не виден | драйвер, кабель, кнопка зажата до питания |
| Нет реакции на питание | аппаратная проблема |

## Оговорки

- Рецепт публичного отчёта проверен на двух устройствах (16 и 32 ГБ), но **не на устройстве из этого репозитория**.
- Сборка `Projector_20260821.111618` новее публичных образов. Проверьте, есть ли для неё стоковый образ у вендора, прежде чем что-то шить.
- Не публикуйте модифицированный образ: это и авторские права вендора, и риск для тех, кто прошьёт его вслепую.
- После очистки всё равно нужна сетевая изоляция: вы не знаете, что именно вендор положит в следующую OTA.

---

Дальше: [Приложения](../Apps/README.md)
