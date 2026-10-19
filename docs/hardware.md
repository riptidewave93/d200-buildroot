# D200 hardware

The Ulanzi D200 is a stream controller: 14 keys (one double-wide) in front of one LCD, USB-C, no Wi-Fi or Ethernet port.

| Part | Details |
|---|---|
| SoC | Rockchip **RK3308B-S**, 4x Cortex-A35, runs 64-bit |
| RAM | 128 MiB DDR3. Linux/U-Boot see 126 MiB: BL31 owns the first 2 MiB |
| Storage | 256 MiB SPI NAND, GigaDevice **GD5F2GM7**: 128 KiB blocks, 2 KiB pages, on-die ECC |
| Display | 720x1280 RGB panel (NewVision **NV3052C**), mounted rotated, used as 1280x720 landscape |
| Keys | 5x3 GPIO matrix (bottom-right key is double-wide) |
| Console | UART2 (TX GPIO4_D2, RX GPIO4_D3), **1500000 8N1** |
| USB | USB-C, DWC2 OTG controller in device mode (maskrom, fastboot, Linux gadget) |

## Boot

BootROM → IDB (rkbin DDR init + U-Boot SPL) → BL31 (rkbin) → U-Boot → Linux.

The BootROM reads the IDB from SPI NAND at `0x0`, `0x40000`, `0x80000` or `0xc0000` (4 copies). If none is valid it
enters **maskrom**: USB device `2207:330e`, driven by `rkdeveloptool`.

## CPU

| Frequency | `vdd_core` | |
|---|---|---|
| 408 MHz | 0.85 V | idle |
| 600 MHz | 0.90 V | |
| 816 MHz | 1.00 V | maximum enabled; U-Boot runs here (at 1.015 V) |
| 1008, 1104 MHz | 1.125, 1.20 V | disabled, as in the vendor firmware |

- Linux scales between these with `schedutil` (operating points from the vendor DT, in `rk3308bs.dtsi`).
- Above **90 °C** Linux lowers the clock, at **115 °C** it shuts down, at **120 °C** the TSADC resets the SoC. Idle
  is about 34 °C, all 4 cores busy about 38 °C.
- No CPU idle states: the rkbin BL31 doesn't support PSCI `CPU_SUSPEND`, so idle cores use WFI.

## Display

U-Boot and Linux both drive the panel from the same `rockchip,cmd-panel` node in `rk3308-ulanzi-d200.dts` (timings,
init sequence over bit-banged SPI). 720x1280 at ~36 Hz; software draws in landscape and rotates. Linux side:
[linux.md](linux.md#display-and-keys).

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

## USB

- Up to 6 IN endpoints at once; at most 3 high-speed bulk IN endpoints (FIFO sizes as in the vendor firmware).
- **One RX FIFO for all OUT endpoints:** if data arrives for an OUT endpoint nobody reads, it blocks every other OUT
  endpoint (see [linux.md](linux.md#usb)).

## OTP (CPU ID / serial)

The CPU serial (USB serial number, MAC addresses) is read from OTP. On the RK3308B-S, SPL must first hand the OTP to
the non-secure controller (clear SGRF_SOC_CON1 bit 2), or every read returns `0xff`. Rockchip's closed loaders do
this step; their open U-Boot and kernel sources don't.

## Test points

| Point | Use |
|---|---|
| R9602 | The pad nearest the SoC, shorted to GND (e.g. a mounting screw), blocks the flash → maskrom |
| SPI NAND (WSON-8) | Pin 1 is CS#, pin 8 is VCC, next to each other. Shorting them also forces maskrom |

Procedure: [recovery.md](recovery.md#3-hardware-short-last-resort).
