#!/usr/bin/env python3
import sys
src, dst = sys.argv[1], sys.argv[2]
OFF = 0x169fc
ORIG = bytes.fromhex('2a00a052')   # movz w10, #0x1, lsl #16   -> limit = 0x10000 sectors (32 MiB)
NEW  = bytes.fromhex('0a008012')   # movn w10, #0              -> limit = 0xFFFFFFFF (unlimited)
d = bytearray(open(src, 'rb').read())
assert d[-4:] == b'QSAK', f"trailer not QSAK: {d[-4:]!r}"
cur = bytes(d[OFF:OFF+4])
assert cur == ORIG, f"unexpected bytes at {OFF:#x}: {cur.hex()} (expected {ORIG.hex()})"
d[OFF:OFF+4] = NEW
assert d[-4:] == b'QSAK' and len(d) == len(open(src,'rb').read())
open(dst, 'wb').write(d)
print(f"patched {OFF:#x}: {ORIG.hex()} -> {NEW.hex()}  (limit 0x10000 -> 0xffffffff)")
print(f"size {len(d)} bytes, trailer={d[-4:].decode()}")
