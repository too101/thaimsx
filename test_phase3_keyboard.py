import sys
sys.path.insert(0, '/tmp/msxtest')
from emutest import make_machine, call_routine

CART = 'build/thairom.rom'
BIOS = '../MSX1_bios.rom'


def make_machine(*a, **kw):
    from emutest import make_machine as _mm
    kw.setdefault('sys_rom_path', BIOS)
    return _mm(*a, **kw)

def _load_symbols(path='build/thairom.sym'):
    syms = {}
    with open(path) as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 3 and parts[1] == 'EQU':
                name = parts[0]
                val = parts[2].rstrip('H')
                syms[name] = int(val, 16)
    return syms

_SYM = _load_symbols()

H_KEYC = _SYM['H_KEYC']
PREV_KEYC = _SYM['PREV_KEYC']
INPUT_MODE = _SYM['INPUT_MODE']
THAI_MODE = _SYM['THAI_MODE']
SHIFT_STATE = _SYM['SHIFT_STATE']
MY_SLOT_ID = _SYM['MY_SLOT_ID']
RST30_OPCODE = _SYM['RST30_OPCODE']
# การออกแบบใหม่ (RST 30H / CALLF) -- ดู comment เต็มที่ KEYC_INSTALL ใน src/keyboard.asm สำหรับ
# เหตุผลทั้งหมด (แทนที่ trampoline มือเขียนเองของบั๊กข้อ 7/8 ทั้งหมด) -- H_KEYC ตอนนี้เป็น hook
# slot มาตรฐานของ MSX 5 ไบต์: [$F7=RST 30H][slot][addr_lo][addr_hi][$C9=RET] ชี้ตรงไปที่
# KEYC_HOOK_REAL (ROM) เลย ไม่มี KEYC_TRAMPOLINE (RAM) อีกต่อไป -- BIOS's official CALLF primitive
# จัดการสลับ page 1 ไป-กลับให้เองทั้งหมด (ยืนยันจาก disassembly จริงว่าใช้ shadow register set
# ป้องกัน primary BC/DE/HL ของผู้เรียกไม่ให้ถูกทับระหว่างนั้น)
KEYC_HOOK_REAL = _SYM['KEYC_HOOK_REAL']
KEYC_INSTALL = _SYM['KEYC_INSTALL']
KEYC_UNINSTALL = _SYM['KEYC_UNINSTALL']
KEYC_TOGGLE_CODE = _SYM['KEYC_TOGGLE_CODE']
SAFE_DISPATCH_A = _SYM['SAFE_DISPATCH_A']
KEYQ_TAIL = _SYM['KEYQ_TAIL']
KEYQ_END = _SYM['KEYQ_END']
KEYBUF_START = 0xFBF0


def test_install_patches_hkeyc_and_saves_original():
    m, vdp = make_machine(CART)
    # simulate "something else already hooked H.KEYC" -- classic hook chain
    # scenario -- so we can prove KEYC_INSTALL saves whatever was there
    # before, not just an assumed default RET stub. A stock/unhooked slot is
    # 5 bytes of RET (C9 x5) per real BIOS behavior (confirmed via openMSX);
    # here we pretend a prior hook occupied it instead.
    prior = [0xC3, 0x99, 0x99, 0xC9, 0xC9]
    for i, b in enumerate(prior):
        m.memory[H_KEYC + i] = b
    ok, ev = call_routine(m, KEYC_INSTALL, {})
    assert ok, f"KEYC_INSTALL did not run to completion (ev={ev})"
    # บั๊กจริงข้อ 8 (ไม่จบ) + การออกแบบใหม่: H_KEYC ต้องเป็น RST 30H hook slot ที่ชี้ไปที่
    # KEYC_HOOK_REAL ตรง ๆ (ไม่ใช่ RAM trampoline อีกต่อไป) -- format: F7,slot,addr_lo,addr_hi,C9
    assert m.memory[H_KEYC] == RST30_OPCODE, f"H_KEYC byte 0 should be RST30_OPCODE, got {m.memory[H_KEYC]:02x}"
    assert m.memory[H_KEYC + 1] == m.memory[MY_SLOT_ID], "H_KEYC byte 1 should be our own slot ID"
    lo = m.memory[H_KEYC + 2]
    hi = m.memory[H_KEYC + 3]
    assert (hi << 8 | lo) == KEYC_HOOK_REAL, f"H_KEYC should point at KEYC_HOOK_REAL, got {hi<<8|lo:04x}"
    assert m.memory[H_KEYC + 4] == 0xC9, "H_KEYC byte 4 should be RET (CALLF's own landing point)"
    for i, b in enumerate(prior):
        assert m.memory[PREV_KEYC + i] == b, f"PREV_KEYC byte {i} should back up the prior hook slot"
    print("test_install_patches_hkeyc_and_saves_original: PASS")


