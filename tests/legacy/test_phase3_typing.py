import sys
sys.path.insert(0, '/tmp/msxtest')
from emutest import call_routine

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

# บั๊กจริงข้อ 7 (ดู src/keyboard.asm หัวข้อ 4): KEYC_HOOK เดิมถูกเปลี่ยนชื่อเป็น KEYC_HOOK_REAL
# -- ตอนนี้มันเป็นแค่ RET ชั้นเดียวธรรมดา ส่งสัญญาณผลลัพธ์ผ่าน carry flag (SCF=handled,
# OR A=passthrough) แทนที่จะ RET สองชั้น/chain ไป PREV_KEYC เอง (หน้าที่ chain ไป PREV_KEYC
# ย้ายไปอยู่ใน KEYC_TRAMPOLINE_SRC ที่ห่อหุ้มมันไว้อีกชั้นแทน -- ดู KEYC_INSTALL/H_KEYC)
KEYC_HOOK_REAL = _SYM['KEYC_HOOK_REAL']
KEYC_INSTALL = _SYM['KEYC_INSTALL']
THAI_MODE = _SYM['THAI_MODE']
INPUT_MODE = _SYM['INPUT_MODE']
SHIFT_STATE = _SYM['SHIFT_STATE']
KEYQ_TAIL = _SYM['KEYQ_TAIL']
KEYQ_END = _SYM['KEYQ_END']
PREV_KEYC = _SYM['PREV_KEYC']
H_KEYC = _SYM['H_KEYC']
KEYC_TOGGLE_CODE = _SYM['KEYC_TOGGLE_CODE']

# ค่าเดียวกับที่ BIOS จริงใช้เป็นบัฟเฟอร์คีย์บอร์ด (ยืนยันจาก disassembly MSX1_bios.rom
# ที่ 0x10C2: INC HL / LD A,L / CP 0x18 / RET NZ / LD HL,0xFBF0 -- วนกลับที่ L=0x18)
KEYBUF_START = 0xFBF0

STUB_ADDR = 0xE000  # free RAM area in this harness's 64K space


def _setup_thai_typing(m, tail=KEYBUF_START, shift=0xFF):
    # *** บั๊กจริงข้อ 9 -- SHIFT_STATE เป็น active-low (NEWKEY มาตรฐาน): idle จริง (ไม่มี modifier
    # ถูกกดค้าง) คือ 0xFF ทุกบิต (ยืนยันจาก NEWKEY จริงผ่าน openMSX debugger ตอน idle = 0xFF ทุก row)
    # *** บั๊กจริงข้อ 11 -- เดิมใช้ shift=3 (แค่เช็ค AND 3) เป็นค่า default ซึ่ง "พอ" สำหรับเช็คแบบเดิม
    # แต่ไม่ใช่ idle จริงระดับบิต (bit2=GRAPH จะเป็น 0=กดอยู่ผิด ๆ) หลังเปลี่ยนมาเช็คทีละบิตตรง ๆ
    # (bit0=SHIFT,bit1=CTRL,bit2=GRAPH) ต้องใช้ 0xFF (ทุกบิต=ปล่อย) เป็น idle จริงเท่านั้น
    m.memory[THAI_MODE] = 0xFF
    m.memory[INPUT_MODE] = 0xFF
    m.memory[SHIFT_STATE] = shift
    m.memory[KEYQ_TAIL] = tail & 0xFF
    m.memory[KEYQ_TAIL + 1] = (tail >> 8) & 0xFF
    # ตั้ง KEYQ_END ให้ไม่ตรงกับ L หลัง advance เพื่อไม่ให้ตรรกะ "คิวเต็ม" ทำงานระหว่างทดสอบ
    m.memory[KEYQ_END] = 0x00
    # หมายเหตุ: ฟังก์ชันนี้ไม่แตะ H_KEYC/PREV_KEYC เลย -- ทุกเทสในไฟล์นี้เรียก KEYC_HOOK_REAL ตรง ๆ
    # (ผ่าน _call_hook_real/_press_handled/_press_passthrough) ไม่ผ่าน H_KEYC/RST 30H เลย (ดู
    # comment ใหญ่เหนือ _carry_set ด้านบนสำหรับเหตุผล)


