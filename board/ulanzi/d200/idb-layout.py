#!/usr/bin/env python3
"""Lay out one 256 KiB IDB copy: the header alone in the first NAND block,
TPL+SPL in the second (header init_offset = 256 sectors).

The BootROM honours init_offset relative to each copy, so a copy can be
updated safely: erase its header block, write the code block, then write the
header page.

usage: idb-layout.py <idbloader.img from mkimage> <output>
"""
import struct
import sys

BLOCK = 128 * 1024
SECTOR = 512
# RC4 key of the Rockchip IDB header (tools/rkcommon.c)
KEY = bytes([124, 78, 3, 4, 85, 5, 9, 7, 45, 44, 123, 56, 23, 13, 23, 17])


def rc4(data):
    s = list(range(256))
    j = 0
    for i in range(256):
        j = (j + s[i] + KEY[i % 16]) & 255
        s[i], s[j] = s[j], s[i]
    i = j = 0
    out = bytearray()
    for b in data:
        i = (i + 1) & 255
        j = (j + s[i]) & 255
        s[i], s[j] = s[j], s[i]
        out.append(b ^ s[(s[i] + s[j]) & 255])
    return bytes(out)


def main(src, dst):
    img = open(src, 'rb').read()
    hdr = bytearray(rc4(img[:SECTOR]))
    magic, = struct.unpack_from('<I', hdr, 0)
    offset, = struct.unpack_from('<H', hdr, 12)
    _, boot_size = struct.unpack_from('<HH', hdr, 506)
    if magic != 0x0ff0aa55:
        sys.exit('%s: no IDB header' % src)
    code = img[offset * SECTOR:(offset + boot_size) * SECTOR]
    if len(code) > BLOCK:
        sys.exit('%s: TPL+SPL larger than one block' % src)

    struct.pack_into('<H', hdr, 12, BLOCK // SECTOR)
    hdr = rc4(bytes(hdr))
    pad = b'\xff'
    out = hdr + pad * (BLOCK - len(hdr)) + code + pad * (BLOCK - len(code))
    open(dst, 'wb').write(out)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
