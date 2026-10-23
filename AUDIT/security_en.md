# BADBOX 2.0 and Security of HY350 Max

← [To index](../README.md) · [Audit index](README.md)

The HY350 Max firmware contains a dropper matching the **BADBOX 2.0** family: `com.hy.storeos`. On this unit it has system UID, package install/delete permissions, `BootReceiver`, and a silent-install channel at `appstore.hanychx.com`. Active residential-proxy (SOAX) or device impersonation as `ADT-3` was not observed on this unit: those are findings from public reports on other revisions.

Key finding: **the dropper here is named `com.hy.storeos`**, not `com.htc.storeos` as in the public report. This is the same family, but different names and a different OTA channel. Removing only the user-space APK does not solve the problem: the factory copy lives in `/product`, and the update lives in `/data`.

## What Is Installed

### `com.hy.storeos` — dropper

| Parameter | Value |
| --- | --- |
| Factory path | `/product/app/HY_StoreOs_QZ/HY_StoreOs_QZ.apk` |
| Current path | `/data/app/~~.../com.hy.storeos-.../base.apk` |
| Type | `UPDATED_SYSTEM_APP` (updated system app) |
| UID | 1000, `android.uid.system` |
| Version in `/product` | `versionCode=127`, `versionName=2608201644` |
| Version in `/data` | `versionCode=135`, `versionName=2609042030` |
| Installed | 22.10.2026 21:35:31 (update after first boot) |
| Signature | AOSP test key: `CN=Android, O=Android, OU=Android, L=Mountain View, ST=California, C=US` |
| SHA-256 APK from `/data` | `3f0d4dfea5905b109a537d0368d8ba8da7b492c8c814f4bd78f16be3dd389876` |
| SHA-256 APK from `/product` | `859558ab8a67021ab9499def7f0d8acbb3dd0103db173eaa680dd1b4ab16a0f5` |

`com.hy.storeos` and `com.hy.hyotaupdate` share more than a UID: their `dumpsys package` output has the same signature fingerprint `signatures:[b4addb29]`. They are parts of the same vendor OTA circuit.

Permissions that make it dangerous:

```
INSTALL_PACKAGES
DELETE_PACKAGES
MOVE_PACKAGE
WRITE_SECURE_SETTINGS
WRITE_DEVICE_CONFIG
CLEAR_APP_USER_DATA
CHANGE_COMPONENT_ENABLED_STATE
RECEIVE_BOOT_COMPLETED
REQUEST_INSTALL_PACKAGES
MANAGE_EXTERNAL_STORAGE
```

Components: `MainActivity`, `PrivacyPolicyActivity`, `BootReceiver`, `StartAppService`, `ExportService`, `PublicRequestService`, `FileProvider`. The `market:` scheme and `persist.sys.defappstore=com.hy.storeos` make it the default store.

Domains hardcoded in the APK:

- `https://appstore.hanychx.com/device/channel/check`
- `https://appstore.hanychx.com/device/sign/app/list`
- `https://appstore.hanychx.com/device/sign/app/update/check`
- `https://appstore.hanychx.com/device/app/install/report`
- `https://ota.hanychx.com/api/ota/check`
- `http://faq.hanychx.com/static/privacy_policy/...`

`appstore.hanychx.com` is the silent-install channel, and `ota.hanychx.com` is the post-reset restoration channel.

### `com.hy.hyotaupdate` — OTA

| Parameter | Value |
| --- | --- |
| Path | `/product/app/HY_OtaUpdate_QZ/HY_OtaUpdate_QZ.apk` |
| UID | 1000, `android.uid.system` |
| Version | `versionCode=10`, `versionName=2608191543` |
| Signature | AOSP test key |
| Domains | `https://ota.hanychx.com/api/ota/check`, `https://ota.hanychx.com/api/ota/upgradeResult` |

The package has `RECEIVE_BOOT_COMPLETED`, `RECOVERY`, `RESTART_PACKAGES`, `SYSTEM_ALERT_WINDOW` and services `DownloadService`, `ReBootService`, `UpgradeStateService`, `UpgradeRemindService`. This is not a "harmless updater" — it is a persistence mechanism.

### `com.android.vending` / Tubesky — check the signature

| Parameter | Value |
| --- | --- |
| Path | `/product/priv-app/Tubesky/Tubesky.apk` |
| Package | `com.android.vending` |
| Version | `34.1.09-23 [8] [PR] 501915548` |
| Signature on tested unit | **Google Inc.** (`O=Google Inc., OU=Android, CN=Android`) |
| GMS | `com.google.android.gms` is present |

A public report on a different revision calls Tubesky a "fake Play Store". On build `Projector_20260821.111618` the APK is signed by Google and looks like the real Play Store. **Do not delete `com.android.vending` blindly.** First check the certificate:

