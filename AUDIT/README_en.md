# Device Audit

← [To index](../README.md)

The HY350 Max audit consists of four independent checks:

1. **Packages and signatures.** What is installed, from where, under which UID, and with what permissions.
2. **Network listeners.** Which ports are open externally and who they belong to.
3. **Outgoing traffic.** Where the device goes on its own, without user action.
4. **Bootloader and SELinux.** How easily malicious code can persist and what can be fixed with firmware changes.

## Documents

- [BADBOX 2.0 and Security](security.md) — main section: `com.hy.storeos` dropper, OTA, IOCs, removal, network isolation.

## Quick Results on Tested Unit

- Android 14, build `Projector_20260821.111618`, board `h726_p1`, Allwinner H726.
- `SELinux` — `Permissive`.
- `ro.boot.verifiedbootstate=orange`, `ro.boot.flash.locked=0`, `veritymode=enforcing`.
- `com.hy.storeos` — updated system app, uid 1000 (`android.uid.system`), AOSP test key signature, install and delete package permissions.
- `com.hy.hyotaupdate` — system OTA, uid 1000, domain `ota.hanychx.com`.
- `com.android.vending` (`Tubesky`) on this build is signed by Google Inc.; GMS is present. This differs from the public report, where Tubesky is called a fake.
- `com.htc.magcubicos` — vendor launcher and projector settings, must not be deleted.
- At the time of the snapshot there were no persistent connections to known C2; primary external traffic was Google/Play/GMS.

Details, commands, and caveats are in [security.md](security.md).