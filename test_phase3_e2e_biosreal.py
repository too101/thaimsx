import sys
sys.path.insert(0, '/tmp/msxtest')
from emutest import make_machine, call_routine

# บั๊กจริงข้อ 5 -- regression test ระดับ "end-to-end จริง" (ดู src/keyboard.asm หัวข้อ 4 และ
# SPEC_TH.md) -- ต่างจาก test_phase3_typing.py/test_phase3_keyboard.py ที่เรียก KEYC_HOOK ตรง ๆ
# พร้อมจำลอง stack เอง ไฟล์นี้เรียกผ่าน "จุดเข้าจริงของ BIOS" (0x1021 ใน MSX1_bios.rom/
# MSX2_bios.rom, ยืนยันแล้วว่า byte เหมือนกันทุกไบต์ทั้งสองรุ่น) ตรง ๆ หลังติดตั้ง hook ด้วย
# KEYC_INSTALL เหมือนการใช้งานจริงทุกประการ -- นี่คือ test ที่พิสูจน์ได้ตรงที่สุดว่าอาการ
# "ค้างสนิท พิมพ์อะไรไม่ได้เลย" ที่ผู้ใช้รายงานบน blueMSX (หลังแก้บั๊กข้อ 4 ด้วย A=$FF ไปแล้ว)
# จะไม่เกิดขึ้นอีก เพราะ test นี้รันโค้ด BIOS จริง (ไม่ใช่แค่โค้ดของเราเอง) ผ่านเส้นทางเดียวกับ
# ที่ฮาร์ดแวร์จริงเรียกทุกประการ

CART = 'build/thairom.rom'
KEYBUF_START = 0xFBF0
EXIT_ADDR = 0x9500


def _load_symbols(path='build/thairom.sym'):
    syms = {}
    with open(path) as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 3 and parts[1] == 'EQU':
                syms[parts[0]] = int(parts[2].rstrip('H'), 16)
    return syms


_SYM = _load_symbols()
KEYC_INSTALL = _SYM['KEYC_INSTALL']
THAI_MODE = _SYM['THAI_MODE']
INPUT_MODE = _SYM['INPUT_MODE']
SHIFT_STATE = _SYM['SHIFT_STATE']
KEYQ_TAIL = _SYM['KEYQ_TAIL']
KEYQ_END = _SYM['KEYQ_END']
H_KEYC = _SYM['H_KEYC']

BIOS_ROMS = ['../MSX1_bios.rom', '../MSX2_bios.rom']


# *** บั๊กจริงข้อ 8 ไม่จบ + การออกแบบใหม่ (RST 30H) *** -- ดู comment เต็มที่ KEYC_INSTALL ใน
# src/keyboard.asm: hook ตอนนี้ติดตั้งด้วย RST 30H (CALLF, BIOS official inter-slot call) แทน
# trampoline มือเขียนเอง -- CALLF ของจริงต้องพึ่ง RAM ที่ $F38C ซึ่ง **cold boot จริงเท่านั้น** เป็น
# คนเติมให้ (เป็น "return trampoline" 12 ไบต์ที่ CALLF ใช้ระหว่างสลับ port $A8 กลับ/เรียกเป้าหมายผ่าน
# JP (IX)) -- test นี้กระโดดตรงเข้า 0x1021 โดยไม่ผ่าน cold boot จริงเลย (ดู comment เดิมด้านบน) จึง
# ไม่มี RAM ตรงนี้ให้ใช้ -- แก้โดย "ปลูกถ่าย" ไบต์จริงที่ยืนยันแล้วจาก openMSX (คือค่าที่ cold boot
# จริงของ MSX1_bios.rom เติมไว้ที่ $F38C เป๊ะ, ยืนยันด้วย debugger) ให้ CALLF ทำงานถูกต้องในนี้ด้วย
_F38C_COLDBOOT_TRAMPOLINE = bytes([
    0xD3, 0xA8, 0x08, 0xCD, 0x98, 0xF3, 0x08, 0xF1, 0xD3, 0xA8, 0x08, 0xC9,
    0xDD, 0xE9,
])