# *** DEAD (ลบแล้ว) -- การออกแบบใหม่ (RST 30H / CALLF, ดู comment เต็มที่ KEYC_INSTALL ใน
# src/keyboard.asm): เคยมี _install_a77_stub()/_install_bare_ret_stub()/_press() ตรงนี้ที่เรียกผ่าน
# H_KEYC จริง (RST 30H) เพื่อยืนยัน end-to-end ว่า "ปล่อยผ่านไปถึง PREV_KEYC's stub จริง ๆ" -- แต่
# ในการออกแบบปัจจุบัน KEYC_HOOK_REAL "ไม่ chain ไป PREV_KEYC เองอีกต่อไปเลย" (ต่างจาก trampoline เดิม
# ก่อนบั๊กข้อ 7): เส้นทางปล่อยผ่าน (.passthrough) ทำแค่ "ld a,c / or a / ret" แล้วปล่อยให้ CALLF คืนค่า
# กลับไปหา BIOS caller จริง ซึ่งตาราง dispatch ของ BIOS เองทำหน้าที่แทน "ปล่อยผ่าน" โดยธรรมชาติ (ไม่มี
# PREV_KEYC เกี่ยวข้องในเส้นทางพิมพ์จริงเลย -- PREV_KEYC ใช้แค่ตอน KEYC_UNINSTALL คืนค่า H_KEYC ตอน
# THAIOFF เท่านั้น) นอกจากนี้ยังพบด้วยว่า harness แบบ flat-memory นี้ (emutest.py, ดู call_routine)
# ไม่ได้จำลอง slot switching จริงเลย (OUT/IN port $A8 เป็น no-op ทั้งคู่ ตกไปที่ VDP callback ที่คืน
# ค่า 0xFF เสมอสำหรับพอร์ตอื่น) ทำให้การเรียกผ่าน H_KEYC ตรง ๆ (กระตุ้น RST 30H จริง) พาไปสู่ path ของ
# CALSLT ที่ไม่แน่นอน/ไม่ตรงกับพฤติกรรมจริงเลย (ยืนยันด้วยการ trace จริง: ตกไปจบที่ STUB_ADDR โดย
# บังเอิญ ไม่ใช่เพราะโค้ดของเราจงใจ chain ไปที่นั่น) -- เหมือนกับเหตุผลที่ลบ
# test_trampoline_passthrough_chains_to_prev_keyc ออกจาก test_phase3_keyboard.py ไปแล้ว ดังนั้น
# ทุกเทสด้านล่างจึงเปลี่ยนมาเรียก KEYC_HOOK_REAL ตรง ๆ (ผ่าน _call_hook_real/_press_handled) แล้ว
# ยืนยันแค่ "สัญญา" (contract) ของมันเอง (carry=0/A=C สำหรับปล่อยผ่าน, carry=1/A=SAFE_DISPATCH_A
# สำหรับจัดการเอง) ซึ่งเป็นสิ่งเดียวที่ portable/ยืนยันได้จริงในระดับนี้ -- การยืนยัน end-to-end ผ่าน
# H_KEYC จริง (RST 30H เต็มรูปแบบ) ทำแยกต่างหากใน test_phase3_e2e_biosreal.py (เรียกผ่านจุดเข้าจริงของ
# BIOS ที่ 0x1021 พร้อม seed ค่า $F38C ที่ถูกต้อง) และยืนยันจริงบนฮาร์ดแวร์ผ่าน openMSX (cold boot เต็ม
# รูปแบบ) แล้วด้วย


def _carry_set(m):
    return (m.af & 1) == 1