def test_uninstall_restores_original():
    m, vdp = make_machine(CART)
    prior = [0xC3, 0x99, 0x99, 0xC9, 0xC9]
    for i, b in enumerate(prior):
        m.memory[H_KEYC + i] = b
    call_routine(m, KEYC_INSTALL, {})
    ok, ev = call_routine(m, KEYC_UNINSTALL, {})
    assert ok, f"KEYC_UNINSTALL did not run to completion (ev={ev})"
    for i, b in enumerate(prior):
        assert m.memory[H_KEYC + i] == b, f"H_KEYC byte {i} should be restored to {b:02x}"
    print("test_uninstall_restores_original: PASS")


# บั๊กจริงข้อ 7/8/9/10 เปลี่ยนสัญญา (contract) ของ KEYC_HOOK_REAL หลายรอบ -- สถานะล่าสุด (การ
# ออกแบบใหม่ RST 30H): KEYC_HOOK_REAL ยังคงเป็น RET ชั้นเดียวธรรมดา เข้าด้วย A=C=scan code,
# HL=ค่าเดิมจากผู้เรียก (ต้องคืนเป๊ะทุกสาขา) -- ออกด้วย:
#   - carry=1 (SCF) + A=SAFE_DISPATCH_A = "จัดการคีย์นี้เองแล้ว" (ดันเข้าคิวเองผ่าน
#     QUEUE_PUSH_CHAR แล้ว) -- ค่า A ตรงนี้สำคัญมาก (บั๊กจริงข้อ 10): มันคือค่าที่ BIOS's ตัวจริง
#     (ผ่าน CALLF, ไม่ใช่ trampoline เดิม) จะใช้เดินตาราง dispatch ของมันเอง ต้องเป็นค่าที่ยืนยัน
#     แล้วว่า "ปลอดภัย" (ไม่ทำให้มันดันตัวอักษร default ซ้ำ) ไม่ใช่ scan code หรือค่า flag ภายใน
#   - carry=0 (OR A) + A=C (scan code เดิม) = "ปล่อยผ่าน" -- ปล่อยให้ตาราง dispatch ของ BIOS เอง
#     จัดการแบบ default (พิมพ์อังกฤษ/กราฟิกปกติ) เหมือนไม่มี hook เลย -- ไม่มี "PREV_KEYC" ให้ chain
#     ไปหาอีกต่อไป (ต่างจาก trampoline เดิม) เพราะ CALLF กลับไปที่ผู้เรียกจริงเสมอไม่ว่า carry จะเป็น
#     อะไร -- ตาราง dispatch ของ BIOS เองนั่นแหละที่ทำหน้าที่แทน "ปล่อยผ่าน" โดยธรรมชาติ (ยืนยันด้วย
#     test_phase3_e2e_biosreal.py ซึ่งเรียกผ่าน BIOS จริงเต็มรูปแบบ)
def _carry_set(m):
    return (m.af & 1) == 1


def test_toggle_key_flips_input_mode_and_returns_zero():
    m, vdp = make_machine(CART)
    m.memory[INPUT_MODE] = 0x00
    sentinel_hl = 0x1234
    ok, ev = call_routine(m, KEYC_HOOK_REAL, {'c': KEYC_TOGGLE_CODE, 'a': KEYC_TOGGLE_CODE, 'hl': sentinel_hl})
    assert ok, f"KEYC_HOOK_REAL(toggle) did not run to completion (ev={ev})"
    assert _carry_set(m), "toggle branch must signal 'handled' (carry=1/SCF)"
    assert m.a == SAFE_DISPATCH_A, f"บั๊กจริงข้อ 10: A must be SAFE_DISPATCH_A on the handled path, got {m.a:02x}"
    assert m.memory[INPUT_MODE] == 0xFF, "INPUT_MODE should flip 0x00 -> 0xFF"
    assert m.hl == sentinel_hl, f"HL must be preserved across the toggle branch, got {m.hl:04x}"

    # press it again -- must flip back
    ok, ev = call_routine(m, KEYC_HOOK_REAL, {'c': KEYC_TOGGLE_CODE, 'a': KEYC_TOGGLE_CODE, 'hl': sentinel_hl})
    assert ok
    assert _carry_set(m)
    assert m.a == SAFE_DISPATCH_A
    assert m.memory[INPUT_MODE] == 0x00, "INPUT_MODE should flip back 0xFF -> 0x00"
    assert m.hl == sentinel_hl
    print("test_toggle_key_flips_input_mode_and_returns_zero: PASS")


