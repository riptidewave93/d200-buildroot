# D200 hardware

The Ulanzi D200 is a stream controller: 14 keys (one double-wide) in front of one LCD, USB-C, no Wi-Fi or Ethernet
port.

| Part | Details |
|---|---|
| SoC | Rockchip **RK3308B-S**, 4x Cortex-A35, runs 64-bit. Marked **RK3308H1** (128 MiB RAM) or **RK3308H3** (256 MiB) |
| RAM | 128 or 256 MiB. Linux/U-Boot see 2 MiB less: BL31 owns the first 2 MiB |
| Storage | 256 MiB SPI NAND, GigaDevice **GD5F2GM7**: 128 KiB blocks, 2 KiB pages, on-die ECC |
| Display | 720x1280 RGB panel (NewVision **NV3052C**), one of [two types](#panels), mounted rotated, used as 1280x720 landscape |
| Keys | 5x3 GPIO matrix (bottom-right key is double-wide) |
| Console | UART2 (TX GPIO4_D2, RX GPIO4_D3), **1500000 8N1** |
| USB | USB-C, DWC2 controller in device mode (maskrom, fastboot, Linux gadget) |
| Serial number | The CPU serial from OTP: the USB serial number and the source of the network addresses |

## Boot

BootROM → IDB (rkbin DDR init + U-Boot SPL) → BL31 (rkbin) → U-Boot → Linux.

The BootROM reads the IDB from SPI NAND at `0x0`, `0x40000`, `0x80000` or `0xc0000` (4 copies). If none is valid it
enters **maskrom**: USB device `2207:330e`, which `d200-install.py` and RKDevTool talk to.

## CPU

| Frequency | `vdd_core` | |
|---|---|---|
| 408 MHz | 0.85 V | idle |
| 600 MHz | 0.90 V | |
| 816 MHz | 1.00 V | maximum enabled; U-Boot runs here (at 1.015 V) |
| 1008, 1104 MHz | 1.125, 1.20 V | disabled, as in the vendor firmware |

Above **90 °C** Linux lowers the clock, at **115 °C** it shuts down, at **120 °C** the SoC resets. Idle is about
30-34 °C.

## Display

U-Boot and Linux drive the panel from the same `rockchip,cmd-panel` node in `rk3308-ulanzi-d200.dts`.

### Panels

D200s come with one of two panels. Each needs its own timings and init sequence; with the wrong one, the picture is
wavy and stretched.

| Panel | Config | Usually found with |
|---|---|---|
| `h1` | `rk3308-ulanzi-d200.dts` | RK3308H1 (128 MiB) |
| `h3` | the `rk3308-ulanzi-d200-panel-h3.dtso` overlay | RK3308H3 (256 MiB) |

U-Boot picks the panel before it shows the boot logo, and boots Linux with the matching device tree (the `h1` or
`h3` configuration in `kernel.itb`). In order:

1. The `panel` variable in the U-Boot env, if it is `h1` or `h3` (unset or `auto`: detect).
2. The SoC: 128 MiB of RAM picks `h1`, 256 MiB picks `h3`.
3. Otherwise `h1`.

If the picture is wavy or stretched, set the panel from Linux. It applies from the next boot and stays across updates
and device resets, but not a full install:
```
fw_setenv panel h3     # or h1; "fw_setenv panel" goes back to detection
```
The U-Boot console logs the choice (`panel: unknown, SoC H3 (256 MiB) -> h3`), and Linux gets it on the command
line as `d200.panel=`, next to `d200.panel_regs=`, the panel's registers `0x78`-`0x7e` (page 1) in hex.

### Screen layout

Each key is a window onto the panel. In the 1280x720 landscape framebuffer (the exact windows are d200-deck's
[`render.Key`](https://github.com/riptidewave93/d200-deck/blob/main/render/render.go)):

| Key | Visible area (approx.) |
|---|---|
| Small keys | ~200x160 each, on a 5x3 grid |
| Top-left | x 17..212, y 0..195 |
| Big bottom-right | x 800..1260, y 525..720 |

## Keys

Key codes: [linux.md](linux.md#display-and-keys); key numbers in the config:
[d200-deck config.md](https://github.com/riptidewave93/d200-deck/blob/main/docs/config.md#keys). Used by the
bootloader:
- **Top-left**: "Hold for Fastboot" in U-Boot.
- **Top-left + bottom-left**: maskrom from SPL.

## Test points

| Point | Use |
|---|---|
| R9602 | The pad nearest the SoC, shorted to GND (e.g. a mounting screw), blocks the flash → maskrom |
| SPI NAND (WSON-8) | Pin 1 is CS#, pin 8 is VCC, next to each other. Shorting them also forces maskrom |

Procedure: [recovery.md](recovery.md#3-hardware-short-last-resort).
