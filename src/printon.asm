; ==========================================================================
; printon.asm -- PRINTON: แสดงผลอักษรไทยแบบ "ซ้อน 3 ระดับ" (สระบน + วรรณยุกต์
; ซ้อนเหนือพยัญชนะ ในคอลัมน์เดียวกัน) ผู้ใช้ยืนยันแล้วว่าพฤติกรรมจริงคือ
; "24 บรรทัดจะเหลือ 8 บรรทัดโดยใช้ 3 line ต่อบรรทัด" -- ตรงกับที่พบจากการ
; disassemble ROM ต้นฉบับ (ดู printon_algorithm_report.md): กลไกจริงคือการซ้อน
; ตัวอักษรข้าม "แถวจริง" ของ name table (แถว-1 / แถว-2 เทียบกับแถวปัจจุบัน)
; ไม่ใช่การ OR บิตแพตเทิร์นแบบที่ SPEC_TH.md ฉบับร่างแรกเข้าใจผิดไว้
;
; ---- ปัญหาสถาปัตยกรรมหลักที่ต้องแก้ (ทำไมถึงยากกว่า H_KEYC) ----
; CHPUT ตัวจริงของ BIOS (เรียกผ่าน jump table CHPUT=$00A2) เรียก "CALL H_CHPUT"
; เป็นก้าวแรกเสมอ แล้ว**เดินหน้าวาดตัวอักษร default ต่อไปเองแบบไม่มีเงื่อนไข**
; ไม่ว่า hook จะทำอะไรก็ตาม -- ไม่มีสัญญาณ carry/flag ใด ๆ ให้ hook บอกว่า "ฉัน
; จัดการเองแล้ว ข้ามการวาด default ที" (ต่างจาก H_KEYC ที่มีสัญญาณ carry ชัดเจน)
; ต้นฉบับ MSXTHA102 แก้ปัญหานี้ด้วยการ "แก้ return address บน stack" (stack-
; hijack ไปยัง literal address ภายใน CHPUT) ซึ่งโปรเจกต์นี้ห้ามใช้ (ดู SPEC_TH.md
; section 0) เพราะ fragile และไม่ portable ข้าม MSX generation
;
; ---- วิธีแก้แบบ portable ที่ใช้ในไฟล์นี้ ----
; disassemble CHPUT ตัวจริงตรง ๆ (MSX1_bios.rom 0x08BC-0x08DE) พบว่า:
;   1. A (ตัวอักษร) ถูก PUSH ไว้ "ก่อน" เรียก H_CHPUT แล้ว POP กลับมาใช้ทีหลัง --
;      hook เปลี่ยนค่า A ที่ส่งกลับไม่ได้ (BIOS ใช้ค่าเดิมเสมอ)
;   2. แต่ตำแหน่งที่จะวาด (CSRY/CSRX ที่ $F3DC/$F3DD) ถูก "อ่านสดจาก RAM" ทุกครั้ง
;      ก่อนวาดจริง (LD HL,(CSRY) ที่ 0x08F3) -- ไม่ได้ผ่าน register ที่ hook คุมได้
;      โดยตรง แต่ hook แก้ค่าใน RAM ตรง ๆ ได้ก่อน return!
; ดังนั้น hook นี้ "แก้ CSRY/CSRX ชั่วคราว" ให้ BIOS ไปวาดตัวอักษร (สระ/วรรณยุกต์)
; ที่ตำแหน่งซ้อน (แถวบน, คอลัมน์เดิมของพยัญชนะ) แทนตำแหน่ง cursor จริง -- ให้ BIOS
; วาด+เลื่อน cursor ของมันเองตามปกติ (ไม่ต้องยุ่งกับการวาดเอง เลี่ยง WRTVRM ซ้ำซ้อน)
; แล้วค่อย "คืนค่า CSRY ที่ถูกต้อง" ในการเรียก hook **ครั้งถัดไป** (เพราะไม่มีจุด
; ให้รันโค้ดหลัง BIOS วาด+เลื่อนเสร็จในรอบเดียวกันเลย) -- ดู comment เต็มที่ PRINTHOOK
;
; ตรวจสอบสูตรคำนวณ VRAM address ((CSRY-1)*40+CSRX, ใช้ NAMPNT เป็น base) ตรงจาก
; disassembly ของ CALC_ADDR ($0BF2) เอง -- LINLEN ไม่เกี่ยวกับสูตรนี้เลยตอน SCRMOD=0
; (ดู comment ที่ LINLEN equate ใน equates.asm)
;
; ---- ขอบเขตที่ implement จริง (แก้ไขรอบสอง -- ดูประวัติที่ git log/SPEC_TH.md 9.17 สำหรับ
; ความเข้าใจรอบแรกที่ผิด) ----
; รอบแรก implement ผิด 2 จุด แก้แล้วตามที่ผู้ใช้ชี้ + ยืนยันด้วยฟอนต์บิตแมปจริงที่ผู้ใช้อัปโหลด
; (thaifont.asm, pixel-match ตรงกับทุกไบต์ที่เกี่ยวข้อง):
;   1. วรรณยุกต์ที่ตามหลังสระบนที่มีอยู่แล้ว **ต้องผสมเป็น glyph เดียว** (โค้ด 0x83-0x91 ในฟอนต์
;      -- ดู COMBINE_TABLE) วาดทับตำแหน่งสระบนเดิมที่แถว-1 -- ไม่ใช่ซ้อนแถว-2 แยกต่างหากแบบที่
;      เข้าใจผิดไว้รอบแรก (โค้ด 0x82-0x9D ที่เคยว่า "ความหมายไม่ชัดเจน" ตอนนี้ยืนยันแล้วว่าคือ
;      glyph ผสมสระบน+วรรณยุกต์เหล่านี้เอง) ถ้าลบวรรณยุกต์ที่ผสมไปออกด้วย Backspace ทันที ต้อง
;      undo กลับเป็นสระบนเปล่า ๆ ด้วย (ผู้ใช้ยืนยัน) -- ดู PRINT_COMBINE_*/PRINT_LAST_MARK_*
;      ใน equates.asm และ COMBINE_LOOKUP/COMBINE_TABLE ด้านล่าง
;   2. (แก้ใน 9.19) ตารางจัดกลุ่มเครื่องหมายเดิมผิด -- ฟอนต์เป็นรหัส TIS-620 (ยืนยันจาก pixel ของ
;      font_raw.bin เอง): สระบน D1,D4,D5,D6,D7,E7,ED / วรรณยุกต์ E8-EC / สระล่าง D8,D9,DA
;      (เดิมเข้าใจผิดว่า D6/D7 เป็นสระล่าง) ดูตารางจริงที่ UPPER_VOWEL_TABLE ด้านล่าง
;   3. (9.19) ตัวแก้ไขบรรทัดของ BIOS อ่านบรรทัดกลับจากจอเฉพาะแถวกลาง -- INLIN_REBUILD ประกอบ BUF
;      ใหม่ให้รวมแถวบน/ล่างด้วย + CHGE_HOOK คืน CSRY แถวจริงก่อนรอคีย์ทุกครั้ง (ดูท้ายไฟล์)
; ==========================================================================

; ---- PRINTHOOK_INSTALL / PRINTHOOK_UNINSTALL -----------------------------
; เรียกจาก CMD_THAION/CMD_THAIOFF (เหมือน KEYC_INSTALL/UNINSTALL ทุกประการ --
; ดู comment เต็มที่ KEYC_INSTALL ใน keyboard.asm สำหรับรายละเอียดของรูปแบบ RST
; 30H/CALLF 5 ไบต์) -- ใช้ MY_SLOT_ID ที่ KEYC_INSTALL คำนวณไว้แล้วซ้ำ (เรียก
; PRINTHOOK_INSTALL "หลัง" KEYC_INSTALL เสมอใน CMD_THAION ดังนั้น MY_SLOT_ID
; valid แล้วแน่นอน ไม่ต้องคำนวณซ้ำ)
;
; หมายเหตุ: hook นี้ติดตั้งอยู่ตลอดเวลาที่ THAION (ไม่ผูกกับ PRINT_MODE โดยตรง)
; แต่ตัว PRINTHOOK เองเช็ค PRINT_MODE ทุกครั้งที่ถูกเรียก แล้ว "ปล่อยผ่านทันที"
; ถ้า PRINTON ยังไม่ได้เปิด -- เพื่อไม่ต้องมี hook installer/uninstaller แยกอีก
; ชุดสำหรับ PRINTON/PRINTOFF (ซึ่งสลับบ่อยกว่า THAION/THAIOFF มาก และ toggle
; แค่ flag เฉย ๆ ก็พอ ไม่จำเป็นต้องติดตั้ง/ถอด hook จริงทุกครั้ง)
PRINTHOOK_INSTALL:
	di
	xor a
	ld (ix+PRINT_REDIRECT),a      ; เริ่มต้นสภาวะ clean เสมอ (กัน state ค้างจาก THAION รอบก่อน)
	ld a,(H_CHPUT)
	ld (ix+PREV_CHPUT),a
	ld a,(H_CHPUT+1)
	ld (ix+PREV_CHPUT+1),a
	ld a,(H_CHPUT+2)
	ld (ix+PREV_CHPUT+2),a
	ld a,(H_CHPUT+3)
	ld (ix+PREV_CHPUT+3),a
	ld a,(H_CHPUT+4)
	ld (ix+PREV_CHPUT+4),a
	ld a,(ix+MY_SLOT_ID)          ; คำนวณไว้แล้วโดย KEYC_INSTALL ที่เรียกก่อนหน้านี้เสมอ
	ld (H_CHPUT+1),a
	ld hl,PRINTHOOK
	ld (H_CHPUT+2),hl
	ld a,$C9                   ; RET
	ld (H_CHPUT+4),a
	ld a,RST30_OPCODE
	ld (H_CHPUT),a
	; --- 9.19: hook เพิ่ม 3 ตัว (ดู INLIN_REBUILD / CHGE_HOOK ด้านล่าง) ---
	xor a
	ld (ix+INLIN_ACTIVE),a
	ld hl,H_CHGE
	ld de,PREV_CHGE
	call IX_DE                  ; 9.27: offset -> address จริงในบล็อก
	ld bc,CHGE_HOOK
	call HOOK_INSTALL
	ld hl,H_PINL
	ld de,PREV_PINL
	call IX_DE                  ; 9.27: offset -> address จริงในบล็อก
	ld bc,INLIN_HOOK
	call HOOK_INSTALL
	ld hl,H_INLI
	ld de,PREV_INLI
	call IX_DE                  ; 9.27: offset -> address จริงในบล็อก
	ld bc,INLIN_HOOK
	call HOOK_INSTALL
	; --- 9.21: cursor แยกสถานะไทย/อังกฤษ ---
	xor a
	ld (ix+IN_CHGET),a
	ld (ix+CUR_WAITING),a
	ld (ix+BLINK_OFF),a
	ld hl,H_DSPC
	ld de,PREV_DSPC
	call IX_DE                  ; 9.27: offset -> address จริงในบล็อก
	ld bc,DSPC_HOOK
	call HOOK_INSTALL
	ld hl,H_ERAC
	ld de,PREV_ERAC
	call IX_DE                  ; 9.27: offset -> address จริงในบล็อก
	ld bc,ERAC_HOOK
	call HOOK_INSTALL
	ld hl,H_TIMI                  ; 9.26: กระพริบ cursor ภาษาไทย (ส่งต่อ hook เดิมเสมอ)
	ld de,PREV_TIMI
	call IX_DE                  ; 9.27: offset -> address จริงในบล็อก
	ld bc,TIMI_HOOK
	call HOOK_INSTALL
	ei
	ret

PRINTHOOK_UNINSTALL:
	di
	ld a,(ix+PREV_CHPUT)
	ld (H_CHPUT),a
	ld a,(ix+PREV_CHPUT+1)
	ld (H_CHPUT+1),a
	ld a,(ix+PREV_CHPUT+2)
	ld (H_CHPUT+2),a
	ld a,(ix+PREV_CHPUT+3)
	ld (H_CHPUT+3),a
	ld a,(ix+PREV_CHPUT+4)
	ld (H_CHPUT+4),a
	; --- 9.19: คืน hook 3 ตัวที่ติดตั้งเพิ่ม (ldir คืนไบต์ opcode ตัวแรกก่อนเสมอ ตามกติกาเดิม) ---
	ld hl,PREV_CHGE
	call IX_HL                  ; 9.27: offset -> address จริงในบล็อก
	ld de,H_CHGE
	ld bc,5
	ldir
	ld hl,PREV_PINL
	call IX_HL                  ; 9.27: offset -> address จริงในบล็อก
	ld de,H_PINL
	ld bc,5
	ldir
	ld hl,PREV_INLI
	call IX_HL                  ; 9.27: offset -> address จริงในบล็อก
	ld de,H_INLI
	ld bc,5
	ldir
	ld hl,PREV_DSPC
	call IX_HL                  ; 9.27: offset -> address จริงในบล็อก
	ld de,H_DSPC
	ld bc,5
	ldir
	ld hl,PREV_ERAC
	call IX_HL                  ; 9.27: offset -> address จริงในบล็อก
	ld de,H_ERAC
	ld bc,5
	ldir
	ld hl,PREV_TIMI
	call IX_HL                  ; 9.27: offset -> address จริงในบล็อก
	ld de,H_TIMI
	ld bc,5
	ldir
	xor a
	ld (ix+INLIN_ACTIVE),a
	ld (ix+CUR_WAITING),a
	ei
	ret