def test_passthrough_signals_carry_clear_and_preserves_scan_code():
    m, vdp = make_machine(CART)
    sentinel_hl = 0x5678
    ok, ev = call_routine(m, KEYC_HOOK_REAL, {'c': 0x10, 'a': 0x10, 'hl': sentinel_hl})
    assert ok, f"KEYC_HOOK_REAL(passthrough) did not run to completion (ev={ev})"
    assert not _carry_set(m), "passthrough branch must signal carry=0 (OR A)"
    assert m.a == 0x10, f"A must equal C (scan code) on passthrough, got a={m.a:02x}"
    assert m.hl == sentinel_hl, f"HL must be preserved across the passthrough branch, got {m.hl:04x}"
    print("test_passthrough_signals_carry_clear_and_preserves_scan_code: PASS")


def test_lookup_success_returns_safe_dispatch_a():
    # บั๊กจริงข้อ 10 โดยตรง: กด main-row key ที่มี mapping ไทย ต้อง SCF + A=SAFE_DISPATCH_A เสมอ
    # (ไม่ใช่ค่าเหลือจาก QUEUE_PUSH_CHAR อย่างที่เคยเป็นก่อนแก้) มิฉะนั้น BIOS จริง (ผ่าน CALLF) จะ
    # ดันตัวอักษร default ของมันเองซ้ำ (ยืนยันจริงบน openMSX: พิมพ์ "a" ได้ 0xBF ของเราถูก ตามด้วย
    # 0xC4 จาก BIOS อีกตัวก่อนแก้)
    m, vdp = make_machine(CART)
    m.memory[THAI_MODE] = 0xFF   # ต้องเปิด THAION ก่อน มิฉะนั้นจะตก .passthrough ตั้งแต่เช็คแรก
    m.memory[INPUT_MODE] = 0xFF  # ต้อง toggle เข้าโหมดพิมพ์ไทยด้วย มิฉะนั้นตก .passthrough เช็คที่สอง
    m.memory[SHIFT_STATE] = 0xFF  # idle จริง (active-low, ทุกบิต=ปล่อย -- บั๊กจริงข้อ 9/11)
    m.memory[KEYQ_TAIL] = KEYBUF_START & 0xFF
    m.memory[KEYQ_TAIL + 1] = (KEYBUF_START >> 8) & 0xFF
    m.memory[KEYQ_END] = 0x00   # ไม่ตรงกับ L หลัง advance -- ไม่ให้ตรรกะ "คิวเต็ม" ทำงานระหว่างทดสอบ
    sentinel_hl = 0x7062
    ok, ev = call_routine(m, KEYC_HOOK_REAL, {'c': 0x16, 'a': 0x16, 'hl': sentinel_hl})  # 'a' -> ฟ
    assert ok
    assert _carry_set(m)
    assert m.a == SAFE_DISPATCH_A, f"บั๊กจริงข้อ 10: A must be SAFE_DISPATCH_A, got {m.a:02x}"
    assert m.memory[KEYBUF_START] == 0xBF, "should have pushed ฟ (0xBF) into the keyboard queue"
    print("test_lookup_success_returns_safe_dispatch_a: PASS")


if __name__ == '__main__':
    test_install_patches_hkeyc_and_saves_original()
    test_uninstall_restores_original()
    test_toggle_key_flips_input_mode_and_returns_zero()
    test_passthrough_signals_carry_clear_and_preserves_scan_code()
    test_lookup_success_returns_safe_dispatch_a()
    print("ALL PASS")
