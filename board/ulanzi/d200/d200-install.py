#!/usr/bin/env python3
"""Install the firmware on a D200 in maskrom, without rkdeveloptool. Does
what these do (flashing.md, "From maskrom"):
  rkdeveloptool db rk3308_loader_wo_ftl.bin
  rkdeveloptool ef
  rkdeveloptool wl 0 d200-full.img
  rkdeveloptool rd

usage: d200-install.py [image-dir]
  image-dir  holds d200-full.img and rk3308_loader_wo_ftl.bin (default: the
             script's directory)

Needs Python 3 and pyusb, with libusb from the system or the libusb-package
module. Everything on the D200 is erased.
"""
import binascii
import os
import struct
import sys
import time

import usb.core

VID, PID = 0x2207, 0x330e     # the BootROM and Rockchip's flash loader alike
CHUNK = 128                 # sectors per write, as rkdeveloptool


def say(msg, end='\n'):
    print(msg, end=end, flush=True)


def backend():
    try:
        import libusb_package
        return libusb_package.get_libusb1_backend()
    except ImportError:
        return None


def wait_for(loader, wait):
    """Wait for the D200 in maskrom, or with `loader` for the flash loader,
    which unlike the BootROM has a product string."""
    end = time.monotonic() + wait
    while True:
        try:
            dev = usb.core.find(idVendor=VID, idProduct=PID, backend=backend())
        except usb.core.NoBackendError:
            sys.exit('No libusb found: install libusb, or pip install libusb-package')
        if dev is not None and (dev.iProduct or not loader):
            return dev
        if time.monotonic() > end:
            if loader:
                sys.exit("Rockchip's flash loader didn't start. Unplug the D200, enter maskrom again "
                         '(install.md, step 1) and run this again.')
            sys.exit('No D200 in maskrom found. Enter maskrom (install.md, step 1) and run this again.')
        time.sleep(0.5)


def download(dev, path):
    """rkdeveloptool db: send the loader's 0x471 and 0x472 entries as stored,
    each followed by a CRC-16/CCITT, in 4 KiB control transfers."""
    with open(path, 'rb') as f:
        b = f.read()
    if b[:4] != b'BOOT':
        sys.exit(path + ': not a Rockchip loader')
    n471, off471, size471, n472, off472, size472 = struct.unpack_from('<BIBBIB', b, 25)
    for code, num, off, size in ((0x471, n471, off471, size471), (0x472, n472, off472, size472)):
        for i in range(num):
            doff, dsize, delay = struct.unpack_from('<III', b, off + i * size + 45)
            data = b[doff:doff + dsize]
            data += struct.pack('>H', binascii.crc_hqx(data, 0xffff))
            for pos in range(0, len(data), 4096):
                dev.ctrl_transfer(0x40, 0x0c, 0, code, data[pos:pos + 4096], timeout=10000)
            time.sleep(delay / 1000)


class Rockusb:
    """Bulk commands of a Rockchip loader in Loader mode."""

    def __init__(self, dev):
        intf = dev.get_active_configuration()[(0, 0)]
        self.out = next(e for e in intf if not e.bEndpointAddress & 0x80)
        self.inp = next(e for e in intf if e.bEndpointAddress & 0x80)

    def cmd(self, op, cb_len=6, lun=0, addr=0, count=0, read=0, data=b''):
        """Send a command (and `data`), read `read` bytes back; return
        (status, data)."""
        tag = int.from_bytes(os.urandom(4), 'little')
        length = read or len(data)
        cbw = struct.pack('<IIIBBB', 0x43425355, tag, length, 0x80 if read else 0, lun, cb_len)
        cbw += struct.pack('>BxIxH7x', op, addr, count)
        self.out.write(cbw, timeout=5000)
        if data:
            self.out.write(data, timeout=10000)
        reply = bytes(self.inp.read(512, timeout=5000)) if read else b''
        sig, rtag, _, status = struct.unpack('<IIIB', bytes(self.inp.read(13, timeout=60000)))
        if sig != 0x53425355 or rtag != tag:
            sys.exit('The D200 gave a bad reply to command 0x%02x' % op)
        return status, reply

    def erase_all(self):
        """rkdeveloptool ef, by LBA (rkdeveloptool erases by block only for
        loaders without LBA access, which ours has)."""
        _, info = self.cmd(0x1a, read=11)                   # READ_FLASH_INFO
        _, cap = self.cmd(0xaa, read=8)                     # READ_CAPABILITY
        if not cap[0] & 1:
            sys.exit("This flash loader can't erase by LBA")
        total = struct.unpack_from('<I', info)[0] // 2048 * 2048
        say('Erasing the flash (%d MiB)...' % (total // 2048))
        for pos in range(0, total, 32768):
            say('\rErasing: %d%%' % (100 * pos // total), end='')
            status, _ = self.cmd(0x25, 10, addr=pos, count=min(32768, total - pos))  # ERASE_LBA
            if status:
                sys.exit('\nErasing failed at sector %d' % pos)
        say('\rErasing: done')

    def write_image(self, path):
        """rkdeveloptool wl 0: WRITE_LBA, 128 sectors at a time."""
        name = os.path.basename(path)
        size = os.path.getsize(path)
        done = 0
        with open(path, 'rb') as f:
            while done < size:
                data = f.read(CHUNK * 512)
                data += bytes(-len(data) % 512)
                say('\rWriting %s: %d%%' % (name, 100 * done // size), end='')
                status, _ = self.cmd(0x15, 10, addr=done // 512, count=len(data) // 512, data=data)
                if status:
                    sys.exit('\nWriting failed at sector %d' % (done // 512))
                done += len(data)
        say('\rWriting %s: done' % name)

    def reset(self):
        try:
            self.cmd(0xff)                                  # DEVICE_RESET
        except usb.core.USBError:
            pass                                            # it may go before replying


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    loader = os.path.join(folder, 'rk3308_loader_wo_ftl.bin')
    image = os.path.join(folder, 'd200-full.img')
    for path in (loader, image):
        if not os.path.isfile(path):
            sys.exit('Missing ' + path)

    say('Waiting for the D200 in maskrom...')
    dev = wait_for(False, 120)
    if dev.iProduct:
        say("Rockchip's flash loader is already running")
    else:
        say("Loading Rockchip's flash loader...")
        download(dev, loader)
        say('Waiting for the flash loader...')
        dev = wait_for(True, 20)
    rockusb = Rockusb(dev)
    rockusb.erase_all()
    rockusb.write_image(image)
    say('Done, restarting the D200')
    rockusb.reset()


if __name__ == '__main__':
    try:
        main()
    except usb.core.USBError as e:
        if e.errno == 13 or 'access' in str(e).lower():
            sys.exit("\nNo access to the D200's USB device: run it with sudo")
        raise