; ---- HOOK_INSTALL (9.19) ------------------------------------------------------
; รูปแบบเดียวกับ PRINTHOOK_INSTALL ด้านบนทุกประการ แค่ทำเป็น routine กลาง
; entry: HL = hook slot (5 ไบต์), DE = ที่สำรองเนื้อ hook เดิม (5 ไบต์), BC = handler
; ผู้เรียกต้อง DI ไว้แล้ว -- เขียนไบต์ opcode (RST 30H) เป็นไบต์สุดท้าย ให้ทุกจังหวะที่ hook
; อาจถูกเรียกระหว่างเขียนยังเป็นโค้ดที่ปลอดภัยเสมอ (กติกาเดียวกับ KEYC_INSTALL)
HOOK_INSTALL:
	push hl
	push bc
	ld bc,5
	ldir                       ; สำรอง hook เดิม
	pop bc
	pop hl
	push hl
	inc hl
	ld a,(ix+MY_SLOT_ID)
	ld (hl),a
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld (hl),$C9                ; RET
	pop hl
	ld (hl),RST30_OPCODE
	ret

; ---- INLIN_HOOK (9.19) --------------------------------------------------------
; ติดตั้งที่ทั้ง H_PINL และ H_INLI -- BIOS เรียกตอนเริ่มรับบรรทัดทุกแบบ (direct mode/โปรแกรม,
; INPUT, LINE INPUT) แค่ตั้ง flag ว่า "กำลังรับบรรทัด" (เฉพาะตอน PRINTON เปิด) ให้ PRINTHOOK รู้ว่า
; LF ตัวถัดไปคือ LF ที่ BIOS พิมพ์หลังอ่านบรรทัดจากจอเข้า BUF เสร็จแล้ว (ดู INLIN_REBUILD)
INLIN_BODY:
	push af
	ld a,(ix+PRINT_MODE)
	ld (ix+INLIN_ACTIVE),a
	xor a
	ld (ix+THAI_INS),a               ; 9.25: เริ่มบรรทัดใหม่ = ไม่อยู่โหมด INS (เหมือน BIOS)
	pop af
	ret

; ---- CHGE_HOOK (9.19) ---------------------------------------------------------
; H_CHGE ถูกเรียกตอนต้น CHGET ทุกครั้ง (MSX1/2/2+ ที่ $10CE เหมือนกัน) = ก่อนรอคีย์ถัดไป ก่อน
; แสดง cursor -- จุดที่เร็วที่สุดหลัง BIOS วาดสระ/วรรณยุกต์ที่ตำแหน่งซ้อนเสร็จ
; ปัญหาเดิม: PRINTHOOK คืน CSRY แถวจริง "ตอน CHPUT ครั้งถัดไป" เท่านั้น -- ถ้าตัวสุดท้ายที่พิมพ์ก่อน
; กด Enter เป็นสระ/วรรณยุกต์ CSRY ยังค้างอยู่แถวบน/ล่าง ตอน BIOS อ่านบรรทัด (Enter ไม่ผ่าน CHPUT
; ก่อนอ่าน) BIOS จะอ่านแถวผิดไปทั้งบรรทัด และ cursor กระพริบผิดแถว -- แก้โดย resync ที่นี่ด้วย
; (+ แก้ glyph ผสมที่ค้างไว้ทันที ไม่ต้องรอคีย์ถัดไปแบบข้อจำกัดเดิมใน 9.18)
CHGE_BODY:
	push hl
	push de
	push bc
	push af
	ld a,TRUE
	ld (ix+IN_CHGET),a               ; 9.21: cursor ที่จะวาดถัดไปคือ cursor รอคีย์ของ CHGET
	call FONT_CHECK               ; 9.23: SCREEN/WIDTH โหลดฟอนต์ระบบทับ -> ใส่ฟอนต์ไทยคืน
	ld a,(ix+PRINT_MODE)
	or a
	jr z,.chge_done
	call PRINT_RESYNC
	; 9.25: รับโหมด INS มาทำเอง -- BIOS กลับค่า INSFLG ตอนกดปุ่ม INS ($24E5) เราเห็นตรงนี้ (ก่อนรอคีย์
	; ถัดไป) แล้วสลับ THAI_INS แทน ตั้ง INSFLG กลับเป็น 0 ให้ BIOS พิมพ์ทับเสมอ (ไม่เลื่อนแถวกลางเอง
	; ซึ่งไม่รู้จักแถวสระบน/ล่างและการต่อแถว 3 ชั้น) -- เราเลื่อนเองใน INSCOL ตอน CHPUT
	ld a,(ix+INLIN_ACTIVE)
	or a
	jr z,.chge_done
	ld a,(INSFLG)
	or a
	jr z,.chge_done
	xor a
	ld (INSFLG),a
	ld a,(ix+THAI_INS)
	cpl
	ld (ix+THAI_INS),a
	ld (CSTYLE),a                 ; รูป cursor: INS = ขีดล่าง (หรือแถบซ้ายตอนภาษาไทย)
.chge_done:
	pop af
	pop bc
	pop de
	pop hl
	ret

; ---- COMBINE_FIX ----------------------------------------------------------------
; (แยกออกมาจาก PRINTHOOK ขั้น 1.6 เดิมเพื่อให้ CHGE_HOOK เรียกซ้ำได้ -- โค้ดเดิมทุกประการ)
; ถ้ามี glyph ผสมค้างอยู่ (PRINT_COMBINE_PENDING) เขียนทับลง VRAM แล้วเคลียร์ flag
; ทำลาย A/DE/HL (BC คงเดิม)
COMBINE_FIX:
	ld a,(ix+PRINT_COMBINE_PENDING)
	or a
	ret z
	xor a
	ld (ix+PRINT_COMBINE_PENDING),a
	push bc
	ld a,(ix+PRINT_COMBINE_ROW)
	ld d,a
	ld a,(ix+PRINT_COMBINE_COL)
	ld e,a
	ld a,d
	call NAMETAB_ADDR
	ld a,(ix+PRINT_COMBINE_CODE)
	call WRTVRM
	pop bc
	ret

; ---- PRINTHOOK -------------------------------------------------------------
; เรียกจาก CHPUT จริงของ BIOS ผ่าน H_CHPUT ก่อนวาดตัวอักษร (ดู comment ใหญ่
; ด้านบนของไฟล์นี้สำหรับที่มาของกลไกทั้งหมด) -- contract: เข้ามาด้วย A=ตัวอักษร
; ที่กำลังจะพิมพ์ (BIOS จะใช้ค่า A เดิมเสมอไม่ว่า hook จะทำอะไร -- แก้ A ไม่มีผล)
; PRESERVE ทุก register (AF/BC/DE/HL) ก่อน RET เสมอ ตามสัญญาของ H.xxx hook
; มาตรฐาน แม้ analysis จะพบว่า BIOS ไม่ได้พึ่งพาค่าที่ hook คืนจริง ๆ ก็ตาม (ทำ
; เพื่อความปลอดภัย -- เผื่อ hook ตัวอื่นถูก chain ต่อ หรือ BIOS variant อื่นพึ่งพา)
; หมายเหตุการจอง register ตลอดฟังก์ชันนี้ (สำคัญ -- อ่านก่อนแก้):
;   C = ตัวอักษรที่กำลังพิมพ์ (ใช้ชั่วคราวแค่ตอน classify แรก, หลังจากนั้นใช้เป็น
;       scratch ได้อิสระ)
;   E = คอลัมน์เป้าหมาย (CSRX-1) -- คงค่าตลอดตั้งแต่คำนวณได้จนถึงขั้นสุดท้าย เพราะ
;       ยืนยันแล้วว่า NAMETAB_ADDR/RDVRM/CLASSIFY_THAI_MARK/COMBINE_LOOKUP ไม่แตะ E เลย
;       (มีแค่ D ที่ NAMETAB_ADDR เซ็ตเป็น 0 เป็นผลข้างเคียง)
;   D = scratch อิสระตลอด (ไม่มีความหมาย "depth" อีกต่อไป -- รอบแรกเคยใช้เก็บ depth 1/2
;       แต่แก้เป็นระบบ "ผสม glyph เดียว" แล้ว ไม่ต้องมี 2 ระดับแยกอีก ดู comment ใหญ่บนสุดไฟล์)
PRINTHOOK_BODY:
	push hl
	push de
	push bc
	push af
	xor a
	ld (ix+IN_CHGET),a               ; 9.21: cursor ที่ CHPUT วาด (ถ้ามี) ไม่ใช่ cursor รอคีย์
	pop af
	push af
	cp $80
	call nc,FONT_CHECK            ; 9.23: จะพิมพ์อักษรไทย -- เช็คว่าฟอนต์ไทยยังอยู่ใน VRAM
	ld a,(ix+PRINT_IN_LF)            ; 9.20: CHPUT(LF) ที่เราเรียกซ้อนเองตอน scroll -- ปล่อยผ่าน
	or a
	jp nz,.done
	pop af
	push af
	cp SELECT_CODE             ; 9.30 (A2): ปุ่ม SELECT (INLIN ส่ง $18 มาที่ CHPUT) สลับ PRINTON/PRINTOFF
	jr nz,.not_select
	call SELECT_TOGGLE
	jp .done
.not_select:
	ld a,(ix+PRINT_MODE)
	or a
	jp z,.done                 ; PRINTON ยังไม่เปิด -- ปล่อยผ่าน ไม่ทำอะไรเลย (jp เพราะ .done
	                           ; อยู่ไกลเกิน range ของ jr แล้วหลังจากฟังก์ชันขยายใหญ่ขึ้น)
	; ปิด blinking-cursor ไว้ตลอดที่ PRINTON เปิด (ทุกครั้งที่ hook ทำงาน -- กันเหนียวเรื่อย ๆ)
	; -- ดูเหตุผลเต็มที่ CURSOR_BLINK_FLAG equate ใน equates.asm (กัน blink ไปวาดทับตัวอักษร
	; ที่ซ้อนไว้ระหว่างที่ CSRY ยังไม่ถูก resync)
	xor a
	ld (CURSOR_BLINK_FLAG),a
	pop af
	push af
	ld c,a                     ; C = ตัวอักษรที่กำลังพิมพ์
	call PRINT_RESYNC          ; 9.25: รวมขั้น 1/1.6 เดิม + ghost + ต่อแถว (ใช้ร่วมกับ CHGE_HOOK)
	pop af
	push af
	ld c,a
	jr .after_resync

	; --- ขั้น 1: sync CSRY แถวจริง (คืนค่าจากรอบก่อนถ้าเคยยักย้ายไว้) ---
	ld a,(ix+PRINT_REDIRECT)             ; (โค้ดเดิม -- ข้ามแล้ว ดู PRINT_RESYNC)
	or a
	jr z,.refresh_shadow
	ld a,(ix+PRINT_ROW)
	ld (CSRY),a
	xor a
	ld (ix+PRINT_REDIRECT),a
	jr .classify
.refresh_shadow:
	; รอบก่อนเป็นตัวอักษรปกติ (ไม่ได้ยักย้าย) -- CSRY ตอนนี้ถูกต้องอยู่แล้ว รีเฟรช
	; เงาไว้เผื่อรอบนี้ต้องยักย้าย
	ld a,(CSRY)
	ld (ix+PRINT_ROW),a

.classify:
	; --- ขั้น 1.6 (ใหม่): แก้ VRAM ค้างจากการ "ผสม" สระบน+วรรณยุกต์ของรอบก่อน (ถ้ามี) ---
	; ดู comment เต็มที่ PRINT_COMBINE_PENDING ใน equates.asm: hook ไม่มีทางแทนที่ตัวอักษรที่
	; BIOS กำลังจะวาดได้เลย (แค่ยักย้ายตำแหน่งได้) จึงปล่อยให้ BIOS วาดวรรณยุกต์ตัวเปล่าทับ
	; ตำแหน่งสระบนไปก่อน (ผิดชั่วคราว 1 จังหวะ) แล้วมาแก้ทับด้วย WRTVRM ตรงนี้ตอนเรียกครั้งถัดไป
	; ก่อนประมวลผลตัวอักษรใหม่ใด ๆ เลย -- ไม่แตะ D/E เพราะยังไม่ถูกใช้งานตอนนี้ (กำหนดใหม่ทุกครั้ง
	; ที่ขั้น 3/5 ด้านล่าง) จึงปลอดภัยที่จะใช้เป็น scratch ตรงนี้ได้อิสระ
	call COMBINE_FIX                  ; (9.19: แยกเป็น routine ให้ CHGE_HOOK ใช้ร่วม -- BC คงเดิม)
