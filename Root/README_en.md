# Root

← [To index](../README.md) · [Audit](../AUDIT/security.md)

**Getting root on HY350 Max without reflashing is impossible.**

On this build `adb root` replies `adbd cannot run as root in production builds` (`ro.build.type=user`, `ro.debuggable=0`), there is no `su` in the system, fastboot and recovery with ADB sideload are absent. Vendor `hotacksu` did not work on the tested unit. Root only appears after flashing a modified image.

I did not reflash the device: root was not needed for normal operation. If reflash is necessary, it is possible using instructions for the same H726 platform:

- [Vadim000009/HY300ProByMagcubic → Root](https://github.com/Vadim000009/HY300ProByMagcubic/tree/main/Root)
- [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal) — cleanup of exactly the HY350 Max

Before flashing, verify the board: HY350 Max is `h726_p1`, an image for `h726_p2` will not work. Flashing erases `/data` and can brick the device; recovery is via FEL. Stock images: <https://www.magcubic-support.com/xw>.

Next: [Apps](../Apps/README.md)