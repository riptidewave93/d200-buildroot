#!/usr/bin/env python3
"""
D200 U-Boot screens, drawn for the keys the panel is seen through:
  boot:     Tux + "Booting..." in the large bottom-right key,
            "Hold for Fastboot" in the top-left key
  fastboot: USB plug + "Fastboot" in the large bottom-right key

U-Boot draws these right-aligned at (-4, 4), i.e. at x = 1277 - width, y = 4
on the 1280x720 (rotated) framebuffer. The canvas is 1277x716, so canvas
x == framebuffer x and canvas y == framebuffer y - 4. Key windows below are
in framebuffer coordinates (measured: big key x ~800..1260, y ~525..720;
the others are ~200x160 on a 5x3 grid).

Tux: tux.ppm is the Linux kernel boot logo
(drivers/video/logo/logo_linux_clut224.ppm, GPL-2.0).

Output: 8-bit palettized BMP (adaptive 256 colours), RLE8 compressed
(U-Boot VIDEO_BMP_RLE8), plus a -preview.png. Run in a container with
python3-pil + fonts-dejavu:
  d200-boot-logo.py boot <out.bmp> [tux.ppm]
  d200-boot-logo.py fastboot <out.bmp>
"""
import os, struct, sys
from PIL import Image, ImageDraw, ImageFont

MODE, OUT = sys.argv[1], sys.argv[2]
TUX = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(__file__), "tux.ppm")
CW, CH, OY = 1277, 716, 4
BIG = (800, 525, 1260, 720)        # big bottom-right key window (x0, y0, x1, y1)
TL = (17, 0, 212, 195)             # top-left key window
FG = (0xE6, 0xE6, 0xE6)            # off-white, like the vendor logo text
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
GAP = 22                           # space between icon and text

img = Image.new("RGB", (CW, CH), (0, 0, 0))
d = ImageDraw.Draw(img)


def centre(win):
    return (win[0] + win[2]) // 2, (win[1] + win[3]) // 2 - OY


def icon_and_text(icon, text, size):
    """centre [icon][gap][text] as a group in the big key"""
    font = ImageFont.truetype(FONT, size)
    l, t, r, b = d.textbbox((0, 0), text, font=font)
    cx, cy = centre(BIG)
    x0 = cx - (icon.width + GAP + r - l) // 2
    img.paste(icon, (x0, cy - icon.height // 2))
    d.text((x0 + icon.width + GAP - l, cy - (t + b) / 2), text, font=font, fill=FG)


def usb_plug(h):
    """upright USB plug, connector up and cable down; drawn 4x, scaled down"""
    s = 4
    u = h * s / 100                # 100 units = icon height, 56 units wide
    im = Image.new("RGB", (int(56 * u), h * s), (0, 0, 0))
    g = ImageDraw.Draw(im)
    g.rectangle((12 * u, 0, 44 * u, 38 * u), outline=FG, width=int(5 * u))   # shell
    g.rectangle((22 * u, 8 * u, 34 * u, 38 * u), fill=FG)                    # tongue
    g.rounded_rectangle((6 * u, 34 * u, 50 * u, 80 * u), 8 * u, fill=FG)     # body
    g.rectangle((23 * u, 80 * u, 33 * u, 100 * u), fill=FG)                  # cable
    return im.resize((im.width // s, h), Image.LANCZOS)


if MODE == "boot":
    tux = Image.open(TUX).convert("RGB")
    tux = tux.resize((tux.width * 120 // tux.height, 120), Image.LANCZOS)
    icon_and_text(tux, "Booting…", 54)
    font = ImageFont.truetype(FONT, 30)
    cx, cy = centre(TL)
    d.multiline_text((cx, cy), "Hold for\nFastboot", font=font, fill=FG,
                     anchor="mm", align="center", spacing=8)
elif MODE == "fastboot":
    icon_and_text(usb_plug(130), "Fastboot", 54)
else:
    sys.exit("mode must be boot or fastboot")

# adaptive palette, black first so the background is index 0
pimg = img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
pal = pimg.getpalette()[:255 * 3]
pal += [0] * (255 * 3 - len(pal))   # few-colour images get a short palette
px = pimg.load()
remap = [i + 1 for i in range(255)]
pal = [0, 0, 0] + pal
# map any pure-black entry to index 0 to keep RLE runs long
for i in range(255):
    if pal[3 + i * 3:6 + i * 3] == [0, 0, 0]:
        remap[i] = 0

rle = bytearray()
for y in range(CH - 1, -1, -1):
    x = 0
    while x < CW:
        v = remap[px[x, y]]; n = 1
        while x + n < CW and n < 255 and remap[px[x + n, y]] == v:
            n += 1
        rle += bytes((n, v)); x += n
    rle += b"\0\0"                 # end of line
rle[-2:] = b"\0\1"                 # end of bitmap
palbytes = b"".join(bytes((pal[i * 3 + 2], pal[i * 3 + 1], pal[i * 3], 0)) for i in range(256))
off = 14 + 40 + len(palbytes)
hdr = b"BM" + struct.pack("<IHHI", off + len(rle), 0, 0, off)
dib = struct.pack("<IiiHHIIiiII", 40, CW, CH, 1, 8, 1, len(rle), 2835, 2835, 256, 0)
open(OUT, "wb").write(hdr + dib + palbytes + rle)
img.save(OUT.rsplit(".", 1)[0] + "-preview.png")
print(OUT, CW, "x", CH, len(hdr + dib + palbytes + rle), "bytes")
