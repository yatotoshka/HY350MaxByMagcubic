# Память

← [К оглавлению](../README.md)

HY350 Max: 2 ГБ ОЗУ и zram. Ниже — снимок с проверенного устройства и пакеты, которые можно отключить.

## Снимок на проверенном устройстве

```
$ adb shell free -m
              total        used        free      shared  buff/cache   available
Mem:           1965        1763         202          10          315         927
Swap:          1768         286        1482
```

- всего ОЗУ: 2012716 КБ (~1965 МиБ);
- `MemAvailable`: 949076 КБ (~927 МиБ);
- zram: 1768 МиБ, из них занято 286 МиБ;
- `/data`: 12 ГБ, занято ~1,5 ГБ.

Это **один снимок после загрузки**, а не бенчмарк. На другой сборке и с другим набором приложений цифры будут другими.

## Что отключать

Кандидаты на проверенной сборке:

```sh
# Уже отключены
com.toofifi.lineserver
com.htc.hyk_pcba
com.mphotool.usbcastserver

# Можно отключить, если не нужна встроенная заставка
adb shell pm disable-user --user 0 com.htc.screensaver
```

Не отключайте:

- `com.htc.magcubicos` — лаунчер и настройки изображения;
- `com.android.vending` — если это настоящий Play Store;
- `com.google.android.gms` — без него не будет Play и части push;
- `com.android.networkstack` — останетесь без сети.

---

Дальше: [Скрипты](../Scripts/README.md)
