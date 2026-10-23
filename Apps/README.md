# Приложения и повседневное использование

← [К оглавлению](../README.md)

HY350 Max — это Android 14 с 2 ГБ ОЗУ и 32-битным userspace. Он не станет Android TV в полном смысле: здесь нет Android TV Remote Service, а часть интерфейса завязана на вендорский `com.htc.magcubicos`. Но поставить нормальный лаунчер, файловый менеджер, медиаплеер и клиент для стриминга можно.

## Главное ограничение: только 32 бита

```
ro.product.cpu.abilist = armeabi-v7a,armeabi
ro.product.cpu.abilist64 = []
```

Любой APK, собранный только под `arm64-v8a`, не установится. Ошибка `INSTALL_FAILED_NO_MATCHING_ABIS` означает именно это. Ищите `armeabi-v7a`-сборки.

## Магазин приложений

На устройстве два «магазина»:

1. **`com.hy.storeos`** — вендорский dropper. По умолчанию именно он прописан в `persist.sys.defappstore`. После очистки прошивки его не будет. Не используйте его.
2. **`com.android.vending`** — на проверенной сборке это настоящий Play Store, подписанный Google, с установленным GMS. После удаления Tubesky Play Store пропадает.

Play Store работает после входа в Google-аккаунт. При неработающих GMS/Play есть альтернативы:

- **F-Droid** — open-source приложения, без Google;
- **Aurora Store** — клиент к Play Store без сервисов Google (учитывайте ToS Google);
- **Aptoide** — альтернативный магазин;
- ручная установка APK.

## Лаунчер

`com.htc.magcubicos` — не просто лаунчер, а ещё и настройки проектора:

- keystone (`CorrectionActivity`);
- режим проецирования (`ProjectActivity`);
- начальный угол (`InitAngleActivity`);
- главные настройки (`MainSettingActivity`).

**Не удаляйте его.** Для другого домашнего экрана оставьте MagcubicOS установленным и назначьте новый лаунчер домашним.

### Как переключиться на сторонний лаунчер

Проверить текущий HOME и все зарегистрированные лаунчеры:

```sh
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

Пример для Projectivy Launcher (`com.spocky.projengmenu`):

```sh
adb shell cmd package set-home-activity com.spocky.projengmenu/.ui.home.MainActivity
```

На этой прошивке одного `set-home-activity` мало: после перезагрузки вендорный `system_server` запускает пакет из `persist.sys.homePackage`, а там по умолчанию `com.htc.magcubicos`. Поэтому стоковый лаунчер может снова оказаться домашним. Закрепить Projectivy:

```sh
adb shell setprop persist.sys.homePackage com.spocky.projengmenu
```

Проверка и откат:

```sh
adb shell getprop persist.sys.homePackage
adb shell setprop persist.sys.homePackage com.htc.magcubicos
```

### Поведение после перезагрузки

Даже с `persist.sys.homePackage=com.spocky.projengmenu` на холодной загрузке первым может открыться MagcubicOS: вендорский лаунчер стартует раньше, чем применяется HOME-роль. После запуска любого приложения и нажатия Home открывается Projectivy. Это особенность прошивки, а не ошибка настройки; на работу она не влияет.

`persist.sys.initPackage` не трогайте: он связан с `InitAngleActivity` и настройкой начального угла.

Вернуть MagcubicOS полностью:

```sh
adb shell cmd package set-home-activity com.htc.magcubicos/.activity.MainActivity
adb shell setprop persist.sys.homePackage com.htc.magcubicos
```

При отсутствии выбора лаунчера при нажатии Home:

```sh
adb shell cmd package clear-package-preferred-activities com.htc.magcubicos
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

После этого нажать Home и выбрать нужный лаунчер. Настройки изображения всё равно открываются через MagcubicOS.

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

Запись `getActivated() isActived=0` в логе означает отсутствие активации.

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

## Что не делать

- Не удалять `com.htc.magcubicos` — потеряете keystone и настройки изображения.
- Не удалять `com.android.vending`, пока не проверили подпись: на этой сборке это настоящий Play Store.
- Не ставить APK только под arm64.
- Не оставлять открытыми `:5555`, `:8899` и FTP в основной сети.
- Не блокировать `server.mphotool.com` до активации кастинга.

---

Дальше: [Память](../Memory/README.md)
