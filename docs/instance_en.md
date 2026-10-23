# Tested Unit

← [To index](../README.md)

De-identified report for one HY350 Max. MAC, serial number, LAN IP, and credentials are not published.

## Identification

| Parameter | Value |
| --- | --- |
| Model | Magcubic HY350 Max |
| Board / firmware | `h726_p1` (`ro.build.flavor=h726_p1-user`, `ro.build.product=h726-p1`) |
| SoC | Allwinner H726, `sun50iw15p1`, 4× Cortex-A53 |
| Userspace | 32-bit, `armeabi-v7a` |
| Kernel | Linux 5.15.167, `armv7l` |
| Android | 14 (SDK 34) |
| Build | `Projector_20260821.111618` |
| Build date | 21.08.2026 11:13 CST |
| Shell | BigdroidOS 3.0.3.010245, DroidBoost 2.1.7 |
| Lumina API model | `rk3566_rgo` / `h726-2` / `H726 Focus` / API v3.0.0 |
| RAM | 2 GB, DRAM 792 MHz, zram ~1.7 GB |
| ROM | 16 GB, `/data` ~12 GB |
| Display | 1920×1080, 60 Hz, 320 dpi |
| Wi-Fi | AIC rwnx 6.4.3.0, firmware 6.9.1.1 |
| SELinux | `Permissive` |
| Bootloader | `ro.boot.flash.locked=0`, `ro.boot.verifiedbootstate=orange` |
| dm-verity | `enforcing` |
| Active slot | `_a` |

## Key Packages

| Package | Path | UID | Version | Signature |
| --- | --- | --- | --- | --- |
| `com.hy.storeos` | `/product/app/HY_StoreOs_QZ`, update in `/data/app` | 1000 (system) | 127 → 135 (`2608201644` → `2609042030`) | AOSP test key |
| `com.hy.hyotaupdate` | `/product/app/HY_OtaUpdate_QZ` | 1000 (system) | 10 (`2608191543`) | AOSP test key |
| `com.htc.magcubicos` | `/product/app/HY_MagcubicOS` | 1000 (system) | `1.0.14` | AOSP test key |
| `com.android.vending` | `/product/priv-app/Tubesky` | 10055 | `34.1.09-23` | **Google Inc.** |

`com.hy.storeos` is installed as `UPDATED_SYSTEM_APP` on 22.10.2026 at 21:35:31. This happened after first boot: the factory version is in `/product`, the updated one in `/data`.

## APK Hashes

```
3f0d4dfea5905b109a537d0368d8ba8da7b492c8c814f4bd78f16be3dd389876  com.hy.storeos (from /data)
859558ab8a67021ab9499def7f0d8acbb3dd0103db173eaa680dd1b4ab16a0f5  HY_StoreOs_QZ.apk (from /product)
8887334123d450a6dc7b5d82d49688f9319b14f27d9c5686301d4f2cf4ed13ea  HY_OtaUpdate_QZ.apk
4b6d959d97f0222cedce87684dd64eeefbbc0ebec141208600aaaa0d70650008  Tubesky.apk
9f97199b0f7701ad57ccad361c1df41c6585d2e5e74d52e258b005642976052e  HY_MagcubicOS.apk
```

## `com.hy.storeos` Components

- `com.hy.storeos/.MainActivity`
- `com.hy.storeos/.PrivacyPolicyActivity`
- `com.hy.storeos/.receiver.BootReceiver`
- `com.hy.storeos/.service.StartAppService`
- `com.hy.storeos/.service.ExportService`
- `com.hy.storeos/.service.PublicRequestService`
- `com.hy.storeos.fileprovider`

Permissions: `INSTALL_PACKAGES`, `DELETE_PACKAGES`, `MOVE_PACKAGE`, `WRITE_SECURE_SETTINGS`, `WRITE_DEVICE_CONFIG`, `CLEAR_APP_USER_DATA`, `CHANGE_COMPONENT_ENABLED_STATE`, `RECEIVE_BOOT_COMPLETED`, `MANAGE_EXTERNAL_STORAGE`.

## Network Listeners at Time of Check

| Port | Who/What |
| --- | --- |
| 1234 | `tvserver` |
| 5555 | `adbd` (Wi-Fi debugging was enabled) |
| 7889, 7890, 8890 | Miracast/toofifi |
| 8899 | Lumina API (no auth) |
| 9528 | AirPlay/AirTunes |
| 10008, 10012, 10013 | Miracast/toofifi |
| 32017, 32018, 32019, 55556 | AirPlay |
| 44075 | Jetty, bound to LAN address |
| 62110 | unknown listener, bound to LAN address |
| random | temporary ADB pairing port (at time of check) |

Earlier in the audit FTP `:8841` was open; at the time of re-check it was not listening. Do not assume a port is permanently closed: check `ss -tunlp`.

## Active Connections (Snapshot)

At the time of check, external traffic went to Google/Play/GMS and local clients; there were no persistent connections to known C2. This is **one snapshot**, not proof of cleanliness.

## Disabled Packages

```
com.toofifi.lineserver
com.htc.hyk_pcba
com.mphotool.usbcastserver
```

## Quirks of This Build

- `com.android.vending` is signed by Google Inc. and is the real Play Store; GMS is installed. This differs from the public report, where Tubesky is called a fake.
- `hotacksu` is present, but `hotacksu 0 id` from shell returns `setgid failed: Operation not permitted`.
- `ro.product.model` and `ro.board.platform` lie about Rockchip; the real platform is Allwinner `sun50iw15p1`.
- `/oem` is mounted with `media_data` (`mmcblk0p26`), although a public report claims the `oem` partition does not exist.
- `persist.sys.defappstore=com.hy.storeos`; `setprop persist.sys.defappstore com.android.vending` works without root, but the `OPEN_APP_STORE` command still opened `com.hy.storeos/.SettingsActivity`.
- `market://` before disabling `com.hy.storeos` has no default handler: the system shows a choice between `com.android.vending` and `com.hy.storeos`. After disabling storeos, links resolve to Play Store.
- `ro.build.type=user`, `ro.debuggable=0`, `adb root` returns `adbd cannot run as root in production builds`; `ro.boot.verifiedbootstate=orange`, `ro.boot.flash.locked=0`. Root is only possible via patching `init_boot`/`system` and flashing via FEL.
- `persist.sys.homePackage=com.htc.magcubicos`: vendor `system_server` starts this package on boot. After switching to Projectivy, on cold boot the stock launcher may still open first; after launching any app and pressing Home, Projectivy opens. This is expected behavior for this build.
- `persist.sys.defappstore=com.android.vending` and `pm disable-user` for `com.hy.storeos`/`com.hy.hyotaupdate` survive reboot. After this, `market://` resolves to `com.android.vending`, not `com.hy.storeos`.