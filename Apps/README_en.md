# Apps and Daily Use

← [To index](../README.md)

HY350 Max is Android 14 with 2 GB RAM and a 32-bit userspace. It will not become Android TV in the full sense: there is no Android TV Remote Service, and part of the interface depends on vendor `com.htc.magcubicos`. But you can install a normal launcher, file manager, media player, and streaming client.

## Main Limitation: 32-bit Only

```
ro.product.cpu.abilist = armeabi-v7a,armeabi
ro.product.cpu.abilist64 = []
```

Any APK built for `arm64-v8a` only will not install. The error `INSTALL_FAILED_NO_MATCHING_ABIS` means exactly this. Look for `armeabi-v7a` builds.

## App Store

There are two "stores" on the device:

1. **`com.hy.storeos`** — vendor dropper. By default `persist.sys.defappstore` points to it. After firmware cleanup it will not be there. Do not use it.
2. **`com.android.vending`** — on the tested build this is the real Google-signed Play Store with GMS installed. After removing Tubesky, Play Store disappears.

Play Store works after signing into a Google account. If GMS/Play are not working, alternatives:

- **F-Droid** — open-source apps, no Google;
- **Aurora Store** — Play Store client without Google services (note Google's ToS);
- **Aptoide** — alternative store;
- manual APK installation.

## Launcher

`com.htc.magcubicos` is not just a launcher — it also handles projector settings:

- keystone (`CorrectionActivity`);
- projection mode (`ProjectActivity`);
- initial angle (`InitAngleActivity`);
- main settings (`MainSettingActivity`).

**Do not delete it.** To use a different home screen, keep MagcubicOS installed and set a new launcher as home.

### How to Switch to a Third-Party Launcher

Check the current HOME and all registered launchers:

```sh
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

Example for Projectivy Launcher (`com.spocky.projengmenu`):

```sh
adb shell cmd package set-home-activity com.spocky.projengmenu/.ui.home.MainActivity
```

On this firmware, `set-home-activity` alone is not enough: after reboot, vendor `system_server` starts the package from `persist.sys.homePackage`, which defaults to `com.htc.magcubicos`. The stock launcher may become home again. To lock Projectivy:

```sh
adb shell setprop persist.sys.homePackage com.spocky.projengmenu
```

Verification and rollback:

```sh
adb shell getprop persist.sys.homePackage
adb shell setprop persist.sys.homePackage com.htc.magcubicos
```

### Behavior After Reboot

Even with `persist.sys.homePackage=com.spocky.projengmenu`, on cold boot the first screen may be MagcubicOS: the vendor launcher starts before the HOME role is applied. After launching any app and pressing Home, Projectivy opens. This is a quirk of the firmware, not a misconfiguration; it does not affect operation.

Do not touch `persist.sys.initPackage`: it is related to `InitAngleActivity` and initial angle setup.

To fully restore MagcubicOS:

```sh
adb shell cmd package set-home-activity com.htc.magcubicos/.activity.MainActivity
adb shell setprop persist.sys.homePackage com.htc.magcubicos
```

If there is no launcher choice when pressing Home:

```sh
adb shell cmd package clear-package-preferred-activities com.htc.magcubicos
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

Then press Home and select the desired launcher. Image settings still open through MagcubicOS.

## Casting: AirPlay, DLNA, Miracast

The system includes:

- `com.mphotool.airplay`;
- `com.mphotool.dlna`;
- `com.mphotool.usbcastserver` (disabled on tested unit);
- `com.htc.samescreen`;
- Miracast stack `com.softwinner.miracastReceiver` / `com.android.toofifi`.

AirPlay/DLNA activation is stored in `/data` and tied to `server.mphotool.com`. After flashing or a reset it is lost. Allow `server.mphotool.com` for ~30 seconds, wait for receivers to appear, then you can block it again.

Verification:

```sh
adb shell settings get global ft_activated_data
adb shell logcat | grep -i 'ProcActive\|mphotool'
```

The log entry `getActivated() isActived=0` means activation is missing.

## Home Assistant

The firmware lacks Android TV Remote Service, so the official `androidtv` integration via the Android TV protocol will not work. A working option is Home Assistant ADB integration:

1. Enable Wi-Fi debugging.
2. Add the `androidtv` integration in ADB mode.
3. Specify IP and port `5555`.
4. Confirm the RSA key on the projector.

Remote commands can also be called directly:

```sh
adb shell input keyevent KEYCODE_HOME
adb shell input keyevent KEYCODE_BACK
adb shell input keyevent KEYCODE_DPAD_OK
```

## Lumina API

On `:8899` there is an HTTP API without authentication:

```sh
curl http://192.168.1.50:8899/api/v1/device
```

It supports `NAV_*`, `SETTINGS`, `TAKE_SCREENSHOT`, `OPEN_DEVELOPER`, `OPEN_FILE_MGR`, `OPEN_APP_MGR`, `FACTORY_RESET`, and other commands. Useful for automation, but **dangerous**: anyone on the LAN can open settings or reset the device. After setup, close the port from strangers or isolate the projector.

## What Not to Do

- Do not delete `com.htc.magcubicos` — you will lose keystone and image settings.
- Do not delete `com.android.vending` before checking the signature: on this build it is the real Play Store.
- Do not install arm64-only APKs.
- Do not leave `:5555`, `:8899`, and FTP open on the main network.
- Do not block `server.mphotool.com` before casting activation.

---

Next: [Memory](../Memory/README.md)