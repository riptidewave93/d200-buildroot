# RK3308 loader without the 32 MiB read limit

For backing up the stock firmware from maskrom when `adb` isn't available
([install.md](../install.md#1-back-up-the-stock-firmware)).

Stock Rockchip loaders stop reading the flash at **32 MiB**, and reads past it **don't fail**: they return `0xcc`
filler. The limit is one instruction in rkbin's usbplug blob; `patch_usbplug.py` raises it to "no limit". Only reads
change; write and erase are untouched.

| File | Use |
|---|---|
| `patch_usbplug.py` | Patches rkbin's `rk3308_usbplug_v1.46.bin` (checks the original bytes first) |
| `RK3308MINIALL_UNLIMITED_READ.ini` | `boot_merger` recipe: rkbin's `RK3308MINIALL.ini` with the patched usbplug |

## Build the loader

You need `python3` and a clone of [rkbin](https://github.com/rockchip-linux/rkbin) with
`bin/rk33/rk3308_usbplug_v1.46.bin` (e.g. the commit in the [README](../../README.md#versions)). From the rkbin
directory, with `D200=/path/to/d200-buildroot`:
```bash
python3 $D200/docs/read-unlock/patch_usbplug.py \
    bin/rk33/rk3308_usbplug_v1.46.bin bin/rk33/rk3308_usbplug_v1.46_unlimited-read.bin
cp $D200/docs/read-unlock/RK3308MINIALL_UNLIMITED_READ.ini RKBOOT/
./tools/boot_merger RKBOOT/RK3308MINIALL_UNLIMITED_READ.ini
# -> rk3308_loader_v2.11.143_unlimited-read.bin
```

## Read the flash

Enter maskrom ([install.md](../install.md#2-enter-maskrom)), then:
```bash
rkdeveloptool ld                                          # "Maskrom", not "Loader"
rkdeveloptool db rk3308_loader_v2.11.143_unlimited-read.bin
rkdeveloptool rl 0 471040 d200-factory.img                # <start> <sectors> <file>
```
This gives the same 241172480-byte image as `adb pull /dev/rkflash0`.

The D200 is now in Loader mode, not maskrom. Unplug it and enter maskrom again before flashing.
