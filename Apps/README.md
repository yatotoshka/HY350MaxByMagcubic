# Приложения и повседневное использование

← [К оглавлению](../README.md)

HY350 Max — это Android 14 с 2 ГБ ОЗУ и 32-битным userspace. Он не станет Android TV в полном смысле: здесь нет Android TV Remote Service, а часть интерфейса завязана на вендорский `com.htc.magcubicos`. Но поставить нормальный лаунчер, файловый менеджер, медиаплеер и клиент для стриминга можно.

## Главное ограничение: только 32 бита

```
ro.product.cpu.abilist = armeabi-v7a,armeabi
ro.product.cpu.abilist64 = []
```

Любой APK, собранный только под `arm64-v8a`, не установится. Если видите `INSTALL_FAILED_NO_MATCHING_ABIS` — причина в этом. Ищите `armeabi-v7a`-сборки.

## Что уже стоит

На проверенном экземпляре:

```
com.finalwire.aida64
ru.kinopoisk.tv
com.alphainventor.filemanager
com.yjlink.secretsettings
cm.aptoide.pt
com.spocky.projengmenu
```

Плюс отключены `com.toofifi.lineserver`, `com.htc.hyk_pcba`, `com.mphotool.usbcastserver`.

`com.spocky.projengmenu` — меню инженерных настроек проектора, полезно для диагностики. `com.yjlink.secretsettings` открывает скрытые разделы Android. `AIDA64` показывает железо. Всё это ставится вручную и не является частью прошивки.

## Магазин приложений

На устройстве два «магазина»:

1. **`com.hy.storeos`** — вендорский dropper. По умолчанию именно он прописан в `persist.sys.defappstore`. После очистки прошивки его не будет. Не используйте его.
2. **`com.android.vending`** — на проверенной сборке это настоящий Play Store, подписанный Google, с установленным GMS. Если вы удалили Tubesky, Play Store пропадёт.

Если Play Store остался, им можно пользоваться после входа в Google-аккаунт. Если GMS/Play не работают, альтернативы:

- **F-Droid** — open-source приложения, без Google;
- **Aurora Store** — клиент к Play Store без сервисов Google (учитывайте ToS Google);
- **Aptoide** — уже установлен на этом экземпляре;
- ручная установка APK с проверенных сайтов.

Избегайте «оптимизаторов», «чистильщиков» и сборок с неизвестных форумов: на устройстве уже есть system-UID dropper, добавлять ещё один не нужно.

## Лаунчер

`com.htc.magcubicos` — не просто лаунчер, а ещё и настройки проектора:

- keystone (`CorrectionActivity`);
- режим проецирования (`ProjectActivity`);
- начальный угол (`InitAngleActivity`);
- главные настройки (`MainSettingActivity`).

**Не удаляйте его.** Если хотите другой домашний экран, оставьте MagcubicOS установленным и назначьте новый лаунчер домашним:

```sh
adb shell cmd package set-home-activity com.example.launcher/.MainActivity
```

Проверка текущего HOME:

```sh
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

Популярный вариант — Projectivy Launcher (на проверенном устройстве уже лежит APK в `/sdcard/Download`). Он лёгкий и заточен под проекторы/ТВ. После установки не забудьте, что настройки изображения всё равно открываются через MagcubicOS.

## Что поставить

| Задача | Приложение | Замечания |
| --- | --- | --- |
| Лаунчер | Projectivy Launcher | лёгкий, ТВ-интерфейс, 32-bit |
| Файлы | Material Files / X-plore / уже установленный File Manager | нужен доступ к USB и сети |
| Видео | VLC / mpv / MX Player (32-bit) | проверяйте аппаратное декодирование |
| YouTube | SmartTube (32-bit) | без рекламы, управление пультом |
| Кино | Kinopoisk, Wink, Okko, IVI | зависят от DRM; Widevine L1 может быть недоступен |
| Браузер | Firefox / Chromium 32-bit | тяжёлый для 2 ГБ |
| Диагностика | AIDA64, CPU-Z | уже установлен AIDA64 |
| Пульт | Infrared/USB-мышь, Bluetooth-пульт | ИК-приёмник встроенный |

Не ставьте тяжёлые игры и «умные» лаунчеры с анимациями: 2 ГБ ОЗУ и zram не бесконечны.

## Кастинг: AirPlay, DLNA, Miracast

В системе есть:

- `com.mphotool.airplay`;
- `com.mphotool.dlna`;
- `com.mphotool.usbcastserver` (отключён на проверенном экземпляре);
- `com.htc.samescreen`;
- Miracast-стек `com.softwinner.miracastReceiver` / `com.android.toofifi`.

Активация AirPlay/DLNA хранится в `/data` и привязана к `server.mphotool.com`. После прошивки или сброса она теряется. Разрешите `server.mphotool.com` на ~30 секунд, дождитесь появления приёмников, затем можете снова блокировать.

Проверка:

```sh
adb shell settings get global ft_activated_data
adb shell logcat | grep -i 'ProcActive\|mphotool'
```

Если в логе `getActivated() isActived=0` — активации нет.

## Home Assistant

В прошивке нет Android TV Remote Service, поэтому официальная интеграция `androidtv` по протоколу Android TV не заработает. Рабочий вариант — ADB-интеграция Home Assistant:

1. Включите отладку по Wi-Fi.
2. Добавьте интеграцию `androidtv` в режиме ADB.
3. Укажите IP и порт `5555`.
4. Подтвердите RSA-ключ на проекторе.

Команды пульта можно дергать и напрямую:

```sh
adb shell input keyevent KEYCODE_HOME
adb shell input keyevent KEYCODE_BACK
adb shell input keyevent KEYCODE_DPAD_OK
```

## Lumina API

На `:8899` работает HTTP API без авторизации:

```sh
curl http://192.168.1.50:8899/api/v1/device
```

Он умеет `NAV_*`, `SETTINGS`, `TAKE_SCREENSHOT`, `OPEN_DEVELOPER`, `OPEN_FILE_MGR`, `OPEN_APP_MGR`, `FACTORY_RESET` и другие команды. Удобно для автоматизации, но **опасно**: любой в LAN может открыть настройки или сбросить устройство. После настройки закройте порт от чужих или изолируйте проектор.

## Память

2 ГБ ОЗУ — это мало для Android 14. Держите в фоне минимум приложений, не ставьте тяжёлые лаунчеры и браузеры. Подробные замеры и советы — в [Memory/README.md](../Memory/README.md).

## Что не делать

- Не удалять `com.htc.magcubicos` — потеряете keystone и настройки изображения.
- Не удалять `com.android.vending`, пока не проверили подпись: на этой сборке это настоящий Play Store.
- Не ставить APK только под arm64.
- Не оставлять открытыми `:5555`, `:8899` и FTP в основной сети.
- Не блокировать `server.mphotool.com` до активации кастинга.

---

Дальше: [Память](../Memory/README.md)
