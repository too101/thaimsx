; ==========================================================================
; kbtables_data.asm -- ตารางคีย์บอร์ดไทย ดึงมาจากต้นฉบับ (ดู
; notes/keyboard_extraction.md สำหรับรายละเอียดการถอดรหัส) -- Phase 3 จะเขียน
; state machine ใหม่ที่ใช้ตารางเหล่านี้
; ==========================================================================

KB_DISPATCH:
	incbin "assets/kbtables/kb_dispatch_0x4c7a.bin"
KB_SHIFT_SYMBOLS:
	incbin "assets/kbtables/kb_shift_symbols_0x4c9e.bin"
KB_SHIFT4WAY_A:
	incbin "assets/kbtables/kb_shift4way_0x4ca8.bin"
KB_SHIFT4WAY_B:
	incbin "assets/kbtables/kb_shift4way_0x4cb0.bin"
KB_SYMBOLPAIRS:
	incbin "assets/kbtables/kb_symbolpairs_0x4cb8.bin"
