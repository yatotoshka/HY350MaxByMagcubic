# Scripts

← [To index](../README.md)

Scripts are intentionally simple: you can read them in full before running. None contain passwords, MACs, serial numbers, or IPs of the tested device. `collect_info.sh` outputs IPs from `ss` — check the output before publishing.

## On the Computer

| File | What It Does | Used In |
| --- | --- | --- |
| [`collect_info.sh`](collect_info.sh) | collects de-identified ADB audit report | audit, issue, build comparison |
| [`debloat.sh`](debloat.sh) | hides/disables known BADBOX packages | [Audit](../AUDIT/security.md) |
| [`block_iocs.sh`](block_iocs.sh) | iptables rule template for hardcoded C2 IPs | [Audit](../AUDIT/security.md) |

### `collect_info.sh`

```sh
./collect_info.sh
# or
SERIAL=192.168.1.50:5555 ./collect_info.sh
```

Prints build, hardware, AVB/SELinux, display, memory, packages, listeners, and connections. **Check the output before publishing**: `ss` will contain the projector's local IP and addresses of other devices.

### `debloat.sh`

```sh
./debloat.sh --dry-run     # show commands only
./debloat.sh --apply       # execute
./debloat.sh --restore     # re-enable packages
```

What it does:

- `pm uninstall --user 0` and `pm disable-user --user 0` for `com.hy.storeos`, `com.hy.hyotaupdate`, `com.htc.storeos`, `com.htc.htcotaupdate`;
- **does not touch** `com.android.vending` and `com.htc.magcubicos`;
- prints the result and reminds that factory copies remain in `/product`.

`--apply` is a temporary measure. Complete removal requires image editing, see [Root](../Root/README.md).

### `block_iocs.sh`

Run on the gateway/router, not on the projector:

```sh
sudo ./block_iocs.sh 192.168.1.50 --apply
sudo ./block_iocs.sh 192.168.1.50 --remove
```

Reads IPs from [`../iocs/ips.txt`](../iocs/ips.txt), adds `DROP` to `FORWARD` for projector-to-IP traffic. Rules do not survive router reboot; save them with the firmware's tools. If you have nftables/firewalld — adapt accordingly.

## On the Device

| File | What It Does | Used In |
| --- | --- | --- |
| [`netwatch.sh`](netwatch.sh) | passive outgoing connection log | [Audit](../AUDIT/security.md) |

```sh
adb push netwatch.sh /data/local/tmp/
adb shell 'nohup sh /data/local/tmp/netwatch.sh >/dev/null 2>&1 &'

# view log
adb shell 'tail -n 50 /data/local/tmp/netwatch.log'

# stop
adb shell 'ps -A -o PID,ARGS | grep netwatch'
adb shell 'kill -9 <pid>'
```

Writes to `/data/local/tmp/netwatch.log`, polls every 20 seconds, does not survive reboot. Without root, process names in `ss` may be empty — at least check addresses and ports.

## What Is Not Here

- Ready-to-use `update.img` and `boot0` images: they are tied to a specific build and board.
- Automatic package removal from `/product`: that requires unpacking and rebuilding `super`.
- APK downloading: install apps from trusted sources only.

## Syntax Check

```sh
bash -n collect_info.sh debloat.sh block_iocs.sh
shellcheck collect_info.sh debloat.sh block_iocs.sh
# netwatch.sh — /system/bin/sh, check on device