.after_resync:
	; --- 9.20: BS/DEL ของตัวแก้ไขบรรทัดขณะ PRINTON (KEYC_HOOK ส่งมาเป็นโค้ดส่วนตัว) ---
	ld a,c
	cp THAI_BS_CODE
	jp z,.thai_bs
	cp THAI_DEL_CODE
	jp z,.thai_del
	; --- ขั้น 1.7 (ใหม่): Backspace ($08) ลบวรรณยุกต์ที่เพิ่งผสมไปเมื่อกี้ -- ต้องกลับไปแสดง
	; สระบนเดิมเปล่า ๆ (ไม่ใช่ glyph ผสม) ผู้ใช้ยืนยันเอง: "ถ้าลบวรรณยุกต์ออกต้องกลับมาวาดสระบน"
	; -- valid แค่ตัวถัดไปที่พิมพ์ "ทันที" หลังผสมเท่านั้น (ดู PRINT_LAST_MARK_* ใน equates.asm)
	ld a,c
	cp 8                              ; BS?
	jr nz,.notbs
	ld a,(ix+PRINT_LAST_MARK_VALID)
	cp TRUE
	jr nz,.notbs                      ; ไม่มีการผสมค้างให้ undo -- ปล่อยผ่าน BS ตามปกติ
	                                  ; (9.20: ค่า 1 = เครื่องหมายเดี่ยว ใช้เฉพาะ BS ของตัวแก้ไขบรรทัด)
	xor a
	ld (ix+PRINT_LAST_MARK_VALID),a
	push bc
	push de
	ld a,(ix+PRINT_LAST_MARK_ROW)
	ld d,a
	ld a,(ix+PRINT_LAST_MARK_COL)
	ld e,a
	ld a,d
	call NAMETAB_ADDR
	ld a,(ix+PRINT_LAST_MARK_VOWEL)
	call WRTVRM
	pop de
	pop bc
	jp .done                          ; BS เอง: ปล่อยให้ BIOS เลื่อน cursor กลับตามปกติ (control
	                                   ; code <0x20 ไม่ผ่าน VRAM write ใด ๆ จาก BIOS อยู่แล้ว --
	                                   ; เราแค่แก้เนื้อ VRAM ของช่องซ้อนเพิ่มเข้ามาเท่านั้น)
.notbs:
	; ไม่ใช่ BS -- ปิดโอกาส undo ทิ้ง (ใช้ได้แค่ตัวถัดจากการผสมทันทีเท่านั้น ป้องกัน undo ผิดจังหวะ
	; ถ้าผู้ใช้พิมพ์ตัวอื่นคั่นก่อนค่อยกด BS) -- กรณีนี้พิมพ์ตัวใหม่ไปแล้ว ไม่ผสม ไม่ต้อง undo
	xor a
	ld (ix+PRINT_LAST_MARK_VALID),a

	; --- ขั้น 1.5: LF (ขึ้นบรรทัดใหม่จริง) ตอน PRINTON ต้องเว้น 3 แถวจริงต่อบรรทัด
	; ตรรกะ ไม่ใช่ 1 แถวแบบปกติ (ยืนยันจากผู้ใช้เอง: "24 บรรทัดจะเหลือ 8 บรรทัดโดยใช้ 3
	; line ต่อบรรทัด") -- BIOS จัดการ CR/LF แยกกัน (CR แค่รีเซ็ตคอลัมน์, LF คือตัวที่เลื่อน
	; แถว+1 จริง ยืนยันจาก breakpoint trace) เราเลยแค่ "โก่ง" CSRY ล่วงหน้า +2 ก่อนคืน
	; ให้ BIOS ทำ +1 ของมันเองตามปกติ รวมเป็น +3 สุทธิ -- ไม่ผูกกับกลไก PRINT_REDIRECT
	; (ซึ่งมีไว้สำหรับ "ยักย้ายชั่วคราวแล้วคืนคราวหน้า" เท่านั้น) เพราะการเลื่อนบรรทัดนี้เป็น
	; การเปลี่ยนแถว "จริง/ถาวร" ไม่ใช่การซ้อนชั่วคราว
	; *** ข้อจำกัดที่ทราบ (ยังไม่ครบ 100%): ยังไม่ได้จัดการกรณีใกล้ขอบล่างจอ (เสี่ยง scroll
	; ผิดจังหวะ) -- กันไว้คร่าว ๆ ด้วยการข้ามการโก่งถ้า CSRY มากกว่า 21 (โก่งแล้วจะเกิน 24)
	ld a,c
	cp 10                          ; LF?
	jr nz,.notlf
	; --- 9.19: LF นี้คือ LF ที่ BIOS พิมพ์หลังอ่านบรรทัดจากจอเข้า BUF เสร็จหรือไม่ (ดู INLIN_HOOK) ---
	; ถ้าใช่ ประกอบ BUF ใหม่จากจอโดยรวมแถวบน/ล่างเข้าไปด้วย ก่อนโก่ง CSRY +2 ด้านล่าง (ตอนนี้ CSRY
	; ยังอยู่ที่แถวของบรรทัดที่เพิ่งอ่านพอดี -- BIOS ย้าย cursor ไปท้ายบรรทัดด้วย ESC Y ก่อนพิมพ์ LF)
	ld a,(ix+INLIN_ACTIVE)
	or a
	jr z,.lf_bump
	xor a
	ld (ix+INLIN_ACTIVE),a
	call INLIN_REBUILD
.lf_bump:
	ld a,(ix+PRINT_MODE)
	; หมายเหตุ: มาถึงจุดนี้ได้แปลว่า PRINT_MODE=TRUE แน่นอนอยู่แล้ว (เช็คตั้งแต่ต้น
	; PRINTHOOK) แต่เช็คซ้ำเผื่อโค้ดข้างบนถูกแก้ในอนาคต -- ไม่เสียหาย
	or a
	jr z,.notlf
	; 9.20: ขึ้นบรรทัดใหม่ = 3 แถวเสมอ แม้อยู่ใกล้ขอบล่าง (เดิมข้ามการโก่งแล้ว BIOS scroll ทีละแถว
	; ทำให้ layout 3 แถวพัง) -- แถวใหม่ T ต้องมีแถวสระล่าง (T+1) อยู่ในจอ: T <= ล่างสุด-1
	;   R+3 <= B-1 : โก่ง CSRY +2 แล้วให้ BIOS +1 เหมือนเดิม
	;   ไม่งั้น   : ย้าย cursor ไปแถวล่างสุด B แล้วเรียก CHPUT(LF) เองซ้ำ s = R+4-B ครั้ง (BIOS scroll
	;               ให้ครั้งละแถว พร้อมดูแล LINTTB เอง) แล้ววาง CSRY=B-2 ให้ LF ของ BIOS พาไป B-1
	call GET_BOTTOM
	ld b,a
	ld a,(CSRY)
	add a,4
	cp b
	jr z,.lf_simple
	jr c,.lf_simple
	sub b
	ld b,a                        ; B = จำนวนแถวที่ต้อง scroll
	call GET_BOTTOM
	ld (CSRY),a
	ld a,TRUE
	ld (ix+PRINT_IN_LF),a
.lf_scroll:
	push bc
	ld a,10
	call CHPUT_IX
	pop bc
	djnz .lf_scroll
	xor a
	ld (ix+PRINT_IN_LF),a
	call GET_BOTTOM
	sub 2
	ld (CSRY),a
	jp .done
.lf_simple:
	ld a,(CSRY)
	add a,2
	ld (CSRY),a
	jp .done
.notlf:
	; --- 9.25: ปุ่มลูกศรขณะ PRINTON: ขึ้น/ลงทีละ 3 แถว (อยู่บนแถวข้อความเสมอ ไม่ตกไปแถวสระ) และ
	; ซ้าย/ขวาข้ามแถวต่อแบบ 3 ชั้น -- ตั้ง CSRY ล่วงหน้าให้การเลื่อน 1 ช่องของ BIOS ไปลงที่ที่ถูกพอดี ---
	ld a,c
	cp $1C
	jp c,.notarrow
	cp $20
	jp nc,.notarrow
	ld a,(ESCCNT)
	or a
	jp nz,.done
	xor a
	ld (ix+THAI_INS),a               ; ลูกศรยกเลิกโหมด INS (เหมือน BIOS $2428)
	ld a,c
	cp $1C
	jr z,.ar_right
	cp $1D
	jr z,.ar_left
	cp $1E
	jr z,.ar_up
	; $1F ลง: +3 ถ้าแถวใหม่ยังมีแถวสระล่างในจอ
	call GET_BOTTOM
	ld b,a
	ld a,(CSRY)
	add a,4
	cp b
	jr z,.ar_down_ok
	jp nc,.done
.ar_down_ok:
	ld a,(CSRY)
	add a,2
	ld (CSRY),a
	jp .done
.ar_up:
	ld a,(CSRY)
	cp 4
	jp c,.done
	sub 2
	ld (CSRY),a
	jp .done
.ar_left:
	ld a,(CSRX)
	cp 1
	jp nz,.done
	ld a,(CSRY)
	call LT_FLAGS
	and LT_UP
	jp z,.done
	ld a,(CSRY)
	sub 2
	ld (CSRY),a                   ; BIOS ถอยจากคอลัมน์ 1 ไป (LINLEN, แถว-1) = (LINLEN, แถว-3)
	jp .done
.ar_right:
	ld a,(LINLEN)
	ld b,a
	ld a,(CSRX)
	cp b
	jp nz,.done
	ld a,(CSRY)
	call LT_FLAGS
	and LT_DOWN
	jp z,.done
	ld a,(CSRY)
	add a,2
	ld (CSRY),a                   ; BIOS ไปต่อ (1, แถว+1) = (1, แถว+3)
	jp .done
.notarrow:
	; --- ขั้น 2: จัดกลุ่มตัวอักษร C -- 0=ปกติ, 1=สระบน, 2=วรรณยุกต์, 3=สระล่าง (อุ/อู) ---
	; *** แก้ไขตามผู้ใช้ (เทียบกับฟอนต์บิตแมปจริงที่ผู้ใช้อัปโหลด thaifont.asm) ***: D6/D7 ไม่ใช่
	; สระบนอีก 2 ตัว แต่เป็นสระล่าง (อุ/อู) ที่ต้องซ้อนแถว+1 (ใต้พยัญชนะ) ไม่ใช่แถว-1 -- ย้ายออกจาก
	; UPPER_VOWEL_TABLE ไปเป็น LOWER_VOWEL_TABLE แยกต่างหาก (ดูรายละเอียดที่ตาราง 2 ชุดด้านล่าง)
	ld a,c
	call CLASSIFY_THAI_MARK      ; ไม่แตะ DE เลย (push/pop HL,BC ภายในตัวเอง)
	push af
	call INS_FIX                 ; 9.25: โหมด INS ของเราเอง (THAI_INS) -- คง BC/DE
	pop af
	or a
	jr nz,.is_mark
	; --- 9.25: ตัวปกติที่จะลงคอลัมน์สุดท้าย -> BIOS จะตัดขึ้นแถว+1 เอง, จำไว้แก้เป็นแถว+3 ทีหลัง ---
	ld a,c
	cp $20
	jp c,.done
	ld a,(ESCCNT)
	or a
	jp nz,.done
	ld a,(LINLEN)
	ld b,a
	ld a,(CSRX)
	cp b
	jp nz,.done
	ld a,TRUE
	ld (ix+WRAP_PENDING),a
	jp .done
.is_mark:
	ld b,a                       ; B = class (1/2/3) -- เก็บชั่วคราว

	; --- ขั้น 3: คำนวณคอลัมน์เป้าหมาย E = CSRX-1 (คอลัมน์ของตัวก่อนหน้าที่เพิ่งวาด
	; แล้ว cursor เลื่อนผ่านไปแล้ว) ---
	; --- 9.25: หาช่องของตัวที่เครื่องหมายจะไปเกาะ (MARK_ROW, E) ---
	ld a,(ix+PRINT_ROW)
	ld (ix+MARK_ROW),a
	ld a,(CSRX)
	cp 2
	jr c,.mk_wrapped
	dec a
	ld e,a                       ; ปกติ: ตัวก่อนหน้าในแถวเดียวกัน
	jr .mk_ok
.mk_wrapped:
	; ต้นแถว: ถ้าแถวนี้ต่อมาจากแถว-3 เครื่องหมายเป็นของตัวคอลัมน์สุดท้ายของแถวก่อน
	ld a,(ix+PRINT_ROW)
	call LT_FLAGS
	and LT_UP
	jp z,.done
	ld a,(ix+PRINT_ROW)
	sub 3
	ld (ix+MARK_ROW),a
	ld a,(LINLEN)
	ld e,a