```sh
adb shell pm path com.android.vending
adb pull /product/priv-app/Tubesky/Tubesky.apk
unzip -p Tubesky.apk META-INF/CERT.RSA > cert.rsa
openssl pkcs7 -inform DER -in cert.rsa -print_certs -noout
```

If the certificate shows `O=Google Inc.` — this is Play Store. If `O=Android` (AOSP test key) or an unknown subject — this is a fake and can be deleted.

### What Not to Touch

`com.htc.magcubicos` (`/product/app/HY_MagcubicOS`, uid 1000) is the vendor launcher and all projector settings:

- `activity.settings.CorrectionActivity` — keystone;
- `activity.settings.ProjectActivity` — projection mode;
- `activity.settings.InitAngleActivity`;
- `activity.settings.MainSettingActivity`.

Deleting it breaks image settings and the home screen. The APK contains strings `appstore.hanychx.com`, `hmma.baidu.com`, `dxp.baidu.com` — telemetry, but the launcher itself is not a dropper. Leave it and block the domains at DNS.

### `hotacksu`

`/system/xbin/hotacksu` is a setuid-root binary named after the same vendor as `com.hotack.*` in public reports.

```sh
adb shell ls -lZ /system/xbin/hotacksu
# -rwsr-sr-x 1 root shell u:object_r:system_file:s0 ...
```

On the tested build, calling from shell:

```sh
adb shell hotacksu 0 id
# hotacksu: setgid failed: Operation not permitted
```

A public report claims that on another revision `hotacksu 0 id` from shell gives root. On this build the direct call did not work, but the binary is still in the system and SELinux here is `Permissive`. Treat it as a backdoor, even if the specific call does not succeed on your unit.

### Packages That Appear Only as Strings

The public report lists `com.htc.expandsdk`, `com.htc.eventuploadservice`, `com.hotack.writesn`, `com.hotack.silentsdk`, `com.htc.htclauncherhighenglishd08`. On the tested unit their APKs were not found. If they are present on your device — remove them.

## Checking Your Device

```sh
# 1. Packages and paths
adb shell pm list packages -f | grep -Ei 'storeos|hyota|htc|hotack|vending|tubesky|magcubic|screensaver'

# 2. UID, signature, permissions
adb shell dumpsys package com.hy.storeos | head -120
adb shell dumpsys package com.hy.hyotaupdate | head -100
adb shell dumpsys package com.android.vending | grep -A30 'Package \[com.android.vending\]'

# 3. Factory copies
adb shell ls -l /product/app/HY_StoreOs_QZ /product/app/HY_OtaUpdate_QZ /product/priv-app/Tubesky

# 4. Listeners
adb shell ss -tunlp

# 5. What is going out on its own
adb shell ss -tunp
```

Signs of this variant:

- `com.hy.storeos` with `sharedUser=android.uid.system` and `UPDATED_SYSTEM_APP`;
- `versionName` in the form `2609...`, install date after build date;
- `persist.sys.defappstore=com.hy.storeos`;
- requests to `*.hanychx.com`;
- `com.hy.hyotaupdate` with `RECOVERY`.

## IOCs

### Domains

Confirmed on this device:

```
hanychx.com
appstore.hanychx.com
ota.hanychx.com
faq.hanychx.com
```

Public IOCs for HY350 Max / BADBOX 2.0 (not confirmed on this unit):

```
api.pixelpioneerss.com
sta.smartinnovate.net
bur.thedynamicleap.com
kkoip.com
soax.com
event-api.aodintech.com
pb-api.aodintech.com
store-api.aodintech.com
cdn-store.aodintech.com
ota.triplesai.com
otaapi.triplesai.com
ota-api.aodintech.com
shortx.srafx.com
hotack.com
int.vaicore.site
int.dewrain.life
int.akisinn.info
```

Telemetry and analytics (optional to block, not C2):

```
statsigapi.net
app-measurement.com
hmma.baidu.com
dxp.baidu.com
```

Candidates from public reports, not analyzed:

```
ip4exordir.shop
zeromedia.cloud
zeasn.tv
```

Only `*.hanychx.com` domains were confirmed on the tested unit. Full lists are in [iocs/](../iocs/).

### IPs

```
8.218.163.124      # appstore.hanychx.com
47.86.211.252      # ota.hanychx.com / faq.hanychx.com
47.96.145.84       # hanychx.com
139.199.190.220    # OTA fallback (Tencent Cloud)
128.12.122.35      # C2 geolocation
103.124.165.222    # hardcoded C2
64.32.27.247       # api.pixelpioneerss.com
```