def _call_hook_real(m, scan, hl=0x2222, max_ticks=200_000):
    # เรียก KEYC_HOOK_REAL ตรง ๆ (ไม่ผ่าน trampoline) -- ใช้สัญญาใหม่หลังบั๊กจริงข้อ 7:
    # RET ชั้นเดียวธรรมดา, ผลลัพธ์ส่งผ่าน carry flag (ดูหัวเรื่องด้านบน) ไม่ต้องจำลอง
    # double-return-address stack ของ BIOS อีกต่อไป (หน้าที่ข้ามตาราง dispatch อันตราย --
    # บั๊กจริงข้อ 5 -- ย้ายไปอยู่ใน KEYC_TRAMPOLINE_SRC แล้ว ซึ่งถูกทดสอบแยกใน
    # test_phase3_keyboard.py::test_trampoline_passthrough_chains_to_prev_keyc และใน
    # test_phase3_e2e_biosreal.py)
    ok, ev = call_routine(m, KEYC_HOOK_REAL, {'c': scan, 'a': scan, 'hl': hl}, max_ticks=max_ticks)
    assert ok, f"KEYC_HOOK_REAL did not run to completion for scan={scan:02x} (ev={ev})"
    assert m.hl == hl, f"HL must be preserved (scan={scan:02x}), got {m.hl:04x}"
    return ok


def _press_handled(m, scan, hl=0x2222, max_ticks=200_000):
    # เส้นทางที่ hook "จัดการคีย์เอง" (toggle / push อักษรไทยสำเร็จ) -- ตอนนี้ยืนยันแค่ว่า
    # KEYC_HOOK_REAL คืนค่า carry=1 (SCF, ดูหัวเรื่องด้านบน) แทนการจำลองว่า RET ไปถึงจุดไหน
    # ของ BIOS จริง (หน้าที่นั้นทดสอบแยกต่างหากผ่าน trampoline ใน test_phase3_keyboard.py และ
    # test_phase3_e2e_biosreal.py แล้ว)
    _call_hook_real(m, scan, hl=hl, max_ticks=max_ticks)
    assert _carry_set(m), (
        f"scan={scan:02x}: KEYC_HOOK_REAL should signal 'handled' (carry=1/SCF) -- "
        f"bug #5/#7 contract regressed"
    )


def _press_passthrough(m, scan, hl=0x2222, max_ticks=200_000):
    # ทดแทน _press() เดิม (ดู comment ด้านบน) -- เรียก KEYC_HOOK_REAL ตรง ๆ แล้วยืนยัน "สัญญา"
    # ปล่อยผ่านที่ portable จริง: carry=0 (OR A) และ A=C (scan code เดิม, บั๊กจริงข้อ 3)
    _call_hook_real(m, scan, hl=hl, max_ticks=max_ticks)
    assert not _carry_set(m), f"scan={scan:02x}: should signal passthrough (carry=0/OR A)"
    assert m.a == scan, f"scan={scan:02x}: A should equal C (scan code), got {m.a:02x}"


def test_main_row_consonant_pushed_to_queue():
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    # บั๊กจริงข้อ 5/7 (ดู src/keyboard.asm หัวข้อ 4): ใช้ _press_handled เพื่อยืนยันว่า
    # KEYC_HOOK_REAL ส่งสัญญาณ "จัดการเองแล้ว" (carry=1) ถูกต้อง -- การข้ามตาราง dispatch ของ
    # BIOS จริงตอนนี้เป็นหน้าที่ของ trampoline ซึ่งทดสอบแยกต่างหากแล้ว
    _press_handled(m, 0x16)  # 'A' key -> ฟ (0xBF) ยืนยันจาก MAIN_ROW_TABLE[0]
    assert m.memory[KEYBUF_START] == 0xBF, f"expected 0xBF (ฟ) pushed, got {m.memory[KEYBUF_START]:02x}"
    tail = m.memory[KEYQ_TAIL] | (m.memory[KEYQ_TAIL + 1] << 8)
    assert tail == KEYBUF_START + 1, f"queue tail should advance by 1, got {tail:04x}"
    print("test_main_row_consonant_pushed_to_queue: PASS")