.mk_ok:

	; --- ขั้น 4: แยกตาม class ---
	ld a,b
	cp 3
	jr z,.lower_vowel            ; class=3 (สระล่าง) -- ซ้อนแถว+1 เสมอ ไม่มีการผสมใด ๆ
	cp 1
	jp z,.place_row_minus1       ; class=1 (สระบน) -- วางแถว-1 เปล่า ๆ (ยังไม่มีอะไรให้ผสมตอนนี้ --
	                              ; ถ้าวรรณยุกต์ตามมาทีหลัง ค่อยมาผสมทับตอนนั้น ดูขั้นล่าง)

	; class=2 (วรรณยุกต์) -- เช็คว่าแถว-1 คอลัมน์เดียวกันมีสระบนอยู่แล้วหรือไม่ ถ้ามี **ต้องผสม
	; เป็น glyph เดียว** (ดู COMBINE_TABLE ด้านล่าง) วาดทับตำแหน่งสระบนเดิมที่แถว-1 -- ผู้ใช้ยืนยัน
	; เอง: "ไม้หันอากาศ ไม้เอกต้องผสมกัน แล้ววาดแทนไม้หันอากาศเดิม ที่ N-1" (ไม่ใช่ซ้อนแถว-2 แยก
	; ต่างหากแบบที่เข้าใจผิดไว้รอบแรก) -- ยืนยันตรงกับ disassembly ของ original ROM เป๊ะด้วย (ดู
	; printon_algorithm_report.md 1.5/2.1) และ pixel-match ตรงกับฟอนต์บิตแมปจริง (thaifont.asm)
	ld a,(ix+MARK_ROW)
	dec a                         ; A = แถว 1-based ที่จะตรวจ (แถวเหนือ PRINT_ROW หนึ่งชั้น)
	jp m,.place_row_minus1        ; PRINT_ROW=0 ผิดปกติ (กันเหนียว) -- ถือว่าไม่มีสระ
	; *** บั๊กที่เจอตอนตรวจทาน (ยังไม่เคยเจอจริงเพราะรอบแรกไม่เคยใช้ C หลังจุดนี้): NAMETAB_ADDR
	; เอกสารตัวเองบอกชัดว่า "ทำลาย A/BC/DE(D)" -- ใช้ C เป็น scratch ภายใน (ld c,l) โดยไม่คืนค่า --
	; แต่ตอนนี้ต้องใช้ C (วรรณยุกต์เดิมที่พิมพ์) ต่อที่ COMBINE_LOOKUP ด้านล่าง จึงต้อง push/pop bc
	; ครอบการเรียกนี้ไว้ (ไม่แตะ B ก็ได้เพราะ B ไม่มีความหมายอะไรค้างอยู่ตรงนี้ แต่ push/pop คู่ง่ายกว่า)
	push bc
	call NAMETAB_ADDR             ; entry A=แถว(1-based), E=คอลัมน์ -> HL=VRAM addr (ไม่แตะ E)
	pop bc
	call RDVRM                    ; A = ตัวอักษรที่อยู่ในช่องนั้นตอนนี้ (เอกสาร BIOS: แตะแค่ AF)
	ld b,a                        ; B = เก็บตัวอักษรที่แถวเหนือไว้ก่อน (ถูก CLASSIFY_THAI_MARK ทับ A)
	call CLASSIFY_THAI_MARK       ; ไม่แตะ B/C (push/pop bc ภายใน) -- B,C ยังอยู่ครบหลัง call นี้
	cp 1
	jp nz,.place_row_minus1       ; แถวเหนือไม่ใช่สระบน (ปกติ/สระล่าง/ว่าง) -- ซ้อนแถว-1 เปล่า ๆ

	; --- แถว-1 มีสระบนอยู่แล้ว: ผสมเป็น glyph เดียว แล้วเตรียม "แก้ VRAM" ตอนเรียกครั้งถัดไป ---
	; (เหตุผลที่ต้องรอครั้งถัดไป ไม่แก้ตรงนี้เลย: hook ไม่มีทางแทนที่ตัวอักษรที่ BIOS กำลังจะวาด
	; ได้เลย -- ดู comment ใหญ่ที่ PRINTHOOK ด้านบน และ PRINT_COMBINE_PENDING ใน equates.asm)
	; *** บั๊กที่เจอตอนตรวจทาน (breakpoint trace เจอ LAST_MARK_VOWEL=0 แทนที่จะเป็น 209): เดิมอ่าน
	; B (สระบนเดิม) เพื่อเก็บ PRINT_LAST_MARK_VOWEL "หลัง" เรียก COMBINE_LOOKUP ไปแล้ว -- แต่
	; COMBINE_LOOKUP เอกสารตัวเองบอกชัดว่า "ทำลาย B/C/HL" (ใช้ B เป็นตัวนับดัชนีสระแล้วทับด้วย
	; offset ผลลัพธ์) ทำให้ B ไม่ใช่สระบนเดิมอีกต่อไปตอนอ่านซ้ำ -- แก้โดยเก็บ B ไว้ใน D ก่อนเรียก
	; COMBINE_LOOKUP (D ว่างอยู่ตรงนี้แน่นอน ไม่ชนกับอะไร) แล้วใช้ D แทน B หลังจากนั้น ***
	ld d,b                        ; D = สระบนเดิม (สำรองไว้ก่อน B จะถูก COMBINE_LOOKUP ทับ)
	ld a,b
	call COMBINE_LOOKUP           ; entry A=สระบน,C=วรรณยุกต์(ยังอยู่ตั้งแต่ต้นฟังก์ชัน) -> A=โค้ดผสม
	                               ; ทำลาย B/C/HL (ไม่แตะ D/E -- D คือที่ที่เราสำรองสระบนไว้พอดี)
	jp nc,.place_row_minus1       ; 9.19: ไม่มี glyph ผสมของคู่นี้ในฟอนต์ -- วางทับแถว-1 เฉย ๆ
	ld (ix+PRINT_COMBINE_CODE),a
	ld a,(ix+MARK_ROW)
	dec a
	ld (ix+PRINT_COMBINE_ROW),a
	ld a,e
	ld (ix+PRINT_COMBINE_COL),a
	ld a,TRUE
	ld (ix+PRINT_COMBINE_PENDING),a
	; --- บันทึกไว้เผื่อผู้ใช้กด Backspace ทันทีถัดจากนี้ -- ต้อง undo กลับเป็นสระบนเปล่า ๆ
	; (ดู PRINT_LAST_MARK_* ใน equates.asm และขั้น 1.7 ด้านบน) ---
	ld a,d                        ; A = สระบนเดิม (จาก D ที่สำรองไว้ -- ไม่ใช่ B ที่ถูกทับไปแล้ว)
	ld (ix+PRINT_LAST_MARK_VOWEL),a
	ld a,(ix+MARK_ROW)
	dec a
	ld (ix+PRINT_LAST_MARK_ROW),a
	ld a,e
	ld (ix+PRINT_LAST_MARK_COL),a
	ld a,TRUE
	ld (ix+PRINT_LAST_MARK_VALID),a
	jp .place_row_minus1          ; ตกลงไปวาดที่แถว-1 ตามปกติ (BIOS จะวาดวรรณยุกต์ตัวเปล่าทับ
	                               ; ตำแหน่งนี้ไปก่อน -- ผิดชั่วคราว 1 จังหวะ แล้วค่อยแก้เป็น glyph
	                               ; ผสมตอนเรียก PRINTHOOK ครั้งถัดไปตามที่เตรียมไว้ข้างบน)

.lower_vowel:
	; class=3 (สระล่าง อุ/อู) -- ซ้อนแถว+1 เสมอ (ใต้พยัญชนะ) ไม่มีการผสมกับวรรณยุกต์ใด ๆ (วรรณยุกต์
	; อยู่คนละตำแหน่ง -- เหนือพยัญชนะ ไม่เกี่ยวกับสระล่าง) ผู้ใช้ยืนยันเอง: "◌ุ กับ ◌ู วาดที่ N+1"
	call GET_BOTTOM
	ld b,a
	ld a,(ix+MARK_ROW)
	cp b                          ; 9.20: แถว+1 ต้องไม่เลยแถวล่างสุดที่ใช้ได้ (ไม่ทับแถว function key)
	jp nc,.done
	inc a
	call NOTE_LAST_MARK
	call GHOST_CHECK             ; 9.25: คอลัมน์สุดท้าย -> วาดเอง (A=แถว, E=คอลัมน์, C=ตัว)
	jp c,.done
	ld (CSRY),a
	ld a,e
	ld (CSRX),a
	ld a,TRUE
	ld (ix+PRINT_REDIRECT),a
	jp .done

.place_row_minus1:
	; class=1 (สระบนเดี่ยว ๆ) หรือ class=2 ที่ไม่มีสระบนให้ผสม (รวมถึงกรณีผสมแล้วที่ jr มาจากบนด้วย
	; -- ตำแหน่งวาดเหมือนกันทุกกรณี คือแถว-1 คอลัมน์เดิมของพยัญชนะ)
	ld a,(ix+MARK_ROW)
	dec a
	jp m,.done                   ; แถวติดลบ (บนสุดจอพอดี) -- กันเหนียว ไม่ซ้อน
	jp z,.done                   ; แถว=0 ก็ผิดปกติเช่นกัน (CSRY เป็น 1-based)
	call NOTE_LAST_MARK
	call GHOST_CHECK             ; 9.25
	jp c,.done
	ld (CSRY),a
	ld a,e
	ld (CSRX),a
	ld a,TRUE
	ld (ix+PRINT_REDIRECT),a
	jp .done

; --- 9.20: BS ของตัวแก้ไขบรรทัดขณะ PRINTON ---
;  ถ้าเพิ่งพิมพ์สระ/วรรณยุกต์ไปทันที -> ลบเฉพาะเครื่องหมายตัวนั้น (คืนค่าช่องเดิม: ว่าง หรือสระบนก่อนผสม)
;  ไม่งั้น -> ลบทั้งช่อง (ตัวแถวกลาง + สระบน/วรรณยุกต์ + สระล่าง ของคอลัมน์นั้น) เลื่อนทั้ง 3 แถวไปทางซ้าย
;  แล้วถอย cursor 1 ช่อง -- ข้อมูลที่เก็บจึงหายไปด้วย เพราะ INLIN_REBUILD อ่านจากจอตอนกด Enter
.thai_bs:
	ld a,(ix+PRINT_LAST_MARK_VALID)
	or a
	jr z,.tbs_col
	xor a
	ld (ix+PRINT_LAST_MARK_VALID),a
	ld a,(ix+PRINT_LAST_MARK_COL)
	ld e,a
	ld a,(ix+PRINT_LAST_MARK_ROW)
	call NAMETAB_ADDR
	ld a,(ix+PRINT_LAST_MARK_VOWEL)
	call WRTVRM
	jp .done
.tbs_col:
	ld a,(CSRX)
	dec a
	jr z,.tbs_wrap
	ld e,a
	ld a,(ix+PRINT_ROW)
	call DELCOL
	ld a,(CSRX)
	dec a
	ld (CSRX),a
	jp .done
.tbs_wrap:
	; 9.25: ต้นแถวต่อ -> ลบตัวคอลัมน์สุดท้ายของแถวข้อความก่อนหน้า แล้วย้าย cursor ไปที่นั่น
	ld a,(ix+PRINT_ROW)
	call LT_FLAGS
	and LT_UP
	jp z,.done
	ld a,(ix+PRINT_ROW)
	sub 3
	ld (ix+PRINT_ROW),a
	ld (CSRY),a
	ld a,(LINLEN)
	ld (CSRX),a
	ld e,a
	ld a,(ix+PRINT_ROW)
	call DELCOL
	jp .done
; --- 9.20: DEL = ลบทั้งช่องที่ cursor (cursor ไม่ขยับ) ---
.thai_del:
	xor a
	ld (ix+PRINT_LAST_MARK_VALID),a
	ld a,(CSRX)
	ld e,a
	ld a,(ix+PRINT_ROW)
	call DELCOL

.done:
	pop af
	pop bc
	pop de
	pop hl
	ret

; ---- CLASSIFY_THAI_MARK -----------------------------------------------------
; entry: A = รหัสตัวอักษร
; exit:  A = 0 (ตัวอักษรปกติ), 1 (สระบน), 2 (วรรณยุกต์), 3 (สระล่าง) -- ไม่ทำลาย register อื่น
CLASSIFY_THAI_MARK:
	push hl
	push bc
	ld c,a
	ld hl,UPPER_VOWEL_TABLE
	ld b,UPPER_VOWEL_TABLE_LEN
.vowel_loop:
	cp (hl)
	jr z,.is_vowel
	inc hl
	djnz .vowel_loop
	ld a,c
	ld hl,LOWER_VOWEL_TABLE
	ld b,LOWER_VOWEL_TABLE_LEN
.lower_loop:
	cp (hl)
	jr z,.is_lower
	inc hl
	djnz .lower_loop
	ld a,c
	ld hl,TONE_MARK_TABLE
	ld b,TONE_MARK_TABLE_LEN
.tone_loop:
	cp (hl)
	jr z,.is_tone
	inc hl
	djnz .tone_loop
	xor a
	jr .cls_done
.is_vowel:
	ld a,1
	jr .cls_done
.is_tone:
	ld a,2
	jr .cls_done
.is_lower:
	ld a,3
.cls_done:
	pop bc
	pop hl
	ret

; ---- ตารางจัดกลุ่มเครื่องหมายไทย (9.19: แก้ใหม่ทั้งชุดจาก pixel ของ font_raw.bin จริง) ----
; ฟอนต์นี้คือรหัส TIS-620 มาตรฐาน (ก=$A1, ด=$B4, ว=$C7, ส=$CA ...) และตาราง keyboard ก็สร้างรหัส
; ชุดเดียวกัน -- วาด glyph จาก font_raw.bin ออกมาดูทีละตัวแล้วพบว่า:
;   สระบน/เครื่องหมายบน วาดชิด "ล่าง" ของช่อง (เพราะไปอยู่แถวเหนือพยัญชนะ):
;     D1=ั  D4=ิ  D5=ี  D6=ึ  D7=ื  E7=็  ED=ํ
;   วรรณยุกต์ วาดชิด "บน" ของช่อง: E8=่ E9=้ EA=๊ EB=๋ EC=์
;   สระล่าง วาดชิด "บน" ของช่อง (เพราะไปอยู่แถวใต้พยัญชนะ): D8=ุ D9=ู DA=ฺ
; *** 9.18 เดิมเข้าใจผิดว่า D6/D7 คือ ุ/ู (เชื่อ comment auto-generate ใน thaifont.asm ที่ label
; เลื่อนผิดตำแหน่ง) ทำให้ ึ/ื ถูกวาดลงแถวล่าง และ ุ/ู (D8/D9 ของจริง) ไม่ถูกซ้อนเลย -- แก้แล้ว ***
UPPER_VOWEL_TABLE:
	db $D1,$D4,$D5,$D6,$D7,$E7,$ED
