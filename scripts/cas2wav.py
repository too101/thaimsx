#!/usr/bin/env python3
# cas2wav.py -- แปลงไฟล์เทป .CAS ของ MSX เป็นเสียง .WAV (1200 baud) สำหรับอัดลงเทปจริง หรือเล่นเข้าช่องเทปของเครื่อง
# ใช้: cas2wav.py in.cas out.wav   (1200 baud -- ทดสอบแล้วว่า MSX ใน openMSX โหลดได้)
# รูปแบบสัญญาณมาตรฐานของ MSX BIOS:
#   บิต 0 = 1 รอบที่ 1200 Hz, บิต 1 = 2 รอบที่ 2400 Hz
#   1 ไบต์ = start bit 0 + 8 บิต (LSB ก่อน) + stop bit 1 สองบิต
#   หัวไฟล์ (บล็อกชื่อไฟล์) = เงียบ 2 วินาที + tone 2400 Hz ยาว 16000 รอบ; บล็อกข้อมูล = เงียบ 1 วินาที + tone 4000 รอบ
import sys, struct

CAS_HDR = bytes([0x1F, 0xA6, 0xDE, 0xBA, 0xCC, 0x13, 0x7D, 0x74])
RATE = 43200

def main():
    src, dst = sys.argv[1:3]
    baud = 1200
    data = open(src, 'rb').read()
    lo = RATE // baud            # samples ต่อ 1 รอบของบิต 0
    hi = lo // 2                 # samples ต่อ 1 รอบของบิต 1 / tone หัว
    out = bytearray()

    def cycle(n):
        out.extend(b'\xE0' * (n // 2)); out.extend(b'\x20' * (n - n // 2))
    def silence(sec):
        out.extend(b'\x80' * int(RATE * sec))
    def byte(v):
        cycle(lo)                                   # start bit 0
        for i in range(8):
            if (v >> i) & 1: cycle(hi); cycle(hi)
            else: cycle(lo)
        for _ in range(2): cycle(hi); cycle(hi)     # stop bits 1

    # แยกบล็อกตามตำแหน่ง header ของ .CAS (อยู่ที่ขอบ 8 ไบต์)
    pos = [i for i in range(0, len(data) - 7, 8) if data[i:i + 8] == CAS_HDR]
    for k, p in enumerate(pos):
        end = pos[k + 1] if k + 1 < len(pos) else len(data)
        block = data[p + 8:end]
        is_file_hdr = len(block) >= 10 and block[:10] in (b'\xD0' * 10, b'\xD3' * 10, b'\xEA' * 10)
        if is_file_hdr:
            silence(2.0); [cycle(hi) for _ in range(16000)]
        else:
            silence(1.0); [cycle(hi) for _ in range(4000)]
        for b in block:
            byte(b)
    silence(1.0)

    with open(dst, 'wb') as f:
        f.write(b'RIFF' + struct.pack('<I', 36 + len(out)) + b'WAVE')
        f.write(b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, RATE, RATE, 1, 8))
        f.write(b'data' + struct.pack('<I', len(out)) + out)
    print(f"{dst}: {len(out) / RATE:.1f} s at {baud} baud")

if __name__ == '__main__':
    main()
