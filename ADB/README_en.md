# ADB and Device Access

← [To index](../README.md)

This is the starting point. Without ADB you cannot check packages, signatures, ports, or bootloader state. Root is not required for auditing.

## Enabling Debugging

On the tested build the standard path via "About device" is blocked: the UI does not allow reaching the option. ADB is enabled as follows:

1. Install **Aptoide**.
2. From Aptoide install **Hidden Settings** (`com.yjlink.secretsettings`).
3. In Hidden Settings open **Developer options**.
4. Enable **Wireless debugging** (and **USB debugging** if needed).

> Due to UI quirks, Aptoide and Hidden Settings are hard to operate with a remote alone: some screens do not respond to D-pad. You will need to combine D-pad with mouse emulation — USB mouse or a mouse app. Be prepared for this.

USB requires a USB-A ↔ USB-A cable (or OTG adapter if the port works as a device). On first connection an RSA authorization dialog appears — accept it.

```sh
adb devices -l
# 192.168.1.50:5555  device  product:rk3566_rgo model:rk3566_rgo ...
```

If the device shows `unauthorized` but the dialog does not appear — see [If Authorization Stalls](#if-authorization-stalls).

## ADB over Wi-Fi (Standard Pairing)

Starting with Android 11, the standard approach is Wi-Fi debugging with a pairing code, not `adb tcpip 5555`. On the tested HY350 Max build this works.

On the projector: "Wireless debugging" → "Pair device with pairing code". An `IP:port` and 6-digit code will appear.

On the computer:

```sh
adb pair 192.168.1.50:<pair_port> <code>
# Successfully paired to 192.168.1.50:<pair_port> [guid=adb-...]

adb mdns services
# _adb-tls-connect._tcp  192.168.1.50:5555

adb connect 192.168.1.50:5555
adb devices -l
```

Pairing port and connection port are **different**. Pairing port is usually random, while `adb connect` often uses `:5555`. If `adb mdns services` shows nothing, check the port on the "Wireless debugging" screen or try `:5555`.

After pairing, the computer saves the key. Switching computers requires pairing again.

> On the tested unit pairing succeeded immediately and `adb connect :5555` came up without a confirmation prompt. This is not guaranteed on a different revision.

## ADB over Network Without Pairing

Classic approach:

```sh
adb tcpip 5555
adb connect 192.168.1.50:5555
```

`adb tcpip` restarts `adbd` and may break the USB link. If the projector has no network at that moment, you lose both transports. First make sure Wi-Fi is working and keep a remote/mouse handy.

For a persistent port (requires root or firmware editing):

```sh
setprop persist.adb.tcp.port 5555
```

But on stock build `ro.adb.secure=1` and `ro.debuggable=0`, so do not rely on this without editing `build.prop`.

## If Authorization Stalls

A public report on HY350 Max describes a revision where `adbd` listens on `:5555`, TCP connection establishes, but the authorization dialog is suppressed and the handshake hangs. Standard pairing did not help there. The author's solution was image editing:

```properties
ro.secure=0
ro.adb.secure=0
ro.debuggable=1
service.adb.tcp.port=5555
persist.adb.tcp.port=5555
```

in `/system/build.prop` inside `system_a.img`.

**This is a serious security downgrade.** Such a projector lets anyone on the LAN into root ADB without a password. Only do this in an isolated VLAN and never distribute such an image.

On the tested build `Projector_20260821.111618` this was not needed: standard Wi-Fi debugging worked. If you have a different build, first try pairing, then USB, and only then image editing.

## Useful Audit Commands

```sh
# packages and paths
adb shell pm list packages -f
adb shell pm list packages -3
adb shell pm list packages -d

# package details, UID, signature, permissions
adb shell dumpsys package com.hy.storeos
adb shell dumpsys package com.hy.hyotaupdate
adb shell dumpsys package com.android.vending

# who is listening on ports
adb shell ss -tunlp

# active connections
adb shell ss -tunp

# properties, screen, memory
adb shell getprop
adb shell wm size
adb shell free -m
adb shell df -h

# SELinux and AVB
adb shell getenforce
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.veritymode
```

## Disable OTA Before Starting

On HY350 Max the OTA package is named `com.hy.hyotaupdate` and runs under `android.uid.system`. It may restore stock components and reset your changes:

```sh
adb shell pm disable-user --user 0 com.hy.hyotaupdate
```

Verification:

```sh
adb shell pm list packages -d
```

Side effect: you will no longer receive stock updates. For a device with factory BADBOX this is a plus, but decide for yourself.

## Hygiene

- Do not leave `:5555` open on the main network when not needed.
- After work, turn off "Wireless debugging".
- Do not publish the serial number, MAC, or real LAN IP.
- If ADB is not needed constantly, only use it from an isolated computer/VLAN.

---

Next: [BADBOX 2.0 Audit](../AUDIT/security.md)