UPPER_VOWEL_TABLE_LEN equ 7

LOWER_VOWEL_TABLE:
	db $D8,$D9,$DA
LOWER_VOWEL_TABLE_LEN equ 3

TONE_MARK_TABLE:
	db $E8,$E9,$EA,$EB,$EC
TONE_MARK_TABLE_LEN equ 5

; ---- COMBO_TABLE: glyph ที่ผสมสระบน+วรรณยุกต์ไว้แล้วในฟอนต์ (สระบนชิดล่าง + วรรณยุกต์ชิดบน)
; เรียงเป็นชุดละ 3 ไบต์ (สระบน, วรรณยุกต์, โค้ดผสม) ปิดท้ายด้วย 0 -- ยืนยันด้วย pixel ทุกตัว: แถวล่าง
; ของโค้ดผสมตรงกับสระบนเดี่ยว แถวบนตรงกับวรรณยุกต์เดี่ยว (ชุด D1/D4/D5 ตรงกับตารางเดิมของ 9.18
; ทุกไบต์ ส่วน D6/D7/ED และ ิ+์ เพิ่มใหม่)
COMBO_TABLE:
	db $D1,$E8,$83, $D1,$E9,$85, $D1,$EA,$86, $D1,$EB,$87
	db $D4,$E8,$88, $D4,$E9,$89, $D4,$EA,$8A, $D4,$EB,$8B, $D4,$EC,$8D
	db $D5,$E8,$8E, $D5,$E9,$8F, $D5,$EA,$90, $D5,$EB,$91
	db $D6,$E8,$92, $D6,$E9,$93, $D6,$EA,$94, $D6,$EB,$95
	db $D7,$E8,$96, $D7,$E9,$97, $D7,$EA,$98, $D7,$EB,$99
	db $ED,$E8,$9A, $ED,$E9,$9B, $ED,$EA,$9C, $ED,$EB,$9D
	db 0

; ---- COMBINE_LOOKUP -----------------------------------------------------------
; entry: A = สระบน, C = วรรณยุกต์
; exit:  carry=1 + A = โค้ดผสม ถ้ามีในฟอนต์ / carry=0 ถ้าไม่มี -- ทำลาย B/HL เท่านั้น (ไม่แตะ C/D/E)
COMBINE_LOOKUP:
	ld b,a
	ld hl,COMBO_TABLE
.cl_loop:
	ld a,(hl)
	or a
	ret z                          ; จบตาราง: ไม่พบ (or a เคลียร์ carry แล้ว)
	cp b
	jr nz,.cl_next
	inc hl
	ld a,(hl)
	dec hl
	cp c
	jr nz,.cl_next
	inc hl
	inc hl
	ld a,(hl)
	scf
	ret
.cl_next:
	inc hl
	inc hl
	inc hl
	jr .cl_loop

; ---- DECOMBINE (9.19) -----------------------------------------------------------
; ย้อนกลับของ COMBINE_LOOKUP: entry A = โค้ดใด ๆ
; exit: carry=1 + A = สระบน, C = วรรณยุกต์ ถ้าเป็นโค้ดผสม / carry=0 ถ้าไม่ใช่ -- ทำลาย B/HL
DECOMBINE:
	ld b,a
	ld hl,COMBO_TABLE
.dc_loop:
	ld a,(hl)
	or a
	ret z
	inc hl
	inc hl
	ld a,(hl)                      ; โค้ดผสม
	cp b
	jr z,.dc_found
	inc hl
	jr .dc_loop
.dc_found:
	dec hl
	ld c,(hl)                      ; วรรณยุกต์
	dec hl
	ld a,(hl)                      ; สระบน
	scf
	ret

; ---- NAMETAB_ADDR ------------------------------------------------------------
; คำนวณ VRAM address ของช่อง name table ที่ (แถว, คอลัมน์) -- สูตรตรงจาก
; disassembly ของ CALC_ADDR ($0BF2 ของ MSX1 BIOS) ตอน SCRMOD=0: (แถว-1)*40+คอลัมน์
; แล้วบวก NAMPNT (documented system variable, base จริงของ name table)
; entry: A = แถว (1-based, แบบเดียวกับ CSRY), E = คอลัมน์ (0-based, แบบเดียวกับ CSRX)
; exit:  HL = VRAM address, ทำลาย A/BC/DE(D)
;
; *** ค่าคงที่ +1 ท้ายสุด -- ยืนยันด้วย breakpoint จริงที่ CALC_ADDR ($0BF2) ของ MSX1
; BIOS เทียบกับสูตร (CSRY-1)*40+CSRX+NAMPNT เฉย ๆ (ไม่มี +1): เขียนจริง 3 ครั้ง (พยัญชนะ
; CSRY=18,CSRX=1 -> จริง=682 vs สูตรเปล่า=681 / สระ CSRY=17,CSRX=1 -> จริง=642 vs 641 /
; วรรณยุกต์ CSRY=17,CSRX=0 -> จริง=641 vs 640) เกิน 1 เท่ากันทุกครั้ง -- ตรวจสอบต่อพบว่า
; CALC_ADDR จริงมีขั้นตอนเพิ่มอีก (LINLEN-derived offset ที่ $0C0E-$0C14 แล้วค่อยบวก NAMPNT
; ที่ $0C16-$0C19 แล้ว DEC HL ที่ $0C1A) ซึ่งรวมกันแล้วเท่ากับ "+1" คงที่พอดีตราบใดที่
; SCRMOD=0/LINLEN=37/NAMPNT=0 คงที่ตลอด session (เป็นจริงเสมอสำหรับโปรเจกต์นี้ที่ใช้
; SCREEN 0 อย่างเดียว) จึงชดเชยด้วยค่าคงที่ +1 ตรงนี้แทนการ port สูตร LINLEN ที่ซับซ้อน
; และผูกกับ SCRMOD=0 อยู่แล้วโดยธรรมชาติ (ถ้าในอนาคตรองรับ SCRMOD!=0 ต้องทบทวนใหม่)
NAMETAB_ADDR:
	; 9.19: เขียนใหม่ให้ตรงกับ CALC_ADDR ของ BIOS ทุกรุ่นทุกโหมดข้อความ (disassemble ยืนยัน: MSX1 $0BF2,
	; MSX2/MSX2+ $0B98 -- สูตรเดียวกัน) เดิมเป็น (แถว-1)*40+คอลัมน์+1 คงที่ ซึ่งถูกเฉพาะ SCREEN 0 WIDTH 37
	; (MSX2+ ญี่ปุ่นบูตมาเป็น 80 คอลัมน์ -> PRINTON/การอ่านบรรทัดเพี้ยนทั้งหมด)
	;   SCREEN 0, LINLEN<=40 : NAMPNT + (แถว-1)*40 + (คอลัมน์-1) + (41-LINLEN)/2
	;   SCREEN 0, LINLEN>=41 : NAMPNT + (แถว-1)*80 + (คอลัมน์-1) + (81-LINLEN)/2   (MSX2 TEXT2)
	;   SCREEN 1             : NAMPNT + (แถว-1)*32 + (คอลัมน์-1) + (33-LINLEN)/2
	; entry: A = แถว (1-based), E = คอลัมน์ (1-based แบบ CSRX) -> HL = VRAM address
	; ทำลาย A/BC เท่านั้น (DE คงเดิม)
	push de
	dec a
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl                     ; HL = แถว*8
	ld b,h
	ld c,l                        ; BC = แถว*8
	add hl,hl
	add hl,hl                     ; HL = แถว*32
	ld d,0
	dec e                         ; E = คอลัมน์-1
	ld a,(SCRMOD)
	or a
	ld a,(LINLEN)
	jr nz,.na_g32
	cp 41
	jr nc,.na_t80
	add hl,bc                     ; แถว*40
	sub 42
	jr .na_fin
.na_t80:
	add hl,bc
	add hl,hl                     ; แถว*80
	sub 82
	jr .na_fin
.na_g32:
	sub 34
.na_fin:
	cpl                           ; A = (K-1)-LINLEN
	srl a                         ; /2 = ค่าเยื้องกึ่งกลางจอ
	add a,e
	ld e,a
	add hl,de
	ld de,(NAMPNT)
	add hl,de
	pop de
	ret

; ==========================================================================
; ---- INLIN_REBUILD (9.19) -- เก็บสระบน/ล่าง/วรรณยุกต์เข้าบรรทัดที่พิมพ์ด้วย ----
; ปัญหา (ผู้ใช้รายงาน): พิมพ์ 10 PRINT "สวัสดี" ตอน PRINTON แล้ว LIST/RUN ได้ "สวสด" -- เพราะตอนกด
; Enter ตัวแก้ไขบรรทัดของ BIOS (INLIN, $245A ใน MSX1/2/2+ เหมือนกัน) อ่านบรรทัดกลับจาก VRAM เข้า BUF
; "เฉพาะแถวที่ cursor อยู่" -- สระ/วรรณยุกต์ที่ PRINTON ย้ายไปวาดไว้แถวบน/ล่างจึงไม่ถูกอ่านเลย
; วิธีแก้: หลัง BIOS อ่านเข้า BUF เสร็จ มันจะ ESC Y ย้าย cursor ไปท้ายบรรทัดแล้วพิมพ์ LF ($24B9) --
; PRINTHOOK เห็น LF ตัวนั้น (INLIN_ACTIVE บอกว่าเป็น LF ตัวนี้จริง) แล้วเรียก routine นี้ประกอบ BUF
; ใหม่จากจอ: ทีละคอลัมน์ = ตัวแถวกลาง, ตามด้วยสระล่างจากแถว+1, ตามด้วยสระบน/วรรณยุกต์จากแถว-1
; (glyph ผสมแยกกลับเป็น สระบน+วรรณยุกต์) = ลำดับเก็บข้อความไทยปกติ (ส ว ั ส ด ี)
; รับเฉพาะโค้ดที่เป็นเครื่องหมายจริงจากแถวบน/ล่าง (ตัวอื่นในแถวนั้นไม่เอา) และจำลองกติกาเดียวกับ BIOS:
; เริ่มที่ FSTPOS ถ้าเป็นแถวเดียวกัน (ข้าม prompt ของ INPUT), ข้ามช่องที่เป็น 0, โค้ด <$20 เก็บเป็น
; $01,โค้ด+$40, ตัดช่องว่างท้ายบรรทัด, ปิดด้วย 0
; ข้อจำกัด: บรรทัดตรรกะที่ยาวเกิน 1 แถว (LINTTB บอกว่าต่อจากแถวก่อน) -> ปล่อย BUF ของ BIOS ไว้
; ตามเดิม (ตอน PRINTON แถวถัดไปคือแถวสระล่าง การตัดบรรทัดจึงใช้ร่วมกับ PRINTON ไม่ได้อยู่แล้ว)
; entry: CSRY = แถวของบรรทัดที่ BIOS เพิ่งอ่าน -- ทำลายทุก register (PRINTHOOK pop คืนเองที่ .done)
INLIN_REBUILD:
	ld a,(CSRY)
	ld (ix+RB_ROW),a
	ld (ix+RB_M),a
	cp 2
	jr c,.rb_single               ; แถว 1 ไม่มีแถวก่อนหน้า
	ld e,a
	ld d,0
	ld hl,LINTTB-2
	add hl,de                     ; HL = LINTTB entry ของแถว R-1 (LINTTB[0] = แถว 1)
	ld a,(hl)
	or a
	ret z                         ; แถว R-1 ต่อเนื่องมาแถว R แบบ BIOS (ไม่ใช่ของเรา) -> ไม่ยุ่ง
.rb_up:
	; 9.25: ย้อนขึ้นไปหาแถวแรกของบรรทัดที่ต่อแถวแบบ 3 ชั้น (marker LT_DOWN ที่แถว-3)
	ld a,(ix+RB_ROW)
	cp 4
	jr c,.rb_single
	sub 3
	ld c,a
	call LT_FLAGS
	and LT_DOWN
	jr z,.rb_single
	ld a,c
	ld (ix+RB_ROW),a
	jr .rb_up
.rb_single:
	ld hl,(FSTPOS)                ; L = แถว, H = คอลัมน์ที่เริ่มรับ
	ld a,(ix+RB_ROW)
	cp l
	ld a,1
	jr nz,.rb_setcol
	ld a,h
.rb_setcol:
	ld (ix+RB_COL),a
	ld de,BUF
.rb_col:
	ld a,(LINLEN)
	ld b,a
	ld a,(ix+RB_COL)
	dec a
	cp b
	jr nc,.rb_end                 ; คอลัมน์ > LINLEN -> จบ
	; --- ตัวแถวกลาง ---
	ld a,(ix+RB_ROW)
	call RB_READ
	or a
	jr z,.rb_lower                ; ช่องว่างจริง (0) -- BIOS ข้าม
	cp $20
	jr nc,.rb_plain
	ld c,a                        ; control code: เก็บเป็น $01,โค้ด+$40 แบบ BIOS
	ld a,1
	call RB_EMIT
	ld a,c
	add a,$40
.rb_plain:
	call RB_EMIT
