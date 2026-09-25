#!/usr/bin/env python3
# สร้างไฟล์เทป .CAS จากไฟล์ BLOAD (header $FE start end exec + data) -- ใช้: mkcas.py in.bin out.cas NAME
import sys
HDR = bytes([0x1F,0xA6,0xDE,0xBA,0xCC,0x13,0x7D,0x74])
src, dst, name = sys.argv[1], sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else 'THAI')
b = open(src, 'rb').read()
assert b[0] == 0xFE
out = bytearray()
def block(data):
    while len(out) % 8: out.append(0)
    out.extend(HDR); out.extend(data)
block(bytes([0xD0]*10) + name.upper().encode()[:6].ljust(6))
block(b[1:])   # start, end, exec + data
open(dst, 'wb').write(out)
