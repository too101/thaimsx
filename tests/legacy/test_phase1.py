import sys
sys.path.insert(0, '..')
from emutest import make_machine, call_routine

def _load_symbols(path='build/thairom.sym'):
    syms = {}
    with open(path) as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 3 and parts[1] == 'EQU':
                syms[parts[0]] = int(parts[2].rstrip('H'), 16)
    return syms


# *** บั๊กจริงข้อ 12 + การขยาย INIT (banner/thaion-default) -- ต้องอ่านตำแหน่งจริงจาก symbol table
# เสมอ ไม่ใช่ hardcode ที่นี่ (เดิม hardcode ตรง ๆ ในไฟล์นี้ ซึ่งไม่ sync กับ src/*.asm เมื่อ layout
# เปลี่ยน -- INIT/PROCNM/THAI_MODE ฯลฯ ล้วนเคยพังตามรูปแบบนี้มาแล้ว -- แก้ให้โหลดจาก
# build/thairom.sym เสมอแทน)
_SYM = _load_symbols()
INIT = _SYM['INIT']
STATEMENT = _SYM['STATEMENT']
PROCNM = _SYM['PROCNM']
THAI_MODE = _SYM['THAI_MODE']
PRINT_MODE = _SYM['PRINT_MODE']
INPUT_MODE = _SYM['INPUT_MODE']
PLOCK_MODE = _SYM['PLOCK_MODE']

def new_machine():
    return make_machine('build/thairom.rom', sys_rom_path='../MSX1_bios.rom')

def set_procnm(m, text):
    # PROCNM buffer: text followed by NUL padding (confirmed against REAL MSX1 BASIC
    # via openMSX debug memory read -- "THAION\0\0...", not space-terminated as first assumed)
    data = text.encode('ascii') + b'\x00\x00'
    for i, b in enumerate(data):
        m.memory[PROCNM + i] = b

def test_init_clears_flags():
    m, vdp = new_machine()
    m.memory[THAI_MODE] = 0xAA
    m.memory[PRINT_MODE] = 0xAA
    m.memory[INPUT_MODE] = 0xAA
    m.memory[PLOCK_MODE] = 0xAA
    ok, ev = call_routine(m, INIT, {})
    assert ok, f"INIT did not halt cleanly, ev={ev}"
    assert m.memory[THAI_MODE] == 0, "THAI_MODE not cleared"
    assert m.memory[PRINT_MODE] == 0, "PRINT_MODE not cleared"
    assert m.memory[INPUT_MODE] == 0, "INPUT_MODE not cleared"
    assert m.memory[PLOCK_MODE] == 0, "PLOCK_MODE not cleared"
    print("test_init_clears_flags: PASS")

def test_statement_match_printon():
    m, vdp = new_machine()
    set_procnm(m, "PRINTON")
    text_ptr = 0x9100
    ok, ev = call_routine(m, STATEMENT, {'hl': text_ptr})
    assert ok, f"STATEMENT did not halt cleanly, ev={ev}"
    carry = m.f & 1
    assert carry == 0, f"expected carry CLEAR on match (confirmed polarity from real ROM), f={m.f:#x}"
    assert m.memory[PRINT_MODE] == 0xFF, f"PRINT_MODE not set, got {m.memory[PRINT_MODE]:#x}"
    assert m.hl == text_ptr, f"HL not restored to continuation pointer, got {m.hl:#x}"
    print("test_statement_match_printon: PASS")

def test_statement_match_alias():
    m, vdp = new_machine()
    set_procnm(m, "?ON")
    ok, ev = call_routine(m, STATEMENT, {'hl': 0x9200})
    assert ok, f"STATEMENT did not halt cleanly, ev={ev}"
    carry = m.f & 1
    assert carry == 0, "expected carry CLEAR on alias match"
    assert m.memory[PRINT_MODE] == 0xFF
    print("test_statement_match_alias: PASS")

def test_statement_no_match():
    m, vdp = new_machine()
    set_procnm(m, "FOOBAR")
    text_ptr = 0x9300
    m.memory[PRINT_MODE] = 0x00
    ok, ev = call_routine(m, STATEMENT, {'hl': text_ptr})
    assert ok, f"STATEMENT did not halt cleanly, ev={ev}"
    carry = m.f & 1
    assert carry == 1, f"expected carry SET on no-match, f={m.f:#x}"
    assert m.hl == text_ptr, f"HL should be unchanged on no-match, got {m.hl:#x}"
    assert m.memory[PRINT_MODE] == 0x00, "no-match must not touch flags"
    print("test_statement_no_match: PASS")

def test_statement_plockon_blocks_printon():
    m, vdp = new_machine()
    # first PLOCKON
    set_procnm(m, "PLOCKON")
    ok, ev = call_routine(m, STATEMENT, {'hl': 0x9400})
    assert ok
    assert m.memory[PLOCK_MODE] == 0xFF
    # then try PRINTON -- should be blocked (PRINT_MODE stays 0)
    set_procnm(m, "PRINTON")
    m.memory[PRINT_MODE] = 0x00
    ok, ev = call_routine(m, STATEMENT, {'hl': 0x9500 - 0x10})
    assert ok
    carry = m.f & 1
    assert carry == 0, "PLOCKON-blocked PRINTON should still report carry clear (handled)"
    assert m.memory[PRINT_MODE] == 0x00, "PRINTON should be blocked by PLOCKON"
    print("test_statement_plockon_blocks_printon: PASS")

def test_statement_thaion_thaioff():
    m, vdp = new_machine()
    set_procnm(m, "THAION")
    ok, ev = call_routine(m, STATEMENT, {'hl': 0x9600})
    assert ok
    assert m.memory[THAI_MODE] == 0xFF
    set_procnm(m, "THAIOFF")
    m.memory[PRINT_MODE] = 0xFF
    m.memory[INPUT_MODE] = 0xFF
    m.memory[PLOCK_MODE] = 0xFF
    ok, ev = call_routine(m, STATEMENT, {'hl': 0x9700})
    assert ok
    assert m.memory[THAI_MODE] == 0
    assert m.memory[PRINT_MODE] == 0
    assert m.memory[INPUT_MODE] == 0
    assert m.memory[PLOCK_MODE] == 0
    print("test_statement_thaion_thaioff: PASS")

if __name__ == "__main__":
    test_init_clears_flags()
    test_statement_match_printon()
    test_statement_match_alias()
    test_statement_no_match()
    test_statement_plockon_blocks_printon()
    test_statement_thaion_thaioff()
    print("ALL PASS")