def _real_bios_press(bios_path, scan):
    # ติดตั้ง hook จริงผ่าน KEYC_INSTALL (เหมือนตอน THAION จริง) แล้วเรียกจุดเข้า H.KEYC ของ BIOS
    # จริง (0x1021) ตรง ๆ ด้วยค่า C = scan code จริง เหมือนที่ CALL c,0x1021 ใน matrix-scan loop
    # ของ BIOS (0x0D9A) ทำทุกประการ -- ไม่ผ่าน KEYC_HOOK โดยตรงเหมือน test ไฟล์อื่น ๆ เลย
    m, vdp = make_machine(CART, sys_rom_path=bios_path)
    for i, b in enumerate(_F38C_COLDBOOT_TRAMPOLINE):
        m.memory[0xF38C + i] = b
    m.memory[H_KEYC] = 0xC9  # stock default hook slot ก่อนติดตั้ง (RET x5 -- ยืนยันจาก openMSX จริง)
    m.memory[H_KEYC + 1] = 0xC9
    m.memory[H_KEYC + 2] = 0xC9
    m.memory[H_KEYC + 3] = 0xC9
    m.memory[H_KEYC + 4] = 0xC9
    ok, ev = call_routine(m, KEYC_INSTALL, {})
    assert ok, f"KEYC_INSTALL did not complete on {bios_path} (ev={ev})"

    m.memory[THAI_MODE] = 0xFF
    m.memory[INPUT_MODE] = 0xFF
    m.memory[SHIFT_STATE] = 0xFF  # *** บั๊กจริงข้อ 9/11 *** idle จริง (active-low NEWKEY) = ทุกบิต
                                   # ปล่อย ($FF) -- ตั้งแต่บั๊กข้อ 11 เช็ค bit2 (GRAPH) ตรง ๆ ด้วย ต้อง
                                   # เป็น idle เต็มรูปแบบจริง ไม่ใช่แค่บิต 0-1 (=3) เหมือนเดิมอีกต่อไป
    m.memory[KEYQ_TAIL] = KEYBUF_START & 0xFF
    m.memory[KEYQ_TAIL + 1] = (KEYBUF_START >> 8) & 0xFF
    m.memory[KEYQ_END] = 0x00
    m.memory[KEYBUF_START] = 0
    m.memory[KEYBUF_START + 1] = 0

    m.halted = False
    m.c = scan
    m.hl = 0
    m.memory[EXIT_ADDR] = 0x76  # HALT -- จำลองจุดต่อจาก "CALL c,0x1021" ใน matrix-scan loop จริง
    m.sp = 0xFE00
    m.sp -= 2
    m.memory[m.sp] = EXIT_ADDR & 0xFF
    m.memory[m.sp + 1] = (EXIT_ADDR >> 8) & 0xFF
    m.pc = 0x1021
    m.ticks_to_stop = 500_000
    ev = m.run()
    frames = 0
    while not m.halted and ev != 0 and frames < 200000:
        ev = m.run()
        frames += 1

    landed = m.halted and m.pc == (EXIT_ADDR + 1)
    tail = m.memory[KEYQ_TAIL] | (m.memory[KEYQ_TAIL + 1] << 8)
    return landed, m, tail


def test_main_row_key_no_freeze_and_exactly_one_char_on_real_bios():
    for bios in BIOS_ROMS:
        landed, m, tail = _real_bios_press(bios, 0x16)  # 'A' key -> ฟ (0xBF)
        assert landed, (
            f"[{bios}] froze / never returned to the real BIOS caller for scan=0x16 -- "
            f"this is exactly the freeze reported by the user on real hardware/blueMSX"
        )
        assert m.memory[KEYBUF_START] == 0xBF, f"[{bios}] expected 0xBF (ฟ) pushed"
        assert tail == KEYBUF_START + 1, (
            f"[{bios}] queue tail advanced by more than 1 char -- BIOS's own dispatch table "
            f"must have pushed an extra character on top of ours (bug #4 symptom)"
        )
    print("test_main_row_key_no_freeze_and_exactly_one_char_on_real_bios: PASS")


def test_row1_key_no_freeze_and_exactly_one_char_on_real_bios():
    for bios in BIOS_ROMS:
        landed, m, tail = _real_bios_press(bios, 0x0A)  # '-' key -> ข (0xA2)
        assert landed, f"[{bios}] froze for row1 scan=0x0A"
        assert m.memory[KEYBUF_START] == 0xA2, f"[{bios}] expected 0xA2 (ข) pushed"
        assert tail == KEYBUF_START + 1, f"[{bios}] extra character pushed by BIOS's own dispatch"
    print("test_row1_key_no_freeze_and_exactly_one_char_on_real_bios: PASS")


def test_toggle_key_no_freeze_on_real_bios():
    for bios in BIOS_ROMS:
        landed, m, tail = _real_bios_press(bios, 0x34)  # ปุ่มสลับโหมด
        assert landed, f"[{bios}] froze on the toggle key -- would hang immediately after THAION"
        assert m.memory[INPUT_MODE] == 0x00, f"[{bios}] toggle should flip INPUT_MODE 0xFF -> 0x00"
    print("test_toggle_key_no_freeze_on_real_bios: PASS")


if __name__ == '__main__':
    test_main_row_key_no_freeze_and_exactly_one_char_on_real_bios()
    test_row1_key_no_freeze_and_exactly_one_char_on_real_bios()
    test_toggle_key_no_freeze_on_real_bios()
    print("ALL PASS")
