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

   Если сторонний лаунчер не понравится, вернуть MagcubicOS:

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

4. **Отключить вендорский OTA-апдейтер** `com.hy.hyotaupdate`. Он ходит на `ota.hanychx.com` и после сброса или обновления может вернуть/обновить `com.hy.storeos`:

   ```sh
   adb shell pm disable-user --user 0 com.hy.hyotaupdate
   ```

5. **Для полной очистки** нужна перепрошивка: [Root](Root/README.md). Factory reset проблему не решает. На текущей сборке от этого воздержался — для повседневного использования достаточно пунктов 3 и 4 выше.

---

## Что это за устройство

HY350 Max — проектор на Allwinner H726 с 2 ГБ ОЗУ, 16 или 32 ГБ eMMC и Android 14. В заводской прошивке установлен магазин `com.hy.storeos` с признаками **BADBOX 2.0**.

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

### Энергопотребление и нагрев

По отзывам пользователей этой модели, режим энергопотребления «нормальный» лучше не включать: матрица склонна к перегреву. Рекомендуют «энергосбережение». Отдельно стоит учитывать наклон вверх — в таком положении теплоотвод хуже, поэтому энергосбережение особенно желательно. На проверенном экземпляре используется именно энергосбережение: проектор направлен вверх.

### Резюме по безопасности

Явных признаков заражения или активного канала управления на проверенном экземпляре не обнаружено: подозрительных APK в `/data` нет, исходящие соединения шли в основном к Google и локальным клиентам. Однако полностью доверенной эту прошивку считать нельзя. Встроенный `com.hy.storeos` по признакам похож на dropper BADBOX 2.0: system UID, права на установку/удаление пакетов, `BootReceiver` и канал `appstore.hanychx.com`. Похожие прошивки уже попадали в ботнеты, поэтому после отключения `com.hy.storeos`/`com.hy.hyotaupdate` и DNS-блокировки доменов экземпляр можно считать безопасным для обычного использования — но не «безопасным по умолчанию».

---

## Разделы

| № | Раздел | О чём |
| --- | --- | --- |
| 1 | [ADB и доступ](ADB/README.md) | USB, отладка по Wi-Fi, pairing, что делать с зависающей авторизацией |
| 2 | [Аудит BADBOX 2.0](AUDIT/security.md) | `com.hy.storeos`, `com.hy.hyotaupdate`, IOC, проверка трафика, изоляция |
| 3 | [Root](Root/README.md) | почему без перепрошивки нельзя и где взять инструкцию |
| 4 | [Приложения](Apps/README.md) | что ставить, что не трогать, 32-битные APK, кастинг, Home Assistant |
| 5 | [Память](Memory/README.md) | замеры 2 ГБ, zram, что отключать |
| 6 | [IOC](iocs/) | домены, IP, пакеты, денилист для Pi-hole |
| 7 | [Скрипты](Scripts/README.md) | сбор информации, netwatch, debloat, блокировка IOC |
| 8 | [Данные экземпляра](docs/instance.md) | обезличенный отчёт по проверенному устройству |

---

## Источники и благодарности

- [Vadim000009/HY300ProByMagcubic](https://github.com/Vadim000009/HY300ProByMagcubic) — структура, методика, разделы ADB/Root/Overclock/Memory/AUDIT/Apps.
- [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal) 

## Лицензия

Документация — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), скрипты — MIT. Подробности в [LICENSE](LICENSE).