.rb_lower:
	; --- สระล่างจากแถว+1 ---
	ld a,(CRTCNT)
	ld b,a
	ld a,(ix+RB_ROW)
	cp b
	jr nc,.rb_upper               ; แถวล่างสุดของจอ ไม่มีแถว+1
	inc a
	call RB_READ
	ld c,a
	call CLASSIFY_THAI_MARK
	cp 3
	ld a,c
	call z,RB_EMIT
.rb_upper:
	; --- สระบน/วรรณยุกต์จากแถว-1 ---
	ld a,(ix+RB_ROW)
	cp 2
	jr c,.rb_next
	dec a
	call RB_READ
	ld c,a
	call CLASSIFY_THAI_MARK
	or a
	jr z,.rb_combo
	cp 3
	jr z,.rb_next                 ; สระล่างในแถวบน -- ไม่ใช่ของบรรทัดนี้
	ld a,c
	call RB_EMIT                  ; สระบนเดี่ยว หรือ วรรณยุกต์เดี่ยว
	jr .rb_next
.rb_combo:
	ld a,c
	call DECOMBINE                ; -> A = สระบน, C = วรรณยุกต์
	jr nc,.rb_next
	call RB_EMIT
	ld a,c
	call RB_EMIT
.rb_next:
	inc (ix+RB_COL)
	jp .rb_col
.rb_end:
	; --- 9.25: แถวนี้ต่อไปที่แถว+3 หรือไม่ (แถวที่กด Enter: BIOS เขียน LINTTB ทับไปแล้ว ดูจากแถว+3 แทน) ---
	ld a,(ix+RB_M)
	ld b,a
	ld a,(ix+RB_ROW)
	cp b
	jr nz,.rb_own
	add a,3
	call LT_FLAGS
	and LT_UP
	jr .rb_contq
.rb_own:
	call LT_FLAGS
	and LT_DOWN
.rb_contq:
	jr z,.rb_trim
	ld a,(ix+RB_ROW)
	add a,3
	ld (ix+RB_ROW),a
	ld a,1
	ld (ix+RB_COL),a
	jp .rb_col
	; --- ตัดช่องว่างท้ายบรรทัด (ไม่ถอยเลยต้น BUF) แล้วปิดด้วย 0 ---
.rb_trim:
	ld a,e
	cp BUF & $FF
	jr nz,.rb_trim1
	ld a,d
	cp BUF >> 8
	jr z,.rb_term
.rb_trim1:
	dec de
	ld a,(de)
	cp $20
	jr z,.rb_trim
	inc de
.rb_term:
	xor a
	ld (de),a
	; --- 9.25: ใส่ marker ของแถวที่กด Enter คืน (BIOS $0C29 เขียน $AF ทับ) และให้ LF ไปต่อใต้แถวสุดท้าย ---
	ld a,(ix+RB_M)
	ld b,0
	cp 4
	jr c,.rb_m_down
	sub 3
	call LT_FLAGS
	and LT_DOWN
	jr z,.rb_m_down
	ld b,LT_UP
.rb_m_down:
	ld a,(ix+RB_M)
	ld c,a
	ld a,(ix+RB_ROW)
	cp c
	jr z,.rb_m_set
	ld a,b
	or LT_DOWN
	ld b,a
.rb_m_set:
	ld a,c
	call LT_SET
	ld a,(ix+RB_ROW)
	ld (CSRY),a
	ret

; RB_READ: entry A = แถว (1-based), คอลัมน์จาก RB_COL -> exit A = โค้ดในช่องนั้น (คง BC/DE)
RB_READ:
	push bc
	push de
	ld b,a
	ld a,(ix+RB_COL)
	ld e,a
	ld a,b
	call NAMETAB_ADDR
	call RDVRM
	pop de
	pop bc
	ret

; RB_EMIT: entry A = ไบต์, DE = ตำแหน่งเขียนใน BUF -> เขียนแล้ว DE+1 (กันล้น: หยุดที่ 253 ไบต์
; เหมือนขอบเขต B=$FE ของ BIOS) -- คง A/BC
RB_EMIT:
	push hl
	push af
	ld hl,BUF+253
	or a
	sbc hl,de
	jr c,.re_full
	jr z,.re_full
	pop af
	ld (de),a
	inc de
	pop hl
	ret
.re_full:
	pop af
	pop hl
	ret

; ==========================================================================
; ---- 9.20: ตัวช่วยสำหรับ scroll 3 แถว / BS-DEL-INSERT ที่รู้จักแถวสระบน/ล่าง ----
; ==========================================================================

; GET_BOTTOM: A = แถวล่างสุดที่ข้อความใช้ได้ = CRTCNT + CNSDFG (CNSDFG=$FF ตอนแสดง function key
; -> ลบ 1) สูตรเดียวกับ BIOS ($0C32) -- คงทุก register ยกเว้น A/F
GET_BOTTOM:
	push hl
	ld a,(CNSDFG)
	ld hl,CRTCNT
	add a,(hl)
	pop hl
	ret

; NOTE_LAST_MARK: จำ "ค่าเดิมของช่อง" ที่กำลังจะถูกวาดสระ/วรรณยุกต์ทับ ไว้ให้ BS ถัดไปทันทีคืนค่าได้
; entry: A = แถวที่จะวาด, E = คอลัมน์ -- คงทุก register (ถ้าเพิ่งผสม glyph ไว้แล้ว = TRUE ไม่ทับ)
NOTE_LAST_MARK:
	push af
	ld a,(ix+PRINT_LAST_MARK_VALID)
	or a
	jr nz,.nl_keep
	pop af
	push af
	ld (ix+PRINT_LAST_MARK_ROW),a
	push bc
	push de
	push hl
	call NAMETAB_ADDR
	call RDVRM
	ld (ix+PRINT_LAST_MARK_VOWEL),a
	pop hl
	pop de
	pop bc
	ld a,e
	ld (ix+PRINT_LAST_MARK_COL),a
	ld a,1
	ld (ix+PRINT_LAST_MARK_VALID),a
.nl_keep:
	pop af
	ret

; DELCOL: ลบคอลัมน์ E ของบรรทัดที่ PRINT_ROW ทั้ง 3 แถว (กลาง/บน/ล่าง) แล้วเลื่อนทางขวาเข้ามาแทน
; คง DE
DELCOL:
	; 9.25: entry A = แถว, E = คอลัมน์ -- ลบช่องนั้นทั้ง 3 ชั้นแล้วเลื่อนซ้าย ถ้าแถวต่อไปที่แถว+3 ดึงช่องแรก
	; ของแถวถัดไป (3 ชั้น) มาเติมคอลัมน์สุดท้าย แล้วทำต่อที่แถวถัดไปจนสุดบรรทัด -- ทำลายทุก register
	ld (ix+DC_ROW),a
.dl_loop:
	ld a,(LINLEN)
	cp e
	ret c
	ld a,(ix+DC_ROW)
	ld d,0
	call SHIFTROW_L
	ld a,(ix+DC_ROW)
	cp 2
	jr c,.dl_low
	dec a
	ld d,1
	call SHIFTROW_L
.dl_low:
	call GET_BOTTOM
	ld b,a
	ld a,(ix+DC_ROW)
	cp b
	jr nc,.dl_next
	inc a
	ld d,3
	call SHIFTROW_L
.dl_next:
	ld a,(ix+DC_ROW)
	call LT_FLAGS
	and LT_DOWN
	ret z
	ld a,(ix+DC_ROW)
	call PULL3                    ; (แถว+3, คอลัมน์ 1) -> (แถว, LINLEN) ทั้ง 3 ชั้น
	ld a,(ix+DC_ROW)
	add a,3
	ld (ix+DC_ROW),a
	ld e,1
	jr .dl_loop

; PULL3: A = แถว r -- คัดลอกช่อง (r+3+k, 1) ไป (r+k, LINLEN) สำหรับ k = -1, 0, +1
PULL3:
	ld b,3
	dec a                         ; เริ่มที่ชั้นบน (r-1)
.p3_loop:
	push bc
	push af
	or a
	jr z,.p3_skip                 ; แถว 0 ไม่มี
	ld c,a
	add a,3
	ld b,a                        ; B = แถวต้นทาง
	ld a,1
	ld (ix+RB_COL),a
	ld a,b
	call RB_READ
	ld d,a
	ld a,c
	ld (ix+RB_ROW),a
	ld a,(LINLEN)
	ld (ix+RB_COL),a
	ld a,d
	call RB_WRITE
.p3_skip:
	pop af
	pop bc
	inc a
	djnz .p3_loop
	ret

; INS_FIX: โหมด insert ของตัวแก้ไขบรรทัด -- ก่อน CHPUT ของตัวที่พิมพ์ BIOS ($24F2) เลื่อนแถวกลาง
; ไปทางขวาหนึ่งช่องที่ตำแหน่ง cursor ไปแล้ว:
;   ตัวอักษรปกติ -> เลื่อนแถวสระบน/ล่างตามไปด้วย ให้ตรงคอลัมน์เดิม
;   สระ/วรรณยุกต์ (ไม่กินช่อง) -> ปิดช่องว่างที่ BIOS เปิดไว้ในแถวกลางกลับคืน
; entry: A = class ของตัวอักษร, C = ตัวอักษร -- คง BC/DE/HL
INS_FIX:
	; 9.25: โหมด INS ของเราเอง (THAI_INS -- BIOS ถูกตั้ง INSFLG=0 ตลอดใน CHGE_HOOK จึงพิมพ์ทับเสมอ)
	; entry A = class, C = ตัวอักษร -- คง BC/DE/HL
	;   control code (ไม่ใช่ BS/DEL ของเรา) -> BIOS ยกเลิก INS เอง ($2428) ทำตาม
	;   ตัวปกติ >= $20 -> เลื่อนทั้ง 3 ชั้นไปขวาที่ cursor (ข้ามแถวต่อได้ ต่อแถวใหม่ถ้าล้น) ให้ BIOS วาดลงช่องว่าง
	;   สระ/วรรณยุกต์ -> ไม่กินช่อง ไม่ต้องเลื่อน
	push bc
	push de
	push hl
	ld b,a
	ld a,(ix+INLIN_ACTIVE)
	or a
	jr z,.if_ret
	ld a,(ESCCNT)
	or a
	jr nz,.if_ret
	ld a,c
	cp $20
	jr nc,.if_print
	cp THAI_BS_CODE
	jr z,.if_ret
	cp THAI_DEL_CODE
	jr z,.if_ret
	xor a
	ld (ix+THAI_INS),a
	jr .if_ret
.if_print:
	ld a,(ix+THAI_INS)
	or a
	jr z,.if_ret
	ld a,b
	or a
	jr nz,.if_ret
	ld a,(CSRX)
	ld e,a
	ld a,(ix+PRINT_ROW)
	call INSCOL
.if_ret:
	pop hl
	pop de
	pop bc
	ret

; INSCOL: A = แถว, E = คอลัมน์ -- แทรกช่องว่างที่ตำแหน่งนั้นทั้ง 3 ชั้น เลื่อนไปขวาจนสุดบรรทัด ตัวที่ล้น
; คอลัมน์สุดท้าย (พร้อมสระบน/ล่างของมัน) ไปต่อที่ต้นแถวต่อ ถ้าแถวสุดท้ายล้นเป็นตัวที่ไม่ใช่ช่องว่าง ต่อแถวใหม่
; (LINK_NEXT -- อาจ scroll จอ PRINT_ROW เลื่อนตาม) -- ทำลายทุก register
INSCOL:
	ld (ix+DC_ROW),a
	xor a
	ld (ix+IC_CARRY),a
	ld (ix+IC_CARRY+1),a
	ld (ix+IC_CARRY+2),a
	ld d,0                        ; D = มีตัวค้างจากแถวก่อนหรือไม่
.ic_loop:
	push de
	; เก็บตัวที่จะล้น (3 ชั้น) ของแถวนี้ไว้ก่อนเลื่อน -- ใช้ stack พักค่าตัวค้างรอบก่อน
	ld a,(ix+IC_CARRY)
	push af
	ld a,(ix+IC_CARRY+1)
	push af
	ld a,(ix+IC_CARRY+2)
	push af
	ld a,(LINLEN)
	ld (ix+RB_COL),a
	ld a,(ix+DC_ROW)
	dec a
	call nz,RB_READ_OR_SP
	ld (ix+IC_CARRY),a
	ld a,(ix+DC_ROW)
	call RB_READ
	ld (ix+IC_CARRY+1),a
	ld a,(ix+DC_ROW)
	inc a
	call RB_READ_OR_SP
	ld (ix+IC_CARRY+2),a
	; เลื่อนทั้ง 3 ชั้น
	ld a,(ix+DC_ROW)
	ld d,0
	call SHIFTROW_R
	ld a,(ix+DC_ROW)
	cp 2
	jr c,.ic_low
	dec a
	ld d,1
	call SHIFTROW_R
.ic_low:
	call GET_BOTTOM
	ld b,a
	ld a,(ix+DC_ROW)
	cp b
	jr nc,.ic_put
	inc a
	ld d,3
	call SHIFTROW_R
