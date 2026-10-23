# Memory

← [To index](../README.md)

HY350 Max: 2 GB RAM and zram. Below is a snapshot from the tested device and packages that can be disabled.

## Snapshot on Tested Unit

```
$ adb shell free -m
              total        used        free      shared  buff/cache   available
Mem:           1965        1763         202          10          315         927
Swap:          1768         286        1482
```

- total RAM: 2012716 KB (~1965 MiB);
- `MemAvailable`: 949076 KB (~927 MiB);
- zram: 1768 MiB, 286 MiB used;
- `/data`: 12 GB, ~1.5 GB used.

This is **one snapshot after boot**, not a benchmark. On a different build with a different set of apps, the numbers will differ.

## What to Disable

Candidates on the tested build:

```sh
# Already disabled
com.toofifi.lineserver
com.htc.hyk_pcba
com.mphotool.usbcastserver

# Can disable: built-in screensaver is not needed
adb shell pm disable-user --user 0 com.htc.screensaver
```

Do not disable:

- `com.htc.magcubicos` — launcher and image settings;
- `com.android.vending` — real Play Store on this build;
- `com.google.android.gms` — without it, no Play and limited push;
- `com.android.networkstack` — you will lose network.

---

Next: [Scripts](../Scripts/README.md)