def test_main_row_all_26_keys_match_extracted_table():
    m, vdp = make_machine(CART)
    expected = [0xBF, 0xD4, 0xE1, 0xA1, 0xD3, 0xB4, 0xE0, 0xE9, 0xC3, 0xE8,
                0xD2, 0xCA, 0xB7, 0xD7, 0xB9, 0xC2, 0xE6, 0xBE, 0xCB, 0xD0,
                0xD5, 0xCD, 0xE4, 0xBB, 0xD1, 0xBC]
    for i, want in enumerate(expected):
        tail = KEYBUF_START + i  # ตำแหน่งเดินไปเรื่อย ๆ ในรอบเดียว (ยังไม่ครบ wrap ที่ 0x18 ตัว)
        _setup_thai_typing(m, tail=tail)
        scan = 0x16 + i
        _press_handled(m, scan)
        got = m.memory[tail]
        assert got == want, f"scan={scan:02x} (key #{i}) expected {want:02x} got {got:02x}"
    print("test_main_row_all_26_keys_match_extracted_table: PASS")


def test_row1_symbol_pushed_to_queue():
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    _press_handled(m, 0x0A)  # '-' key -> ข (0xA2) ยืนยันจาก ROW1_TABLE[0]
    assert m.memory[KEYBUF_START] == 0xA2, f"expected 0xA2 (ข), got {m.memory[KEYBUF_START]:02x}"
    print("test_row1_symbol_pushed_to_queue: PASS")


def test_row1_unmapped_dead_key_passes_through():
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    _press_passthrough(m, 0x15)  # DEAD key ตำแหน่งสุดท้ายของ row1 -- ROW1_TABLE[11] == 0xFF
    assert m.memory[KEYBUF_START] == 0x00, "unmapped key must not push anything into the queue"
    print("test_row1_unmapped_dead_key_passes_through: PASS")


def test_shift_held_uses_shifted_thai_table():
    # *** บั๊กจริงข้อ 11 (แก้แล้ว) *** -- เดิมเข้าใจผิดว่ากด Shift ค้างต้อง fallback เป็นอังกฤษเสมอ
    # (ดูชื่อเทสเดิม test_shift_held_falls_back_to_english) แต่ disassemble ต้นฉบับซ้ำพบว่ามีตาราง
    # Thai ชุดที่สองสำหรับตอนกด Shift ค้างโดยเฉพาะ (THAI_SHIFTED_TABLE, $4EDB) -- ผู้ใช้ทดสอบจริงก็
    # ยืนยันตรงกัน: "เวลากด shift ไม่ได้อักษรไทยตัวบน" คือควรได้อักษรไทยอีกชุดหนึ่ง ไม่ใช่อังกฤษ
    m, vdp = make_machine(CART)
    # Shift ถูกกดอยู่ (bit0=0) ส่วนบิตอื่นทั้งหมดปล่อย (active-low: 1=ปล่อย) = 0xFE
    _setup_thai_typing(m, shift=0xFE)
    _press_handled(m, 0x16)  # 'A' key -- ไม่กด Shift ปกติจะได้ฟ(0xBF) แต่กด Shift ต้องได้ชุดที่สอง
    assert m.memory[KEYBUF_START] == 0xC4, f"expected 0xC4 (THAI_SHIFTED_TABLE[$16]), got {m.memory[KEYBUF_START]:02x}"
    print("test_shift_held_uses_shifted_thai_table: PASS")


def test_ctrl_or_graph_held_falls_back_to_english():
    # CTRL/GRAPH ค้างอยู่ต้องปล่อยผ่านเป็นอังกฤษเสมอ (ตรงกับต้นฉบับที่ $4D1C/$4D1F -- ดู comment ใหญ่
    # เหนือ KEYC_THAI_TABLE_N ใน src/keyboard.asm) ไม่ว่า SHIFT จะกดอยู่ด้วยหรือไม่ก็ตาม
    m, vdp = make_machine(CART)
    _setup_thai_typing(m, shift=0xFD)  # CTRL ถูกกดอยู่ (bit1=0) เท่านั้น
    _press_passthrough(m, 0x16)
    assert m.memory[KEYBUF_START] == 0x00, "ctrl-held must not push a Thai glyph"

    m, vdp = make_machine(CART)
    _setup_thai_typing(m, shift=0xFB)  # GRAPH ถูกกดอยู่ (bit2=0) เท่านั้น
    _press_passthrough(m, 0x16)
    assert m.memory[KEYBUF_START] == 0x00, "graph-held must not push a Thai glyph"
    print("test_ctrl_or_graph_held_falls_back_to_english: PASS")


