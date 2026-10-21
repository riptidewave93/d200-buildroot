#!/usr/bin/env python3
"""Pack an update.img for RKDevTool's "Upgrade Firmware": the whole install,
like d200-full.img, from maskrom.

update.img is an RKFW file: a header, the loader RKDevTool runs from maskrom,
an RKAF archive with the images and where they go, and an MD5. The images are
"env" firmware: an item named "env" at sector 0 makes the tool skip writing
its own boot block and write every item at its raw NAND offset, if the loader
supports direct LBA (rkbin's raw NAND loader does). "env" is just that label
here: it holds the idbloader partition. The tool erases the whole "ubi"
partition before writing ubi.img, and reads every item back after writing.

usage: rkdevtool-image.py <loader> <image folder> <version> <output>
  loader        rk3308_loader_wo_ftl.bin
  image folder  holds idbloader-x4.img, u-boot.itb and ubi.img
  version       X.Y.Z, shown by the tool as the firmware version
"""
import hashlib
import os
import re
import struct
import sys
import time

SECTOR = 512
ALIGN = 2048
NO_FLASH = 0xffffffff
# name, file, NAND offset and size in sectors (docs/flashing.md#nand-layout)
LAYOUT = [
    ('env', 'idbloader-x4.img', 0x0, 0x800),
    ('u-boot', 'u-boot.itb', 0x800, 0x2000),
    ('u-boot-backup', 'u-boot.itb', 0x2800, 0x2000),
    ('ubi', 'ubi.img', 0x4800, 0x7b000),
]
LOADER = 'rk3308_loader_wo_ftl.bin'
CHIP = b'8033'  # RK3308, digits reversed


def rkcrc(data, crc=0):
    """Rockchip's CRC32 (polynomial 0x04c10db7, no reflection)"""
    for b in data:
        crc = ((crc << 8) & 0xffffffff) ^ TABLE[(crc >> 24) ^ b]
    return crc


def _table():
    t = []
    for i in range(256):
        c = i << 24
        for _ in range(8):
            c = ((c << 1) ^ 0x04c10db7 if c & 0x80000000 else c << 1) & 0xffffffff
        t.append(c)
    return t


TABLE = _table()


def cstr(s, n):
    return s.encode().ljust(n, b'\0')


def rkaf(files, version):
    """files: [(name, path in the archive, data, NAND offset, NAND size)]"""
    package = '# NAME\tPATH\n' + ''.join('%s\t%s\n' % (n, p) for n, p, *_ in files)
    files = [('package-file', 'package-file', package.encode(), NO_FLASH, 0)] + files
    head = bytearray(ALIGN)
    head[0:4] = b'RKAF'
    head[8:42] = cstr('RK3308', 34)  # model
    head[72:132] = cstr('RK3308', 60)  # manufacturer
    struct.pack_into('<II', head, 132, version, len(files))
    body = bytearray()
    placed = {}  # the same file is stored once
    for i, (name, path, data, flash, size) in enumerate(files):
        if path not in placed:
            placed[path] = ALIGN + len(body)
            body += data + bytes(-len(data) % ALIGN)
        struct.pack_into('<32s60sIIIII', head, 140 + i * 112, cstr(name, 32), cstr(path, 60),
                         size, placed[path], flash, -(-len(data) // ALIGN), len(data))
    struct.pack_into('<I', head, 4, ALIGN + len(body))
    out = bytes(head) + bytes(body)
    return out + struct.pack('<I', rkcrc(out))


def rkfw(loader, archive, version, when):
    t = time.gmtime(when)
    head = bytearray(0x66)
    struct.pack_into('<4sHII', head, 0, b'RKFW', 0x66, version, 0x02000000)
    struct.pack_into('<HBBBBB', head, 0x0e, t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec)
    head[0x15:0x19] = CHIP
    struct.pack_into('<IIII', head, 0x19, 0x66, len(loader), 0x66 + len(loader), len(archive))
    head[0x2d] = 1  # OS type, as Rockchip's tools set it
    out = bytes(head) + loader + archive
    return out + hashlib.md5(out).hexdigest().encode()


def check(img, loader, files):
    """Read the update.img back: checksums, offsets and every item"""
    assert img[:4] == b'RKFW' and img[0x15:0x19] == CHIP
    lo, ll, ao, al = struct.unpack_from('<IIII', img, 0x19)
    assert ao + al + 32 == len(img), 'RKFW size'
    assert hashlib.md5(img[:-32]).hexdigest().encode() == img[-32:], 'RKFW MD5'
    assert img[lo:lo + ll] == loader, 'loader'
    a = img[ao:ao + al]
    assert a[:4] == b'RKAF' and struct.unpack_from('<I', a, 4)[0] == al - 4, 'RKAF size'
    assert rkcrc(a[:-4]) == struct.unpack_from('<I', a, al - 4)[0], 'RKAF CRC'
    count, = struct.unpack_from('<I', a, 136)
    want = {n: (d, f, s) for n, _, d, f, s in files}
    got = set()
    for i in range(count):
        name, _, size, pos, flash, pad, n = struct.unpack_from('<32s60sIIIII', a, 140 + i * 112)
        name = name.rstrip(b'\0').decode()
        assert pos % ALIGN == 0 and pos + pad * ALIGN <= al - 4, name
        if name == 'package-file':
            continue
        d, f, s = want[name]
        assert (a[pos:pos + n], flash, size) == (d, f, s), name
        got.add(name)
    assert got == set(want), 'items'


def main(loader_path, folder, version, output):
    m = re.match(r'v?(\d+)\.(\d+)\.(\d+)', version)
    major, minor, patch = map(int, m.groups()) if m else (0, 0, 0)
    ver = major << 24 | minor << 16 | patch
    loader = open(loader_path, 'rb').read()
    files = [('bootloader', LOADER, loader, NO_FLASH, 0)]
    for name, f, offset, size in LAYOUT:
        data = open(os.path.join(folder, f), 'rb').read()
        if len(data) > size * SECTOR:
            sys.exit('%s: larger than %s' % (f, name))
        files.append((name, f, data, offset, size))
    when = int(os.environ.get('SOURCE_DATE_EPOCH', time.time()))
    img = rkfw(loader, rkaf(files, ver), ver, when)
    check(img, loader, files)
    open(output, 'wb').write(img)


if __name__ == '__main__':
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
