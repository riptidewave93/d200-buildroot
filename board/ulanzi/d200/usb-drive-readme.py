#!/usr/bin/env python3
"""The USB drive's README, which S30usb-gadget fills in at boot with the
D200's name and addresses, rewriting it in place in a RAM copy of the image.

usage: usb-drive-readme.py pad <readme> <out>
           <out>: the README for the image: generic values, padded with
           spaces to the longest the filled-in README can be
       usb-drive-readme.py locate <image> <readme>
           prints "<offset> <size>" of the README's bytes in the image
"""
import sys

# placeholder: (longest value, generic value)
FIELDS = {
    '@NAME@': (27, 'd200-<serial>.local'),  # d200-<16 hex digits>.local
    '@IPV4@': (15, '<D200 address>'),
    '@PEER4@': (15, '<PC address>'),
    '@IPV6@': (17, '<D200 address>'),  # fdxx:xxxx:xxxx::1
}


def pad(src, dst):
    text = open(src).read()
    longest = generic = text
    for k, (n, g) in FIELDS.items():
        longest = longest.replace(k, 'x' * max(n, len(g)))
        generic = generic.replace(k, g)
    open(dst, 'w').write(generic + ' ' * (len(longest) - len(generic)))


def locate(img, readme):
    data = open(img, 'rb').read()
    text = open(readme, 'rb').read()
    at = data.find(text)
    if at < 0 or data.find(text, at + 1) >= 0:
        sys.exit('%s: README not found once, in one piece' % img)
    print(at, len(text))


if __name__ == '__main__':
    if len(sys.argv) != 4 or sys.argv[1] not in ('pad', 'locate'):
        sys.exit(__doc__)
    {'pad': pad, 'locate': locate}[sys.argv[1]](sys.argv[2], sys.argv[3])
