# Root

← [К оглавлению](../README.md) · [Аудит](../AUDIT/security.md)

**Получить root на HY350 Max без перепрошивки невозможно.**

На этой сборке `adb root` отвечает `adbd cannot run as root in production builds` (`ro.build.type=user`, `ro.debuggable=0`), `su` в системе нет, fastboot и recovery с ADB sideload отсутствуют. Вендорский `hotacksu` на проверенном экземпляре не сработал. Root появляется только после перепрошивки изменённого образа.

Я не перепрошивал устройство: для нормальной работы root не потребовался. При необходимости перепрошивка возможна по инструкции для той же платформы H726:

- [Vadim000009/HY300ProByMagcubic → Root](https://github.com/Vadim000009/HY300ProByMagcubic/tree/main/Root)
- [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal) — очистка именно HY350 Max

Перед прошивкой сверьте плату: HY350 Max — `h726_p1`, образ от `h726_p2` не подходит. Прошивка стирает `/data` и может кирпичнуть устройство; восстановление — FEL. Стоковые образы: <https://www.magcubic-support.com/xw>.

Дальше: [Приложения](../Apps/README.md)