.ic_put:
	; ใส่ตัวค้างจากแถวก่อน (ถ้ามี) ที่คอลัมน์ E
	pop af
	ld c,a                        ; ล่าง
	pop af
	ld b,a                        ; กลาง
	pop af                        ; บน
	pop de
	push de
	bit 0,d
	call nz,IC_PUT3
	pop de
	; แถวนี้ต่อไปแถว+3 หรือไม่
	ld a,(ix+DC_ROW)
	call LT_FLAGS
	and LT_DOWN
	jr nz,.ic_next
	ld a,(ix+IC_CARRY+1)
	cp $21
	ret c                         ; ล้นเป็นช่องว่าง/0 -- จบ
	ld a,(ix+DC_ROW)
	call LINK_NEXT
	ld b,a
	ld a,(ix+DC_ROW)
	sub b
	ld (ix+DC_ROW),a
	; แถวใหม่ว่างอยู่แล้ว ใส่ตัวค้างที่คอลัมน์ 1 แล้วจบ
	add a,3
	ld (ix+DC_ROW),a
	ld e,1
	ld a,(ix+IC_CARRY)
	push af
	ld a,(ix+IC_CARRY+1)
	ld b,a
	ld a,(ix+IC_CARRY+2)
	ld c,a
	pop af
	jp IC_PUT3
.ic_next:
	ld a,(ix+DC_ROW)
	add a,3
	ld (ix+DC_ROW),a
	ld e,1
	ld d,1
	jp .ic_loop

; IC_PUT3: A = บน, B = กลาง, C = ล่าง -> เขียนลง (DC_ROW-1/DC_ROW/DC_ROW+1, E) -- สระบน/ล่างเขียนเฉพาะ
; ที่เป็นเครื่องหมายจริง -- คง DE
IC_PUT3:
	push de
	push bc
	push af
	ld a,e
	ld (ix+RB_COL),a
	ld a,(ix+DC_ROW)
	ld (ix+RB_ROW),a
	ld a,b
	call RB_WRITE
	pop af
	push af
	call CLASSIFY_THAI_MARK
	or a
	jr z,.ip_low
	ld a,(ix+DC_ROW)
	dec a
	ld (ix+RB_ROW),a
	pop af
	push af
	call RB_WRITE
.ip_low:
	pop af
	pop bc
	push bc
	push af
	ld a,c
	call CLASSIFY_THAI_MARK
	cp 3
	jr nz,.ip_ret
	ld a,(ix+DC_ROW)
	inc a
	ld (ix+RB_ROW),a
	ld a,c
	call RB_WRITE
.ip_ret:
	pop af
	pop bc
	pop de
	ret

; RB_READ_OR_SP: A = แถว (0 = ไม่มี) -> อ่านช่อง (A, RB_COL) หรือคืน $20 -- คง BC/DE
RB_READ_OR_SP:
	or a
	jr z,.rs_sp
	cp 25
	jr nc,.rs_sp
	jp RB_READ
.rs_sp:
	ld a,$20
	ret

; SR_VALID: แถว A ตั้งแต่คอลัมน์ E ถึงท้ายบรรทัด มีแต่ช่องว่าง หรือเครื่องหมายชนิดที่ถูกต้องเท่านั้น
; หรือไม่ (D=1: สระบน/วรรณยุกต์/glyph ผสม, D=3: สระล่าง) -> carry=1 ถ้าใช่ -- กันไม่ให้ไปเลื่อน
; ข้อความของบรรทัดอื่นที่บังเอิญอยู่แถวติดกัน (กรณีไม่ได้เว้น 3 แถว) -- คง DE
SR_VALID:
	ld (ix+RB_ROW),a
	ld a,e
	ld (ix+RB_COL),a
.sv_loop:
	ld a,(LINLEN)
	ld b,a
	ld a,(ix+RB_COL)
	dec a
	cp b
	jr nc,.sv_ok
	ld a,(ix+RB_ROW)
	call RB_READ
	cp $20
	jr z,.sv_next
	or a
	jr z,.sv_next
	ld c,a
	call CLASSIFY_THAI_MARK
	ld b,a
	ld a,d
	cp 3
	jr nz,.sv_up
	ld a,b
	cp 3
	jr z,.sv_next
	or a                           ; carry=0 = ไม่ผ่าน
	ret
.sv_up:
	ld a,b
	cp 1
	jr z,.sv_next
	cp 2
	jr z,.sv_next
	ld a,c
	call DECOMBINE
	ret nc
.sv_next:
	inc (ix+RB_COL)
	jr .sv_loop
.sv_ok:
	scf
	ret

; SHIFTROW_L: แถว A คอลัมน์ E..ท้ายบรรทัด เลื่อนซ้าย 1 ช่อง (ช่อง E หายไป ท้ายบรรทัดเติมช่องว่าง)
; D=0 เลื่อนเลย, D=1/3 เลื่อนเฉพาะเมื่อ SR_VALID ผ่าน -- คง DE
SHIFTROW_L:
	push de
	push af
	ld a,(LINLEN)
	cp e
	jr c,.sl_abort
	ld a,d
	or a
	jr z,.sl_go
	pop af
	push af
	call SR_VALID
	jr nc,.sl_abort
.sl_go:
	pop af
	ld (ix+RB_ROW),a
	ld a,e
	ld (ix+RB_COL),a
.sl_loop:
	ld a,(LINLEN)
	ld b,a
	ld a,(ix+RB_COL)
	cp b
	jr nc,.sl_last
	inc a
	ld (ix+RB_COL),a
	ld a,(ix+RB_ROW)
	call RB_READ
	dec (ix+RB_COL)
	call RB_WRITE
	inc (ix+RB_COL)
	jr .sl_loop
.sl_last:
	ld a,$20
	call RB_WRITE
	pop de
	ret
.sl_abort:
	pop af
	pop de
	ret

; SHIFTROW_R: แถว A คอลัมน์ E..ท้ายบรรทัด เลื่อนขวา 1 ช่อง (ช่อง E กลายเป็นช่องว่าง ตัวท้ายสุดหลุดไป)
; D เหมือน SHIFTROW_L -- คง DE
SHIFTROW_R:
	push de
	push af
	ld a,(LINLEN)
	cp e
	jr c,.sr_abort
	ld a,d
	or a
	jr z,.sr_go
	pop af
	push af
	call SR_VALID
	jr nc,.sr_abort
.sr_go:
	pop af
	ld (ix+RB_ROW),a
	ld a,(LINLEN)
	ld (ix+RB_COL),a
.sr_loop:
	ld a,(ix+RB_COL)
	cp e
	jr z,.sr_first
	jr c,.sr_first
	dec a
	ld (ix+RB_COL),a
	ld a,(ix+RB_ROW)
	call RB_READ
	inc (ix+RB_COL)
	call RB_WRITE
	dec (ix+RB_COL)
	jr .sr_loop
.sr_first:
	ld a,$20
	call RB_WRITE
	pop de
	ret
.sr_abort:
	pop af
	pop de
	ret

; SELECT_TOGGLE (9.30 A2): สลับ PRINTON/PRINTOFF แล้วล้างจอ -- ตามต้นฉบับ $512E-$5150 (ล้างจอเพราะข้อความ
; ที่วาดไว้แบบเก่าอ่านไม่ได้ในอีกแบบ) -- ถ้า PLOCKON อยู่ไม่ทำอะไร -- ล้างจอด้วย CHPUT($0C) ซ้อน ซึ่งผ่าน
; PRINTHOOK อีกรอบตามโหมดใหม่ -- ทำลาย AF, HL
SELECT_TOGGLE:
	ld a,(ix+PLOCK_MODE)
	or a
	ret nz
	ld a,(ix+PRINT_MODE)
	cpl
	ld (ix+PRINT_MODE),a
	or a
	jr nz,.st_on
	ld a,TRUE
	ld (CURSOR_BLINK_FLAG),a      ; เหมือน CMD_PRINTOFF
.st_on:
	xor a
	ld (ix+PRINT_REDIRECT),a
	ld (ix+WRAP_PENDING),a
	ld (ix+GHOST_PENDING),a
	ld (ix+PRINT_COMBINE_PENDING),a
	ld (ix+PRINT_LAST_MARK_VALID),a
	ld a,$0C
	call CHPUT_IX
	ld a,(ix+PRINT_MODE)
	or a
	jr z,.st_fst
	ld a,2                        ; PRINTON: เริ่มแถว 2 ให้มีแถวสระบนเหนือข้อความ (ต้นฉบับ $552F จัดแถวเหมือนกัน)
	ld (CSRY),a
	ld (ix+PRINT_ROW),a
.st_fst:
	ld a,(CSRY)                   ; บรรทัดที่กำลังรับอยู่เริ่มใหม่ที่ต้นแถวปัจจุบัน (FSTPOS เดิมชี้แถวก่อนล้างจอ)
	ld (FSTPOS),a
	ld a,1
	ld (FSTPOS+1),a
	ld hl,(CURLIN)                ; direct mode = SELECT มาจาก INLIN ของบรรทัดคำสั่ง -> บรรทัดนี้ต้อง
	inc hl                        ; ประกอบสระบน/ล่างกลับเข้า BUF ตามโหมดใหม่ (INLIN_HOOK ตั้งไว้ตามโหมดเดิม)
	ld a,h
	or l
	ret nz
	ld a,(ix+PRINT_MODE)
	ld (ix+INLIN_ACTIVE),a
	ret

; RB_WRITE: เขียน A ลงช่อง (RB_ROW, RB_COL) -- คง BC/DE
RB_WRITE:
	push bc
	push de
	push af
	ld a,(ix+RB_COL)
	ld e,a
	ld a,(ix+RB_ROW)
	call NAMETAB_ADDR
	pop af
	call WRTVRM
	pop de
	pop bc
	ret

; ==========================================================================
; ---- 9.26: cursor ภาษาไทย = รูปเดียวกับอังกฤษ (ของ BIOS) แต่กระพริบ ----
; BIOS วาด cursor (MSX1 $09E6 / MSX2,2+ $0A43) โดยคัดลอก glyph ของตัวใต้ cursor (เก็บไว้ที่ CURSAV) มากลับสี
; (CSTYLE=0 ทั้งตัว / INS 3 แถวล่าง) ลง glyph 255 แล้วเขียน 255 ลงช่องนั้น -- ระหว่างรอคีย์ (DSPC..ERAC)
; TIMI_HOOK สลับ glyph 255 ระหว่าง "กลับสี" (ติด) กับ "ตัวปกติ" (ดับ) ทุก BLINK_FRAMES frame เมื่ออยู่ภาษาไทย
; (ช่วงรอคีย์โค้ดหลักไม่ใช้ VDP ยกเว้นตอน BIOS วาดป้าย function key ใหม่เพราะ SHIFT เปลี่ยน -- ข้ามรอบนั้น)
; H.TIMI ต้องส่งต่อ hook เดิมเสมอ (disk ROM ใช้นับเวลาดับมอเตอร์) -- ดู TIMI_HOOK

; DSPC_HOOK -- คงทุก register
DSPC_BODY:
	push af
	ld a,(ix+THAI_MODE)
	or a
	jr z,.dp_done
	ld a,(ix+IN_CHGET)
	ld (ix+CUR_WAITING),a
	xor a
	ld (ix+IN_CHGET),a
	ld (ix+BLINK_CNT),a
	ld (ix+BLINK_OFF),a
.dp_done:
	pop af
	ret

; ERAC_HOOK -- คงทุก register
ERAC_BODY:
	push af
	xor a
	ld (ix+CUR_WAITING),a
	ld (ix+BLINK_OFF),a
	pop af
	ret

; CUR_REDRAW -- เรียกจาก KEYC_HOOK (ใน interrupt) หลังสลับภาษา: ให้ cursor "ติด" ทันทีแล้วเริ่มนับใหม่
; (สลับเป็นอังกฤษตอนกำลังดับ -> กลับมาติดค้าง) -- คงทุก register
CUR_REDRAW:
	push hl
	push de
	push bc
	push af
	call CUR_SAFE
	jr nc,.cr_done
	xor a
	ld (ix+BLINK_CNT),a
	ld (ix+BLINK_OFF),a
	ld a,2
	call CUR_BUILD
.cr_done:
	pop af
	pop bc
	pop de
	pop hl
	ret

; CUR_SAFE: carry=1 ถ้า cursor รอคีย์แสดงอยู่ (โหมดข้อความ) และ BIOS ไม่มีงานวาดป้าย function key ค้าง
CUR_SAFE:
	ld a,(ix+CUR_WAITING)
	or a
	ret z
	ld a,(SCRMOD)
	cp 2
	ret nc                        ; SCREEN 2+ -> nc
	ld a,(CNSDFG)
	or a
	scf
	ret z
	ld a,(FNKSWI)
	ld hl,SHIFT_STATE
	xor (hl)
	and 1
	scf
	ret z
	or a
	ret

; TIMI_HOOK -- ทุก VDP interrupt: กระพริบ cursor ภาษาไทย แล้วส่งต่อไป hook เดิม (PREV_TIMI) โดยคืนทุก
; register ตามเดิม (A = VDP status ที่ hook ตัวอื่นอาจใช้)
TIMI_BODY:
	push hl
	push de
	push bc
	push af
	call CUR_SAFE
	jr nc,.ti_chain
	ld a,(ix+THAI_MODE)
	or a
	jr z,.ti_chain
	ld a,(ix+INPUT_MODE)
	or a
	jr z,.ti_eng
	ld a,(ix+BLINK_CNT)
	inc a
	ld (ix+BLINK_CNT),a
	cp BLINK_FRAMES
	jr c,.ti_chain
	xor a
	ld (ix+BLINK_CNT),a
	ld a,(ix+BLINK_OFF)
	xor 1
	ld (ix+BLINK_OFF),a
	ld a,2                        ; ติด = กลับสีแบบ BIOS
	jr z,.ti_draw
	xor a                         ; ดับ = ตัวปกติ
