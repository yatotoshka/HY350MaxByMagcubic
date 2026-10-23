# Проектор HY350 Max (Magcubic, Allwinner H726)

Руководство по реверсу, аудиту, обезвреживанию и доработке проектора **Magcubic HY350 Max** на **Allwinner H726** с Android 14.

> **За основу взято.** Структура, методика и формат этого руководства взяты за основу из репозитория [Vadim000009/HY300ProByMagcubic](https://github.com/Vadim000009/HY300ProByMagcubic) («Реверс проектора HY300Pro от MagCubic и его доработка»). Текст написан заново для HY350 Max; данные по BADBOX 2.0 и очистке прошивки опираются на [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal). Это не официальная документация Magcubic.

Репозиторий описывает один проверенный экземпляр HY350 Max и публичные находки по этой же модели. Состав прошивок у вендора меняется от сборки к сборке, поэтому **проверяйте своё устройство**, а не доверяйте этому отчёту вслепую.

---

## Быстрый путь: сделать проектор удобным

Если не хочется читать аудит целиком:

1. **Получить ADB.** Установить Aptoide → Hidden Settings (`com.yjlink.secretsettings`) → Developer options → Wireless debugging. Pairing и команды — в [ADB](ADB/README.md).
2. **Поставить сторонний лаунчер.** Например, Projectivy, и назначить его домашним:

   ```sh
   adb shell cmd package set-home-activity com.spocky.projengmenu/.ui.home.MainActivity
   ```

   Вернуть MagcubicOS:

   ```sh
   adb shell cmd package set-home-activity com.htc.magcubicos/.activity.MainActivity
   ```

3. **Переключить магазин на Google Play.** На этой сборке `com.android.vending` — настоящий Play Store, подписанный Google, с установленным GMS. Отдельной настройки «магазин по умолчанию» в UI нет, а штатная кнопка магазина в MagcubicOS всё равно открывает `com.hy.storeos`.

   - `setprop persist.sys.defappstore com.android.vending` выполняется без root, но в проверке кнопка `OPEN_APP_STORE` всё равно открыла `com.hy.storeos` — возможно, свойство читается только при загрузке.
   - Надёжнее отключить dropper и запускать Play Store напрямую:

     ```sh
     adb shell pm disable-user --user 0 com.hy.storeos
     adb shell monkey -p com.android.vending -c android.intent.category.LAUNCHER 1
     ```

     Если `disable-user` не сработал: `adb shell pm uninstall --user 0 com.hy.storeos`. После этого ссылки `market://` обрабатывает Play Store. Кнопка магазина в MagcubicOS может перестать работать.

   Вернуть свойство, если меняли:

   ```sh
   adb shell setprop persist.sys.defappstore com.hy.storeos
   ```

4. **Отключить OTA**, чтобы он не вернул dropper:

   ```sh
   adb shell pm disable-user --user 0 com.hy.hyotaupdate
   ```

5. **Для полной очистки** нужна правка образа: [Root](Root/README.md). Factory reset проблему не решает.

> `com.hy.storeos` — это malware, а не просто магазин. Его отключение — часть очистки, а не только смена магазина.

---

## Что это за устройство

HY350 Max — проектор на Allwinner H726 с 2 ГБ ОЗУ, 16 или 32 ГБ eMMC и Android 14. В заводской прошивке установлен **BADBOX 2.0** в варианте `com.hy.storeos`.

Устройство выдаёт себя за Rockchip RK3566: в `getprop` прописаны `rk3566_rgo`, `hermes`, `rockchip`. Это ложь, унаследованная от чужого AOSP-конфига. Реальный SoC — **Allwinner H726** (`sun50iw15p1`), что подтверждается `ro.boot.hardware`, `/proc/device-tree/compatible` и `ro.build.flavor=h726_p1-user`.

### Технические характеристики

| Компонент | Что видно на устройстве |
| --- | --- |
| SoC | Allwinner H726, 4 ядра Cortex-A53, платформа `sun50iw15p1` |
| Пользовательское пространство | 32-битное, `armeabi-v7a` (`ro.product.cpu.abilist64=[]`) |
| ОЗУ | 2 ГБ (`ro.boot.dramsize=2048`), частота DRAM 792 МГц, плюс zram ~1,7 ГБ |
| ПЗУ | 16 ГБ eMMC на проверенном экземпляре; встречается и 32 ГБ, `/data` ~12 ГБ |
| ОС | Android 14 (SDK 34), сборка `Projector_20260821.111618` |
| Оболочка | BigdroidOS 3.0.3.010245, DroidBoost 2.1.7, MagcubicOS |
| Экран | 1920×1080, 60 Гц, плотность 320 dpi |
| Wi-Fi | AIC, драйвер `rwnx 20250410-009-6.4.3.0`, прошивка 6.9.1.1 |
| Порты | HDMI, USB-A, ИК-приёмник, Bluetooth-пульт (по публичным данным для этой модели) |
| Питание | уточняется по вашей ревизии; не подавайте питание от другого блока, пока не проверены разъём и напряжение |
| Сервисный режим | FEL у Allwinner, восстановление через PhoenixSuit/PhoenixUSBPro |
| Разметка | A/B: `boot_a/b`, `init_boot_a/b`, `vendor_boot_a/b`, `super`, `vbmeta*_a/b` |

Модель в API Lumina (`:8899`) может отличаться от сборки: на проверенном экземпляре там `name=rk3566_rgo`, `model=h726-2`, `model_label=H726 Focus`, `version=v3.0.0`. При этом прошивка рапортует `ro.build.product=h726-p1` и `ro.build.flavor=h726_p1-user`. Для выбора образа доверяйте **сборке и плате**, а не строке `model` из Lumina.

### Почему нельзя верить `getprop`

| Свойство | Показывает | На самом деле |
| --- | --- | --- |
| `ro.product.model` | `rk3566_rgo` | Allwinner H726 |
| `ro.product.board` | `exdroid` | `sun50iw15p1` |
| `ro.board.platform` | `hermes` | `sun50iw15p1` |
| `ro.build.fingerprint` | `rockchip/...:13/...` | Android 14 |
| `ro.boot.verifiedbootstate` | `orange` | загрузчик разблокирован, но AVB/verity включены |
| `ro.boot.vbmeta.device_state` | `locked` | свойство унаследовано, не отражает реальное состояние |

Достоверные проверки:

```sh
adb shell getprop ro.boot.hardware          # sun50iw15p1
adb shell getprop ro.build.flavor           # h726_p1-user
adb shell getprop ro.build.product          # h726-p1
adb shell getprop ro.product.firmware        # H726-android14-v1.0
adb shell getprop ro.sys.cputype            # QuadCore-H726
adb shell cat /proc/device-tree/compatible   # allwinner,h726, arm,sun50iw15p1
adb shell uname -a                           # 5.15.167 ... armv7l
```

### Проверка платы

HY350 Max — это `h726_p1`. Не прошивайте образ для `h726_p2`: это другая плата, и перекрёстная прошивка — самый короткий путь к кирпичу.

```sh
adb shell getprop ro.build.flavor
# h726_p1-user
```

---

## Разделы

| № | Раздел | О чём |
| --- | --- | --- |
| 1 | [ADB и доступ](ADB/README.md) | USB, отладка по Wi-Fi, pairing, что делать с зависающей авторизацией |
| 2 | [Аудит BADBOX 2.0](AUDIT/security.md) | `com.hy.storeos`, `com.hy.hyotaupdate`, IOC, проверка трафика, изоляция |
| 3 | [Прошивка и очистка](Root/README.md) | `update.img`, `lpunpack`, `vbmeta`, version lock, USB-прошивка, восстановление |
| 4 | [Приложения](Apps/README.md) | что ставить, что не трогать, 32-битные APK, кастинг, Home Assistant |
| 5 | [Память](Memory/README.md) | замеры 2 ГБ, zram, что отключать |
| 6 | [IOC](iocs/) | домены, IP, пакеты, денилист для Pi-hole |
| 7 | [Скрипты](Scripts/README.md) | сбор информации, netwatch, debloat, блокировка IOC |
| 8 | [Данные экземпляра](docs/instance.md) | обезличенный отчёт по проверенному устройству |

---

## Что уже проверено на этом экземпляре

Проверка выполнена по ADB 23 октября 2026 года на сборке `Projector_20260821.111618`:

- плата/прошивка: `h726_p1`, `sun50iw15p1`, Allwinner H726, 32-битный userspace;
- экран 1920×1080, 60 Гц; ОЗУ 2 ГБ; `/data` 12 ГБ;
- `SELinux` — `Permissive`; `ro.boot.verifiedbootstate=orange`; `ro.boot.flash.locked=0`; `veritymode=enforcing`;
- отладка по Wi-Fi работает: pairing и подключение на `:5555` прошли без зависания (в отличие от отчёта по другой ревизии);
- `com.hy.storeos` установлен как **обновление системного приложения**, работает под `android.uid.system` (uid 1000), подписан AOSP test key (`CN=Android, O=Android`), имеет права `INSTALL_PACKAGES`, `DELETE_PACKAGES`, `WRITE_SECURE_SETTINGS`, `CLEAR_APP_USER_DATA`, `CHANGE_COMPONENT_ENABLED_STATE`;
- заводская версия в `/product/app/HY_StoreOs_QZ`: `versionCode=127`, `versionName=2608201644`; обновлённая в `/data/app`: `versionCode=135`, `versionName=2609042030`, установлена 22.10.2026 в 21:35;
- `com.hy.hyotaupdate` (`/product/app/HY_OtaUpdate_QZ`, uid 1000) ходит на `ota.hanychx.com`;
- `com.android.vending` (`/product/priv-app/Tubesky`) на этой сборке **подписан ключом Google Inc.** и выглядит как настоящий Play Store, а не подделка; GMS (`com.google.android.gms`) присутствует. Не удаляйте его вслепую: сначала проверьте подпись;
- `com.htc.magcubicos` — вендорский лаунчер и настройки проектора (keystone, режим проецирования). Удалять нельзя;
- `/system/xbin/hotacksu` присутствует, имеет setuid root, но на этой сборке вызов из shell даёт `setgid failed: Operation not permitted`;
- в момент проверки исходящие соединения шли в основном к Google (Play/GMS) и к локальным клиентам; устойчивого канала на известные C2 не наблюдалось. Это снимок, а не гарантия.

---

## Вопросы и ответы

**В. У меня 16 ГБ, а в интернете пишут про 32 ГБ. Это нормально?**

О. Да. В публичном отчёте подтверждены обе версии: 16 и 32 ГБ. В `sys_partition.fex` раздел `UDISK`/`userdata` не имеет фиксированного размера и забирает остаток eMMC.

**В. У меня не включается ADB, соединение висит в `unauthorized`.**

О. На части ревизий вендор подавил диалог авторизации. Сначала попробуйте штатную «Отладку по Wi-Fi» с pairing-кодом (на проверенной сборке она работает). Если не помогает — единственный надёжный путь, по публичному отчёту, это правка `ro.adb.secure=0` в `system/build.prop` внутри образа. Это ослабляет безопасность: такой ADB доступен всем в LAN без авторизации.

**В. Устройство заражено? Factory reset поможет?**

О. На HY350 Max BADBOX 2.0 находится в заводской прошивке. `com.hy.storeos` лежит в `/product`, а после сброса и первого boot снова обновляется в `/data`. Factory reset не удаляет dropper. Нужна очистка образа (см. [Root](Root/README.md)) и блокировка OTA/сети.

**В. Можно ли просто удалить `com.hy.storeos` через ADB?**

О. Можно скрыть/удалить для пользователя (`pm uninstall --user 0`), но заводская копия останется в `/product`, а `com.hy.hyotaupdate` может вернуть обновление. Это временная мера. Полное удаление — только правка `product_a`/`system_a` в образе.

**В. Я кирпичнул устройство. Что делать?**

О. H726 восстанавливается через FEL и PhoenixSuit/PhoenixUSBPro. Открытый `sunxi-fel` на macOS у автора публичного отчёта H726 не определял. Сначала проверьте драйвер, кабель и то, что кнопка FEL зажата **до** подачи питания по USB. Основное питание для FEL не требуется.

---

## Дисклеймер

Всё описанное лишает гарантии и делается на ваш страх и риск. Прошивка может кирпичнуть устройство, стереть `/data` и данные активации кастинга. Автор не несёт ответственности за последствия. Не публикуйте и не передавайте образы с включённым `ro.adb.secure=0`: это превращает проектор в открытый root-ADB ящик в вашей сети.

---

## Источники и благодарности

- [Vadim000009/HY300ProByMagcubic](https://github.com/Vadim000009/HY300ProByMagcubic) — структура, методика, разделы ADB/Root/Overclock/Memory/AUDIT/Apps.
- [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal) — BADBOX 2.0 на HY350 Max, IOC, очистка `update.img`, `vbmeta`, version lock, USB-прошивка.
- HUMAN Security — исследование BADBOX 2.0.
- `Kavan00/Android-Projector-C2-Malware` — отчёт по IOC.
- linux-sunxi.org — FEL и `sunxi-tools`.

## Лицензия

Документация — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), скрипты — MIT. Подробности в [LICENSE](LICENSE).
