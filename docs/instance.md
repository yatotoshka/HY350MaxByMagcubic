# Проверенный экземпляр

← [К оглавлению](../README.md)

Обезличенный отчёт по одному HY350 Max. MAC, серийный номер, LAN-IP и учётные данные не публикуются.

## Идентификация

| Параметр | Значение |
| --- | --- |
| Модель | Magcubic HY350 Max |
| Плата / прошивка | `h726_p1` (`ro.build.flavor=h726_p1-user`, `ro.build.product=h726-p1`) |
| SoC | Allwinner H726, `sun50iw15p1`, 4× Cortex-A53 |
| Пользовательское пространство | 32-бит, `armeabi-v7a` |
| Ядро | Linux 5.15.167, `armv7l` |
| Android | 14 (SDK 34) |
| Сборка | `Projector_20260821.111618` |
| Дата сборки | 21.08.2026 11:13 CST |
| Оболочка | BigdroidOS 3.0.3.010245, DroidBoost 2.1.7 |
| Модель в Lumina API | `rk3566_rgo` / `h726-2` / `H726 Focus` / API v3.0.0 |
| ОЗУ | 2 ГБ, DRAM 792 МГц, zram ~1,7 ГБ |
| ПЗУ | 16 ГБ, `/data` ~12 ГБ |
| Экран | 1920×1080, 60 Гц, 320 dpi |
| Wi-Fi | AIC rwnx 6.4.3.0, firmware 6.9.1.1 |
| SELinux | `Permissive` |
| Загрузчик | `ro.boot.flash.locked=0`, `ro.boot.verifiedbootstate=orange` |
| dm-verity | `enforcing` |
| Активный слот | `_a` |

## Пакеты BADBOX

| Пакет | Путь | UID | Версия | Подпись |
| --- | --- | --- | --- | --- |
| `com.hy.storeos` | `/product/app/HY_StoreOs_QZ`, обновление в `/data/app` | 1000 (system) | 127 → 135 (`2608201644` → `2609042030`) | AOSP test key |
| `com.hy.hyotaupdate` | `/product/app/HY_OtaUpdate_QZ` | 1000 (system) | 10 (`2608191543`) | AOSP test key |
| `com.htc.magcubicos` | `/product/app/HY_MagcubicOS` | 1000 (system) | `1.0.14` | AOSP test key |
| `com.android.vending` | `/product/priv-app/Tubesky` | 10055 | `34.1.09-23` | **Google Inc.** |

`com.hy.storeos` установлен как `UPDATED_SYSTEM_APP` 22.10.2026 в 21:35:31. Это произошло после загрузки: заводская версия лежит в `/product`, обновлённая — в `/data`.

## Хэши APK

```
3f0d4dfea5905b109a537d0368d8ba8da7b492c8c814f4bd78f16be3dd389876  com.hy.storeos (из /data)
859558ab8a67021ab9499def7f0d8acbb3dd0103db173eaa680dd1b4ab16a0f5  HY_StoreOs_QZ.apk (из /product)
8887334123d450a6dc7b5d82d49688f9319b14f27d9c5686301d4f2cf4ed13ea  HY_OtaUpdate_QZ.apk
4b6d959d97f0222cedce87684dd64eeefbbc0ebec141208600aaaa0d70650008  Tubesky.apk
9f97199b0f7701ad57ccad361c1df41c6585d2e5e74d52e258b005642976052e  HY_MagcubicOS.apk
```

## Компоненты `com.hy.storeos`

- `com.hy.storeos/.MainActivity`
- `com.hy.storeos/.PrivacyPolicyActivity`
- `com.hy.storeos/.receiver.BootReceiver`
- `com.hy.storeos/.service.StartAppService`
- `com.hy.storeos/.service.ExportService`
- `com.hy.storeos/.service.PublicRequestService`
- `com.hy.storeos.fileprovider`

Права: `INSTALL_PACKAGES`, `DELETE_PACKAGES`, `MOVE_PACKAGE`, `WRITE_SECURE_SETTINGS`, `WRITE_DEVICE_CONFIG`, `CLEAR_APP_USER_DATA`, `CHANGE_COMPONENT_ENABLED_STATE`, `RECEIVE_BOOT_COMPLETED`, `MANAGE_EXTERNAL_STORAGE`.

## Сетевые слушатели на момент проверки

| Порт | Кто/что |
| --- | --- |
| 1234 | `tvserver` |
| 5555 | `adbd` (отладка по Wi-Fi была включена) |
| 7889, 7890, 8890 | Miracast/toofifi |
| 8899 | Lumina API (без авторизации) |
| 9528 | AirPlay/AirTunes |
| 10008, 10012, 10013 | Miracast/toofifi |
| 32017, 32018, 32019, 55556 | AirPlay |
| 44075 | Jetty, привязан к LAN-адресу |
| 62110 | неизвестный слушатель, привязан к LAN-адресу |
| случайный | временный порт ADB pairing (на момент проверки) |

Ранее в ходе аудита был открыт FTP `:8841`; на момент повторной проверки он не слушал. Не считайте, что порт закрыт навсегда: проверяйте `ss -tunlp`.

## Активные соединения (снимок)

Основные внешние соединения на момент проверки:

- Google: `142.251.40.226:443`, `172.217.112.4:443`, `108.177.14.156:443`, `64.233.164.188:5228`;
- `34.98.104.50:443` — несколько соединений (похоже на Google-инфраструктуру);
- локальные клиенты на портах `5555`, `7890`, `8890`, `10008`.

Устойчивого соединения с известными C2 в этот момент не было. Это **один снимок**, а не доказательство чистоты.

## Отключённые пакеты

```
com.toofifi.lineserver
com.htc.hyk_pcba
com.mphotool.usbcastserver
```

## Особенности этой сборки

- `com.android.vending` подписан Google Inc. и, вероятно, является настоящим Play Store; GMS установлен. Это отличается от публичного отчёта, где Tubesky назван подделкой.
- `hotacksu` присутствует, но `hotacksu 0 id` из shell возвращает `setgid failed: Operation not permitted`.
- `ro.product.model` и `ro.board.platform` врут про Rockchip; реальная платформа — Allwinner `sun50iw15p1`.
- `/oem` смонтирован с `media_data` (`mmcblk0p26`), хотя публичный отчёт утверждает, что раздела `oem` нет.
- `persist.sys.defappstore=com.hy.storeos`; `setprop persist.sys.defappstore com.android.vending` выполняется без root, но команда `OPEN_APP_STORE` всё равно открыла `com.hy.storeos/.SettingsActivity`.
- `market://` не имеет назначенного обработчика по умолчанию: система показывает выбор между `com.android.vending` и `com.hy.storeos`.
- `ro.build.type=user`, `ro.debuggable=0`, `adb root` возвращает `adbd cannot run as root in production builds`; `ro.boot.verifiedbootstate=orange`, `ro.boot.flash.locked=0`. Root возможен только через патч `init_boot`/`system` и прошивку через FEL.