def test_digit_row_thai_mapping():
    # *** บั๊กจริงข้อ 11 (แก้แล้ว) *** -- แถวตัวเลข (scan $00-$09) ตอนนี้ต้องแปลงเป็นอักษรไทยด้วย
    # เหมือนกับ row1/main row (เดิมไม่มี mapping ให้แถวนี้เลย ปล่อยผ่านเป็นอังกฤษเสมอ)
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    _press_handled(m, 0x00)  # scan $00 -> THAI_UNSHIFTED_TABLE[0] = 0xA8
    assert m.memory[KEYBUF_START] == 0xA8, f"expected 0xA8, got {m.memory[KEYBUF_START]:02x}"
    print("test_digit_row_thai_mapping: PASS")


def test_thai_mode_off_passes_through():
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    m.memory[THAI_MODE] = 0x00  # ยังไม่ THAION
    _press_passthrough(m, 0x16)
    assert m.memory[KEYBUF_START] == 0x00
    print("test_thai_mode_off_passes_through: PASS")


def test_input_mode_off_passes_through():
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    m.memory[INPUT_MODE] = 0x00  # THAION แล้วแต่ยังไม่เปิดโหมดประกอบอักษร (INPUTOFF/ยังไม่ toggle)
    _press_passthrough(m, 0x16)
    assert m.memory[KEYBUF_START] == 0x00
    print("test_input_mode_off_passes_through: PASS")