.ti_draw:
	call CUR_BUILD
	jr .ti_chain
.ti_eng:
	ld a,(ix+BLINK_OFF)              ; อังกฤษแต่ค้างอยู่ช่วงดับ -> ให้ติด
	or a
	jr z,.ti_chain
	xor a
	ld (ix+BLINK_OFF),a
	ld a,2
	call CUR_BUILD
.ti_chain:
	pop af
	pop bc
	pop de
	pop hl
	ret                           ; 9.27: wrapper TIMI_HOOK (workram.asm) ส่งต่อ hook เดิม

; CUR_BUILD: เขียน glyph 255 จาก glyph ของตัวใต้ cursor (CURSAV) -- A bit1 = กลับสีแบบ BIOS (ทั้งตัว หรือ
; 3 แถวล่างถ้า CSTYLE!=0) / 0 = ตัวปกติ -- ทำลายทุก register ใช้ stack 8 ไบต์เป็น buffer
CUR_BUILD:
	ld c,a
	ld hl,-8
	add hl,sp
	ld sp,hl
	ex de,hl                      ; DE = buffer
	push de
	push bc
	ld a,(CURSAV)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,(CGPNT)
	add hl,bc
	ld bc,8
	call LDIRMV                   ; glyph ตัวจริง -> buffer
	pop bc
	pop hl
	push hl
	ld b,0                        ; B = แถว 0..7
.cb_row:
	ld a,(hl)
	bit 1,c
	jr z,.cb_store
	ld d,a
	ld a,(CSTYLE)
	or a
	ld a,b
	jr z,.cb_all
	cp 5                          ; CSTYLE!=0: BIOS กลับสีแค่แถว 5-7
	ld a,d
	jr c,.cb_store
	cpl
	jr .cb_store
.cb_all:
	ld a,d
	cpl
.cb_store:
	ld (hl),a
	inc hl
	inc b
	ld a,b
	cp 8
	jr nz,.cb_row
	ld hl,(CGPNT)
	ld de,$07F8
	add hl,de
	ex de,hl                      ; DE = VRAM ของ glyph 255
	pop hl                        ; HL = buffer
	ld bc,8
	call LDIRVM
	ld hl,8
	add hl,sp
	ld sp,hl
	ret

; ---- FONT_CHECK (9.23) ----------------------------------------------------------
; SCREEN / WIDTH ของ BASIC เรียก INITXT/INIT32 ซึ่งโหลดฟอนต์ระบบลง VRAM ทับฟอนต์ไทย (เช่น
; SCREEN 0:WIDTH 80 บน MSX2) -- เช็ค 2 ไบต์ของ glyph ก ($A1) ใน pattern table ปัจจุบัน ถ้าไม่ใช่ของเรา
; โหลดฟอนต์ไทยใหม่ทั้งชุด -- เฉพาะโหมดข้อความ (SCREEN 0/1) และตอน THAION -- ทำลาย AF/BC/DE/HL
FONT_CHECK:
	ld a,(ix+THAI_MODE)
	or a
	ret z
	ld a,(SCRMOD)
	cp 2
	ret nc
	ld hl,(CGPNT)
	ld de,$A1*8+1
	add hl,de
	call RDVRM
	ld b,a
	ld a,(FONT_THAI+$A1*8+1)
	cp b
	jr nz,.fc_reload
	inc hl
	call RDVRM
	ld b,a
	ld a,(FONT_THAI+$A1*8+2)
	cp b
	ret z
.fc_reload:
	ld hl,FONT_THAI
	ld de,(CGPNT)
	ld bc,FONT_THAI_END-FONT_THAI
	jp LDIRVM

; ==========================================================================
; ---- 9.25: บรรทัดยาวต่อแถว (continuation) ขณะ PRINTON ----
; BIOS ตัดบรรทัดที่เกินความกว้างไป "แถว+1" (ซึ่งตอน PRINTON คือแถวสระล่าง) และตั้ง LINTTB[แถว]=0
; เราย้ายไปต่อที่ "แถว+3" แทน (แต่ละแถวข้อความมีแถวสระบน/ล่างของตัวเอง) และบันทึกการต่อแถวไว้ใน LINTTB
; ด้วยค่า marker ($50|LT_DOWN|LT_UP) ซึ่ง BIOS ถือว่า "ไม่ต่อ" (ไม่ไปอ่าน/เลื่อนแถวสระเป็นข้อความ) แต่
; เลื่อนตามจอเวลา BIOS scroll ให้เอง -- INLIN_REBUILD/DELCOL/INSCOL ใช้ marker นี้เดินข้ามแถว
; ==========================================================================

; LT_ADDR: A = แถว (1-based) -> HL = ที่อยู่ LINTTB ของแถวนั้น -- ทำลาย DE
LT_ADDR:
	ld e,a
	ld d,0
	ld hl,LINTTB-1
	add hl,de
	ret

; LT_FLAGS: A = แถว -> A = LT_DOWN/LT_UP ของแถวนั้น (0 ถ้าไม่ใช่ marker หรือแถวนอกจอ) -- คง BC/DE
LT_FLAGS:
	or a
	ret z
	cp 25
	jr nc,.lf_zero
	push de
	push hl
	call LT_ADDR
	ld a,(hl)
	pop hl
	pop de
	push bc
	ld b,a
	and $FC
	cp LT_MARK
	ld a,b
	pop bc
	jr nz,.lf_zero
	and 3
	ret
.lf_zero:
	xor a
	ret

; LT_SET: A = แถว, B = flags ที่จะ OR เพิ่ม (หรือ 0 = ล้างเป็นค่า "ไม่ต่อ" ปกติ $AF) -- คง BC/DE
LT_SET:
	push de
	push hl
	push af
	call LT_FLAGS
	or b
	jr z,.ls_plain
	or LT_MARK
	jr .ls_put
.ls_plain:
	ld a,$AF
.ls_put:
	ld (ix+LT_TMP),a                 ; (LT_ADDR ทับ DE -- พักค่าไว้ใน RAM)
	pop af
	push af
	call LT_ADDR
	ld a,(ix+LT_TMP)
	ld (hl),a
	pop af
	pop hl
	pop de
	ret

; LINK_NEXT: A = แถวข้อความ r -- เตรียมแถวต่อที่ r+3 (ต้องมีแถวสระล่างของมันในจอ: r+4 <= ล่างสุด ไม่งั้น
; scroll จอขึ้นเท่าที่ต้อง) ตั้ง marker r=DOWN, r+3=UP, แถวสระ r+1/r+2 = ไม่ต่อ -- exit A = จำนวนแถวที่
; scroll (แถว r จริงตอนนี้ = r - A) -- PRINT_ROW ถูกเลื่อนตามด้วย -- ทำลาย BC/DE/HL
LINK_NEXT:
	ld c,a
	call GET_BOTTOM
	ld b,a
	ld a,c
	add a,4
	sub b
	jr z,.ln_noscroll
	jr c,.ln_noscroll
	ld b,a                        ; B = จำนวนแถวที่ต้อง scroll
	push bc
	ld a,(CSRY)
	push af
	call GET_BOTTOM
	ld (CSRY),a
	ld a,TRUE
	ld (ix+PRINT_IN_LF),a
.ln_scroll:
	push bc
	ld a,10
	call CHPUT_IX
	pop bc
	djnz .ln_scroll
	xor a
	ld (ix+PRINT_IN_LF),a
	pop af                        ; CSRY เดิม
	pop bc                        ; B = จำนวนที่ scroll, C = r เดิม
	sub b
	ld (CSRY),a
	ld a,(ix+PRINT_ROW)
	sub b
	ld (ix+PRINT_ROW),a
	ld a,c
	sub b
	ld c,a
	ld a,b
	jr .ln_link
.ln_noscroll:
	xor a
.ln_link:
	push af
	ld a,c
	ld b,LT_DOWN
	call LT_SET
	inc a
	ld b,0
	call LT_SET_PLAIN
	inc a
	call LT_SET_PLAIN
	inc a
	ld b,LT_UP
	call LT_SET
	pop af
	ret

; LT_SET_PLAIN: A = แถว -> LINTTB = $AF (ไม่ต่อ, ไม่ใช่ marker) -- คง AF/BC/DE
LT_SET_PLAIN:
	push de
	push hl
	push af
	call LT_ADDR
	ld (hl),$AF
	pop af
	pop hl
	pop de
	ret

; WRAP_FIX: หลัง BIOS ตัดบรรทัดไปแถว+1 (WRAP_PENDING, cursor อยู่คอลัมน์ 1, LINTTB[แถวก่อน]=0) ย้ายไปแถว+3
; ทำลายทุก register
WRAP_FIX:
	ld a,(ix+WRAP_PENDING)
	or a
	ret z
	xor a
	ld (ix+WRAP_PENDING),a
	ld a,(CSRX)
	cp 1
	ret nz
	ld a,(CSRY)
	cp 2
	ret c
	dec a
	ld c,a                        ; C = r (แถวที่เพิ่งเต็ม)
	call LT_ADDR
	ld a,(hl)
	or a
	ret nz                        ; BIOS ไม่ได้ตัดบรรทัด (cursor มาต้นแถวด้วยเหตุอื่น)
	ld (hl),$AF                   ; ยกเลิกการต่อแถวแบบ BIOS (r -> r+1)
	ld a,c
	push bc
	call LINK_NEXT                ; (ทำลาย BC)
	pop bc
	ld b,a
	ld a,c
	sub b
	ld c,a                        ; C = r หลัง scroll
	; BIOS เขียน 0 ทับ LINTTB[r] ไปแล้ว -- ถ้า r เองเป็นแถวต่อ (r-3 ชี้ลงมา) ใส่ LT_UP คืน
	cp 4
	jr c,.wf_pos
	sub 3
	call LT_FLAGS
	and LT_DOWN
	jr z,.wf_pos
	ld a,c
	ld b,LT_UP
	call LT_SET
.wf_pos:
	ld a,c
	add a,3
	ld (CSRY),a
	ld a,1
	ld (CSRX),a
	ret

; GHOST_CHECK: entry A = แถวที่จะวาดเครื่องหมาย, E = คอลัมน์, C = ตัวเครื่องหมาย
; ถ้า E = LINLEN (ตัวที่เกาะอยู่คอลัมน์สุดท้าย) ห้ามให้ BIOS วาดที่นั่น (BIOS จะตัดบรรทัด/scroll จอ) --
; วาดเครื่องหมาย (หรือ glyph ผสมที่รออยู่) เองด้วย WRTVRM แล้วปล่อย BIOS วาด "ตัวหลอก" ที่ cursor จริง
; ซึ่งเราจำตัวเดิมไว้เขียนคืนตอน resync -> carry=1 = จัดการแล้ว / carry=0 = ใช้วิธีปกติ -- คง A/C/E
GHOST_CHECK:
	push af
	ld a,(LINLEN)
	cp e
	jr z,.gc_do
	pop af
	or a
	ret
.gc_do:
	pop af
	push af
	push bc
	push de
	push hl
	ld b,a                        ; B = แถว
	ld a,(ix+PRINT_COMBINE_PENDING)
	or a
	jr z,.gc_single
	xor a
	ld (ix+PRINT_COMBINE_PENDING),a
	ld a,(ix+PRINT_COMBINE_ROW)
	ld b,a
	ld a,(ix+PRINT_COMBINE_COL)
	ld e,a
	ld a,(ix+PRINT_COMBINE_CODE)
	ld c,a
.gc_single:
	push bc
	ld a,b
	call NAMETAB_ADDR             ; (ทำลาย BC)
	pop bc
	ld a,c
	call WRTVRM
	; ตัวหลอก: จำช่องที่ cursor จริง
	ld a,(CSRY)
	ld (ix+GHOST_ROW),a
	ld a,(CSRX)
	ld (ix+GHOST_COL),a
	ld e,a
	ld a,(ix+GHOST_ROW)
	call NAMETAB_ADDR
	call RDVRM
	ld (ix+GHOST_CHAR),a
	ld a,TRUE
	ld (ix+GHOST_PENDING),a
	pop hl
	pop de
	pop bc
	pop af
	scf
	ret

; PRINT_RESYNC: เรียกตอนต้น PRINTHOOK และ CHGE_HOOK -- คืน CSRY จริงหลังยักย้าย, เขียนคืนตัวหลอก,
; ย้ายการตัดบรรทัดของ BIOS ไปแถว+3, รีเฟรช PRINT_ROW, แก้ glyph ผสมที่ค้าง -- ทำลายทุก register
PRINT_RESYNC:
	ld a,(ix+PRINT_REDIRECT)
	or a
	jr z,.rs_ghost
	ld a,(ix+PRINT_ROW)
	ld (CSRY),a
	xor a
	ld (ix+PRINT_REDIRECT),a
.rs_ghost:
	ld a,(ix+GHOST_PENDING)
	or a
	jr z,.rs_wrap
	xor a
	ld (ix+GHOST_PENDING),a
	ld a,(ix+GHOST_COL)
	ld e,a
	ld (CSRX),a
	ld a,(ix+GHOST_ROW)
	ld (CSRY),a
	call NAMETAB_ADDR
	ld a,(ix+GHOST_CHAR)
	call WRTVRM
.rs_wrap:
	call WRAP_FIX
	ld a,(CSRY)
	ld (ix+PRINT_ROW),a
	jp COMBINE_FIX