IPs can change. Block both domains and hardcoded IPs: DNS filtering will not catch direct IP connections.

### Functional Domains That Must Not Be Blocked Permanently

`server.mphotool.com` is needed to activate AirPlay/DLNA after flashing. Allow it for ~30 seconds, wait for receivers to appear, then you can block it. If blocked before activation, receivers stay off and logcat shows `ProcActive: getActivated() isActived=0`.

## Removal

### Option 1. Quick, via ADB (incomplete)

```sh
# Hide dropper for user 0
adb shell pm uninstall --user 0 com.hy.storeos

# Disable OTA so it does not restore the dropper
adb shell pm disable-user --user 0 com.hy.hyotaupdate

# Verify
adb shell pm list packages | grep -E 'storeos|hyota'
adb shell pm list packages -d
```

If `pm uninstall` did not work:

```sh
adb shell pm disable-user --user 0 com.hy.storeos
```

To downgrade to factory version (removing at least the `/data` copy):

```sh
adb shell pm uninstall-system-updates com.hy.storeos
```

**Limitations:**

- factory copy remains in `/product`;
- `com.hy.hyotaupdate` may restore the update if not disabled;
- after factory reset the dropper is active again;
- `persist.sys.defappstore` still points to the removed package, store errors possible.

### Option 2. Complete Removal from Image

Only this method removes the dropper permanently. You need `update.img` for your build, `lpunpack`/`lpmake`, `debugfs`, and rebuilding the Allwinner container. Step-by-step in external guides: [HY300Pro → Root](https://github.com/Vadim000009/HY300ProByMagcubic/tree/main/Root) (same H726 platform) and [hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal).

Briefly:

```sh
# product_a.img — where APKs live
debugfs -w -R "rm /app/HY_StoreOs_QZ/HY_StoreOs_QZ.apk" product_a.img
debugfs -w -R "rm /app/HY_OtaUpdate_QZ/HY_OtaUpdate_QZ.apk" product_a.img
```

Before flashing, disable AVB verification (`vbmeta` flags `0 -> 3`) and set the date forward in `sunxi_version.fex`, otherwise the bootloader refuses the image.

## Network Isolation

Even after cleaning the device:

- put the projector on a separate **IoT VLAN**;
- block **IoT → main LAN**;
- set DHCP-DNS to Pi-hole with the [denylist](../iocs/pihole-denylist.txt);
- block outbound `:53` and `:853` from the projector at the gateway, so it cannot bypass DNS;
- block hardcoded IPs from [iocs/ips.txt](../iocs/ips.txt) on the firewall;
- do not block `server.mphotool.com` before casting activation.

Example rules on a Linux gateway (replace `192.168.1.50` with the projector's IP):

```sh
PROJ=192.168.1.50
for ip in 8.218.163.124 47.86.211.252 47.96.145.84 \
          139.199.190.220 128.12.122.35 103.124.165.222 64.32.27.247; do
  iptables -I FORWARD -s "$PROJ" -d "$ip" -j DROP
done
```

On a dnsmasq router add:

```conf
address=/hanychx.com/0.0.0.0
address=/aodintech.com/0.0.0.0
address=/triplesai.com/0.0.0.0
address=/pixelpioneerss.com/0.0.0.0
address=/smartinnovate.net/0.0.0.0
address=/thedynamicleap.com/0.0.0.0
address=/kkoip.com/0.0.0.0
address=/soax.com/0.0.0.0
address=/srafx.com/0.0.0.0
address=/hotack.com/0.0.0.0
address=/vaicore.site/0.0.0.0
address=/dewrain.life/0.0.0.0
address=/akisinn.info/0.0.0.0
```

After editing, reload dnsmasq or the rules will not apply. Check that a random subdomain returns `0.0.0.0`:

```sh
nslookup random.hanychx.com 192.168.1.1
```

## What Else to Disable

Already disabled on the tested unit:

```
com.toofifi.lineserver
com.htc.hyk_pcba
com.mphotool.usbcastserver
```

If you do not use the built-in screensaver, you can disable `com.htc.screensaver`. Do not disable `com.htc.magcubicos` — keystone and image settings will be gone with it.

## Caveats

- One `ss` snapshot proves nothing. Malware can sleep for days. Run [netwatch](../Scripts/netwatch.sh) for several days.
- Firmware composition changes. Whether `com.htc.storeos` or `com.hy.storeos` is present depends on the build.
- `SELinux=Permissive` and an unlocked bootloader are factory state, not a result of your actions. They make malicious code persistence easier.
- AOSP test key alone is not a malware indicator: vendor system apps are signed with it too. Look at UID, permissions, domains, and behavior.

---

Next: [Root](../Root/README.md)