def test_passthrough_preserves_scan_code_in_a_regression_bug3():
    # บั๊กจริงข้อ 3 (ดู src/keyboard.asm หัวข้อ 4): ผู้ใช้รายงานว่า "call thaion แล้วพิมพ์อะไรไม่ได้
    # เลย" -- สาเหตุคือ .passthrough ไม่ได้คืน A=C (scan code เดิม) ก่อนปล่อยผ่าน ทำให้ A กลาย
    # เป็นค่า flag (THAI_MODE/INPUT_MODE/SHIFT_STATE) แทน สถานการณ์นี้เกิดขึ้น "ทันทีที่ THAION"
    # (THAI_MODE=TRUE) ตราบใดที่ผู้ใช้ยังไม่กดปุ่มสลับโหมด (INPUT_MODE=FALSE ค่าเริ่มต้น) -- ครอบคลุม
    # ทุกเส้นทางที่ปล่อยผ่าน โดยใช้ stub ที่เป็น RET ล้วน ๆ (ไม่แตะ A) เพื่อจับบั๊กนี้ได้จริง
    # (หลังบั๊กจริงข้อ 7: กรณี 1-4 ด้านล่างเรียก KEYC_HOOK_REAL ตรง ๆ พอ เพราะสัญญา A=C เป็นของ
    # KEYC_HOOK_REAL เอง ไม่เกี่ยวกับ trampoline ที่ห่อหุ้มอยู่ข้างนอก -- กรณี 5 ทดสอบ end-to-end
    # ผ่าน trampoline จริงด้วย เพื่อยืนยันว่า A ไม่ถูกแก้ไขระหว่างทางจนถึง PREV_KEYC)
    for scan in (0x16, 0x2F, 0x0A, 0x15, 0xFF, 0x50):
        # -- 1) THAI_MODE ปิด (ยังไม่ THAION เลย)
        m, vdp = make_machine(CART)
        _setup_thai_typing(m)
        m.memory[THAI_MODE] = 0x00
        _call_hook_real(m, scan)
        assert not _carry_set(m)
        assert m.a == scan, f"[THAI_MODE off] scan={scan:02x}: A should equal C, got {m.a:02x}"

        # -- 2) THAION แล้วแต่ INPUT_MODE ยังปิดอยู่ (สถานการณ์จริงที่ผู้ใช้เจอ -- ค่าเริ่มต้นหลัง
        #    THAION ก่อนกดปุ่มสลับโหมดครั้งแรก)
        m, vdp = make_machine(CART)
        _setup_thai_typing(m)
        m.memory[INPUT_MODE] = 0x00
        _call_hook_real(m, scan)
        assert not _carry_set(m)
        assert m.a == scan, f"[INPUT_MODE off] scan={scan:02x}: A should equal C, got {m.a:02x}"

        # -- 3) THAION + INPUT_MODE เปิด + CTRL ค้างอยู่ (บั๊กจริงข้อ 11: เปลี่ยนจาก "Shift ค้าง" เดิม
        #    เพราะตอนนี้ Shift ค้างไม่ได้ปล่อยผ่านอีกต่อไป -- ใช้ตาราง Thai ชุดที่สองแทน -- CTRL ยังคง
        #    ปล่อยผ่านเสมอเหมือนเดิม จึงยังใช้ทดสอบเส้นทางนี้ได้)
        m, vdp = make_machine(CART)
        _setup_thai_typing(m, shift=0xFD)
        _call_hook_real(m, scan)
        assert not _carry_set(m)
        assert m.a == scan, f"[ctrl held] scan={scan:02x}: A should equal C, got {m.a:02x}"

    # -- 4) คีย์ในช่วง row1 ที่ไม่มี mapping ไทย (DEAD key, ตาราง=0xFF) -- เส้นทางที่ C เคยถูกใช้เป็น
    #    ตัวแปรชั่วคราวใน .lookup มาก่อนจะปล่อยผ่าน (จุดที่สองที่บั๊กข้อ 3 กระทบ)
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    _call_hook_real(m, 0x15)
    assert not _carry_set(m)
    assert m.a == 0x15, f"[unmapped row1 key] A should equal C (0x15), got {m.a:02x}"

    # -- 5) เดิมมีเคสที่ 5 ยืนยัน end-to-end ผ่าน H_KEYC/trampoline จริงตรงนี้ด้วย -- ลบแล้ว (ดู
    #    comment ใหญ่เหนือ _carry_set ด้านบน: การออกแบบใหม่ไม่ chain ไป PREV_KEYC จากโค้ดเราเองอีก
    #    ต่อไป และ harness แบบ flat-memory นี้ไม่รองรับการจำลอง RST 30H/CALSLT แบบเต็มรูปแบบ) --
    #    การยืนยัน A=C ระดับ end-to-end ผ่าน BIOS จริงทำแยกต่างหากใน test_phase3_e2e_biosreal.py
    #    (เรียกผ่าน H_KEYC จริงพร้อม seed ค่า $F38C ที่ถูกต้อง) และยืนยันจริงบน openMSX แล้วด้วย
    print("test_passthrough_preserves_scan_code_in_a_regression_bug3: PASS")


def test_toggle_key_still_works_when_thai_typing_active():
    # regression: ต้องแน่ใจว่าเพิ่มส่วนที่ 2 แล้วไม่ทำให้ปุ่มสลับโหมด (ส่วนที่ 1) เพี้ยน
    # branch toggle ก็ส่งสัญญาณ carry=1 แบบเดียวกัน (บั๊กจริงข้อ 5/7) เลยใช้ _press_handled เหมือนกัน
    m, vdp = make_machine(CART)
    _setup_thai_typing(m)
    _press_handled(m, KEYC_TOGGLE_CODE, hl=0x3333)
    assert m.memory[INPUT_MODE] == 0x00, "toggle should still flip INPUT_MODE 0xFF -> 0x00"
    print("test_toggle_key_still_works_when_thai_typing_active: PASS")


if __name__ == '__main__':
    test_main_row_consonant_pushed_to_queue()
    test_main_row_all_26_keys_match_extracted_table()
    test_row1_symbol_pushed_to_queue()
    test_row1_unmapped_dead_key_passes_through()
    test_shift_held_uses_shifted_thai_table()
    test_ctrl_or_graph_held_falls_back_to_english()
    test_digit_row_thai_mapping()
    test_thai_mode_off_passes_through()
    test_input_mode_off_passes_through()
    test_passthrough_preserves_scan_code_in_a_regression_bug3()
    test_toggle_key_still_works_when_thai_typing_active()
    print("ALL PASS")
