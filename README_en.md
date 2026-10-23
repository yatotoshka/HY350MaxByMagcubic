# HY350 Max Projector (Magcubic, Allwinner H726)

Reverse-engineering, audit, cleanup, and customization guide for the **Magcubic HY350 Max** projector on **Allwinner H726** with Android 14.

> **Based on.** Structure, methodology, and format are derived from [Vadim000009/HY300ProByMagcubic](https://github.com/Vadim000009/HY300ProByMagcubic) ("HY300Pro projector reverse-engineering and modification"). Text is rewritten for HY350 Max; BADBOX 2.0 and firmware cleanup data references [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal). This is not official Magcubic documentation.

The repository documents one tested HY350 Max instance and public findings for this model. Verification was performed on 23.10.2026 on build **`Projector_20260821.111618`** (Android 14, board `h726_p1`). Vendor firmware composition varies between builds, so **check your own device** — do not trust this report blindly.

---

## Quick Start: Making the Projector Usable

Short guide without reading the full audit:

1. **Get ADB.** Install Aptoide → Hidden Settings (`com.yjlink.secretsettings`) → Developer options → Wireless debugging. Pairing and commands — in [ADB](ADB/README.md).
2. **Install a third-party launcher.** For example, Projectivy, and set it as home:

   ```sh
   adb shell cmd package set-home-activity com.spocky.projengmenu/.ui.home.MainActivity
   adb shell setprop persist.sys.homePackage com.spocky.projengmenu
   ```

   The second `setprop` locks Projectivy as the vendor `homePackage`, but on cold boot the firmware may still show MagcubicOS first. After launching any app and pressing Home, Projectivy opens. This is a quirk of this firmware; it does not affect operation.

   **Rollback:** restore MagcubicOS:

   ```sh
   adb shell cmd package set-home-activity com.htc.magcubicos/.activity.MainActivity
   adb shell setprop persist.sys.homePackage com.htc.magcubicos
   ```

3. **Switch the store to Google Play.** On this build `com.android.vending` is the real Google-signed Play Store with GMS installed. There is no "default store" setting in the UI, and the stock store button in MagcubicOS is tied to `com.hy.storeos`.

   - `setprop persist.sys.defappstore com.android.vending` works without root and survives reboot, but this alone is not enough: the store button in MagcubicOS still directly launches `com.hy.storeos`.
   - Therefore disable the dropper and launch Play Store directly:

     ```sh
     adb shell pm disable-user --user 0 com.hy.storeos
     adb shell monkey -p com.android.vending -c android.intent.category.LAUNCHER 1
     ```

     On `disable-user` error: `adb shell pm uninstall --user 0 com.hy.storeos`. After this, `market://` links are handled by Play Store. The store button in MagcubicOS may stop working.

   **Rollback:** restore the property if abandoning Play Store:

   ```sh
   adb shell setprop persist.sys.defappstore com.hy.storeos
   ```

4. **Disable the vendor OTA updater** `com.hy.hyotaupdate`. It contacts `ota.hanychx.com` and after a reset or update may restore/update `com.hy.storeos`:

   ```sh
   adb shell pm disable-user --user 0 com.hy.hyotaupdate
   ```

5. **Full cleanup** requires reflashing: [Root](Root/README.md). Factory reset does not solve the problem. On the current build I skipped this — for daily use, steps 3 and 4 above are sufficient.

---

## Device Overview

HY350 Max is an Allwinner H726 projector with 2 GB RAM, 16 or 32 GB eMMC, and Android 14. The factory firmware includes `com.hy.storeos` with **BADBOX 2.0** indicators.

The device pretends to be a Rockchip RK3566: `getprop` contains `rk3566_rgo`, `hermes`, `rockchip`. This is a lie inherited from someone else's AOSP config. The real SoC is **Allwinner H726** (`sun50iw15p1`), confirmed by `ro.boot.hardware`, `/proc/device-tree/compatible`, and `ro.build.flavor=h726_p1-user`.

### Specifications

| Component | What the device reports |
| --- | --- |
| SoC | Allwinner H726, 4× Cortex-A53, platform `sun50iw15p1` |
| Userspace | 32-bit, `armeabi-v7a` (`ro.product.cpu.abilist64=[]`) |
| RAM | 2 GB (`ro.boot.dramsize=2048`), DRAM frequency 792 MHz, plus ~1.7 GB zram |
| ROM | 16 GB eMMC on tested unit; 32 GB also exists, `/data` ~12 GB |
| OS | Android 14 (SDK 34), build `Projector_20260821.111618` |
| Shell | BigdroidOS 3.0.3.010245, DroidBoost 2.1.7, MagcubicOS |
| Display | 1920×1080, 60 Hz, 320 dpi |
| Wi-Fi | AIC, driver `rwnx 20250410-009-6.4.3.0`, firmware 6.9.1.1 |
| Ports | HDMI, USB-A, IR receiver, Bluetooth remote (per public data for this model) |
| Service mode | Allwinner FEL, recovery via PhoenixSuit/PhoenixUSBPro |
| Partitions | A/B: `boot_a/b`, `init_boot_a/b`, `vendor_boot_a/b`, `super`, `vbmeta*_a/b` |

The Lumina API model name (`:8899`) may differ from the build: the tested unit shows `name=rk3566_rgo`, `model=h726-2`, `model_label=H726 Focus`, `version=v3.0.0`. Meanwhile the firmware reports `ro.build.product=h726-p1` and `ro.build.flavor=h726_p1-user`. For image selection, trust the **build and board**, not the `model` string from Lumina.

### Power Consumption and Heat

According to user reports, "normal" power mode is not recommended: the panel is prone to overheating. "Power saving" is recommended. Ceiling mount with upward tilt makes cooling worse, so power saving is especially desirable. The tested unit uses power saving mode: the projector is pointed upward.

### Security Summary

No signs of active infection or persistent C2 channel were found on the tested unit: known dropper packages were verified, outgoing connections were primarily to Google and local clients. However, this firmware cannot be considered fully trusted. Built-in `com.hy.storeos` has BADBOX 2.0 dropper characteristics: system UID, package install/delete permissions, `BootReceiver`, and `appstore.hanychx.com` channel. Similar firmware has been found in botnets before, so after disabling `com.hy.storeos`/`com.hy.hyotaupdate` and blocking domains at DNS, the instance can be considered safe for normal use — but not "secure by default".

---

## Sections

| # | Section | Contents |
| --- | --- | --- |
| 1 | [ADB and Access](ADB/README.md) | USB, Wi-Fi debugging, pairing, handling stuck authorization |
| 2 | [BADBOX 2.0 Audit](AUDIT/security.md) | `com.hy.storeos`, `com.hy.hyotaupdate`, IOCs, traffic verification, isolation |
| 3 | [Root](Root/README.md) | Why root requires reflashing and where to find instructions |
| 4 | [Apps](Apps/README.md) | What to install, what not to touch, 32-bit APKs, casting, Home Assistant |
| 5 | [Memory](Memory/README.md) | 2 GB measurements, zram, what to disable |
| 6 | [IOCs](iocs/) | Domains, IPs, packages, Pi-hole denylist |
| 7 | [Scripts](Scripts/README.md) | Info collection, netwatch, debloat, IOC blocking |
| 8 | [Instance Data](docs/instance.md) | De-identified report of the tested device |

---

## Sources and Credits

- [Vadim000009/HY300ProByMagcubic](https://github.com/Vadim000009/HY300ProByMagcubic) — structure, methodology, ADB/Root/Overclock/Memory/AUDIT/Apps sections.
- [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal)

## License

Documentation — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), scripts — MIT. Details in [LICENSE](LICENSE).