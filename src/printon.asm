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
;   2. D6,D7 ไม่ใช่สระบนอีก 2 ตัว (ที่เข้าใจผิดไว้รอบแรก) แต่เป็น**สระล่าง** (อุ/อู) ซ้อนแถว **+1**
;      (ใต้พยัญชนะ) ไม่ใช่แถว-1 -- ไม่มีการผสมกับวรรณยุกต์ใด ๆ (ผู้ใช้ยืนยัน + ฟอนต์บิตแมปจริง
;      label โค้ดนี้ตรงตัวว่า "ุ"/"ู" พอดี)
; สรุปตารางที่ implement จริงตอนนี้ (ดูรายละเอียดที่ CLASSIFY_THAI_MARK ด้านล่าง):
;   - สระบน 3 ตัว (D1,D4,D5) -- ซ้อนแถว-1 เสมอ, ผสมกับวรรณยุกต์ถ้ามีวรรณยุกต์ตามมา
;   - วรรณยุกต์ 4 รูป (E8,E9,EA,EB) -- ซ้อนแถว-1 เปล่า ๆ ถ้าไม่มีสระบนอยู่ก่อน, ผสมเป็น glyph
;     เดียวทับสระบนเดิมถ้ามีสระบนอยู่ที่แถว-1 แล้ว (ดูข้อ 1 ด้านบน)
;   - สระล่าง 2 ตัว (D6,D7) -- ซ้อนแถว+1 เสมอ ไม่มีการผสม
; โค้ดกลุ่ม 0x82-0x9D ที่เหลือ (นอกเหนือจาก 0x83-0x91 ที่ใช้เป็น combine output) ยังไม่ทราบ
; ความหมายแน่ชัด (E7/ED/FC และตัวแปรอื่นในช่วงนี้) **ไม่ได้ทำการซ้อนพิเศษ** -- ปล่อยให้ BIOS
; วาดแบบปกติ เป็นการตัดสินใจที่ตั้งใจ ไม่ใช่ข้อบกพร่องที่ลืม
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
	ld (PRINT_REDIRECT),a      ; เริ่มต้นสภาวะ clean เสมอ (กัน state ค้างจาก THAION รอบก่อน)
	ld a,(H_CHPUT)
	ld (PREV_CHPUT),a
	ld a,(H_CHPUT+1)
	ld (PREV_CHPUT+1),a
	ld a,(H_CHPUT+2)
	ld (PREV_CHPUT+2),a
	ld a,(H_CHPUT+3)
	ld (PREV_CHPUT+3),a
	ld a,(H_CHPUT+4)
	ld (PREV_CHPUT+4),a
	ld a,(MY_SLOT_ID)          ; คำนวณไว้แล้วโดย KEYC_INSTALL ที่เรียกก่อนหน้านี้เสมอ
	ld (H_CHPUT+1),a
	ld hl,PRINTHOOK
	ld (H_CHPUT+2),hl
	ld a,$C9                   ; RET
	ld (H_CHPUT+4),a
	ld a,RST30_OPCODE
	ld (H_CHPUT),a
	ei
	ret

PRINTHOOK_UNINSTALL:
	di
	ld a,(PREV_CHPUT)
	ld (H_CHPUT),a
	ld a,(PREV_CHPUT+1)
	ld (H_CHPUT+1),a
	ld a,(PREV_CHPUT+2)
	ld (H_CHPUT+2),a
	ld a,(PREV_CHPUT+3)
	ld (H_CHPUT+3),a
	ld a,(PREV_CHPUT+4)
	ld (H_CHPUT+4),a
	ei
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
PRINTHOOK:
	push hl
	push de
	push bc
	push af
	ld a,(PRINT_MODE)
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

	; --- ขั้น 1: sync CSRY แถวจริง (คืนค่าจากรอบก่อนถ้าเคยยักย้ายไว้) ---
	ld a,(PRINT_REDIRECT)
	or a
	jr z,.refresh_shadow
	; รอบก่อนยักย้าย CSRY ไปวาดตัวซ้อน -- คืนค่าแถวจริงจาก PRINT_ROW ก่อนทำอะไรต่อ
	ld a,(PRINT_ROW)
	ld (CSRY),a
	xor a
	ld (PRINT_REDIRECT),a
	jr .classify
.refresh_shadow:
	; รอบก่อนเป็นตัวอักษรปกติ (ไม่ได้ยักย้าย) -- CSRY ตอนนี้ถูกต้องอยู่แล้ว รีเฟรช
	; เงาไว้เผื่อรอบนี้ต้องยักย้าย
	ld a,(CSRY)
	ld (PRINT_ROW),a

.classify:
	; --- ขั้น 1.6 (ใหม่): แก้ VRAM ค้างจากการ "ผสม" สระบน+วรรณยุกต์ของรอบก่อน (ถ้ามี) ---
	; ดู comment เต็มที่ PRINT_COMBINE_PENDING ใน equates.asm: hook ไม่มีทางแทนที่ตัวอักษรที่
	; BIOS กำลังจะวาดได้เลย (แค่ยักย้ายตำแหน่งได้) จึงปล่อยให้ BIOS วาดวรรณยุกต์ตัวเปล่าทับ
	; ตำแหน่งสระบนไปก่อน (ผิดชั่วคราว 1 จังหวะ) แล้วมาแก้ทับด้วย WRTVRM ตรงนี้ตอนเรียกครั้งถัดไป
	; ก่อนประมวลผลตัวอักษรใหม่ใด ๆ เลย -- ไม่แตะ D/E เพราะยังไม่ถูกใช้งานตอนนี้ (กำหนดใหม่ทุกครั้ง
	; ที่ขั้น 3/5 ด้านล่าง) จึงปลอดภัยที่จะใช้เป็น scratch ตรงนี้ได้อิสระ
	ld a,(PRINT_COMBINE_PENDING)
	or a
	jr z,.no_combine_fix
	xor a
	ld (PRINT_COMBINE_PENDING),a
	push bc
	ld a,(PRINT_COMBINE_ROW)
	ld d,a
	ld a,(PRINT_COMBINE_COL)
	ld e,a
	ld a,d
	call NAMETAB_ADDR
	ld a,(PRINT_COMBINE_CODE)
	call WRTVRM
	pop bc
.no_combine_fix:
	; --- ขั้น 1.7 (ใหม่): Backspace ($08) ลบวรรณยุกต์ที่เพิ่งผสมไปเมื่อกี้ -- ต้องกลับไปแสดง
	; สระบนเดิมเปล่า ๆ (ไม่ใช่ glyph ผสม) ผู้ใช้ยืนยันเอง: "ถ้าลบวรรณยุกต์ออกต้องกลับมาวาดสระบน"
	; -- valid แค่ตัวถัดไปที่พิมพ์ "ทันที" หลังผสมเท่านั้น (ดู PRINT_LAST_MARK_* ใน equates.asm)
	ld a,c
	cp 8                              ; BS?
	jr nz,.notbs
	ld a,(PRINT_LAST_MARK_VALID)
	or a
	jr z,.notbs                       ; ไม่มีการผสมค้างให้ undo -- ปล่อยผ่าน BS ตามปกติ
	xor a
	ld (PRINT_LAST_MARK_VALID),a
	push bc
	push de
	ld a,(PRINT_LAST_MARK_ROW)
	ld d,a
	ld a,(PRINT_LAST_MARK_COL)
	ld e,a
	ld a,d
	call NAMETAB_ADDR
	ld a,(PRINT_LAST_MARK_VOWEL)
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
	ld (PRINT_LAST_MARK_VALID),a

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
	ld a,(PRINT_MODE)
	; หมายเหตุ: มาถึงจุดนี้ได้แปลว่า PRINT_MODE=TRUE แน่นอนอยู่แล้ว (เช็คตั้งแต่ต้น
	; PRINTHOOK) แต่เช็คซ้ำเผื่อโค้ดข้างบนถูกแก้ในอนาคต -- ไม่เสียหาย
	or a
	jr z,.notlf
	ld a,(CSRY)
	cp 22
	jr nc,.notlf                  ; CSRY>=22 -- ใกล้ขอบล่างเกินไป ข้ามการโก่ง (ข้อจำกัดที่ทราบ)
	add a,2
	ld (CSRY),a
	jp .done
.notlf:
	; --- ขั้น 2: จัดกลุ่มตัวอักษร C -- 0=ปกติ, 1=สระบน, 2=วรรณยุกต์, 3=สระล่าง (อุ/อู) ---
	; *** แก้ไขตามผู้ใช้ (เทียบกับฟอนต์บิตแมปจริงที่ผู้ใช้อัปโหลด thaifont.asm) ***: D6/D7 ไม่ใช่
	; สระบนอีก 2 ตัว แต่เป็นสระล่าง (อุ/อู) ที่ต้องซ้อนแถว+1 (ใต้พยัญชนะ) ไม่ใช่แถว-1 -- ย้ายออกจาก
	; UPPER_VOWEL_TABLE ไปเป็น LOWER_VOWEL_TABLE แยกต่างหาก (ดูรายละเอียดที่ตาราง 2 ชุดด้านล่าง)
	ld a,c
	call CLASSIFY_THAI_MARK      ; ไม่แตะ DE เลย (push/pop HL,BC ภายในตัวเอง)
	or a
	jp z,.done                  ; ตัวอักษรปกติ -- ไม่ต้องยักย้ายอะไร ปล่อย BIOS วาดตามปกติ
	ld b,a                       ; B = class (1/2/3) -- เก็บชั่วคราว

	; --- ขั้น 3: คำนวณคอลัมน์เป้าหมาย E = CSRX-1 (คอลัมน์ของตัวก่อนหน้าที่เพิ่งวาด
	; แล้ว cursor เลื่อนผ่านไปแล้ว) ---
	ld a,(CSRX)
	or a
	jp z,.done                  ; CSRX=0 (ต้นบรรทัดพอดี ไม่มีตัวก่อนหน้าให้ซ้อนทับ) -- กันเหนียว
	dec a
	ld e,a                       ; E = คอลัมน์เป้าหมาย (คงอยู่ตลอดตั้งแต่นี้)

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
	ld a,(PRINT_ROW)
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
	ld (PRINT_COMBINE_CODE),a
	ld a,(PRINT_ROW)
	dec a
	ld (PRINT_COMBINE_ROW),a
	ld a,e
	ld (PRINT_COMBINE_COL),a
	ld a,TRUE
	ld (PRINT_COMBINE_PENDING),a
	; --- บันทึกไว้เผื่อผู้ใช้กด Backspace ทันทีถัดจากนี้ -- ต้อง undo กลับเป็นสระบนเปล่า ๆ
	; (ดู PRINT_LAST_MARK_* ใน equates.asm และขั้น 1.7 ด้านบน) ---
	ld a,d                        ; A = สระบนเดิม (จาก D ที่สำรองไว้ -- ไม่ใช่ B ที่ถูกทับไปแล้ว)
	ld (PRINT_LAST_MARK_VOWEL),a
	ld a,(PRINT_ROW)
	dec a
	ld (PRINT_LAST_MARK_ROW),a
	ld a,e
	ld (PRINT_LAST_MARK_COL),a
	ld a,TRUE
	ld (PRINT_LAST_MARK_VALID),a
	jp .place_row_minus1          ; ตกลงไปวาดที่แถว-1 ตามปกติ (BIOS จะวาดวรรณยุกต์ตัวเปล่าทับ
	                               ; ตำแหน่งนี้ไปก่อน -- ผิดชั่วคราว 1 จังหวะ แล้วค่อยแก้เป็น glyph
	                               ; ผสมตอนเรียก PRINTHOOK ครั้งถัดไปตามที่เตรียมไว้ข้างบน)

.lower_vowel:
	; class=3 (สระล่าง อุ/อู) -- ซ้อนแถว+1 เสมอ (ใต้พยัญชนะ) ไม่มีการผสมกับวรรณยุกต์ใด ๆ (วรรณยุกต์
	; อยู่คนละตำแหน่ง -- เหนือพยัญชนะ ไม่เกี่ยวกับสระล่าง) ผู้ใช้ยืนยันเอง: "◌ุ กับ ◌ู วาดที่ N+1"
	ld a,(PRINT_ROW)
	add a,1
	cp 25                         ; เกินขอบล่างจอ (24 แถว, CSRY 1-based สูงสุด=24)?
	jp nc,.done                   ; กันเหนียว ไม่ซ้อนถ้าเกินขอบจอ
	ld (CSRY),a
	ld a,e
	ld (CSRX),a
	ld a,TRUE
	ld (PRINT_REDIRECT),a
	jp .done

.place_row_minus1:
	; class=1 (สระบนเดี่ยว ๆ) หรือ class=2 ที่ไม่มีสระบนให้ผสม (รวมถึงกรณีผสมแล้วที่ jr มาจากบนด้วย
	; -- ตำแหน่งวาดเหมือนกันทุกกรณี คือแถว-1 คอลัมน์เดิมของพยัญชนะ)
	ld a,(PRINT_ROW)
	dec a
	jp m,.done                   ; แถวติดลบ (บนสุดจอพอดี) -- กันเหนียว ไม่ซ้อน
	jp z,.done                   ; แถว=0 ก็ผิดปกติเช่นกัน (CSRY เป็น 1-based)
	ld (CSRY),a
	ld a,e
	ld (CSRX),a
	ld a,TRUE
	ld (PRINT_REDIRECT),a

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

; สระบน 3 ตัว: D1,D4,D5 -- ยืนยันจาก disassembly ของ original ROM (table #3 ใน
; printon_algorithm_report.md 1.4c/2.1) ว่าเป็นสมาชิกกลุ่ม "ซ้อนแถว-1" จริง และยืนยันซ้ำด้วย
; pixel-match ตรงกับฟอนต์บิตแมปจริง (thaifont.asm ที่ผู้ใช้อัปโหลด -- แถวล่างของ glyph ผสม
; 0x83-0x91 ตรงกับ glyph ของ D1/D4/D5 เดี่ยว ๆ เป๊ะทุกไบต์) *** แก้จากที่เข้าใจผิดไว้รอบแรกว่า
; มี 5 ตัว (รวม D6,D7) -- ผู้ใช้แก้ไข + ฟอนต์บิตแมปจริงยืนยันตรงกันว่า D6,D7 คือสระล่าง (อุ/อู)
; ไม่ใช่สระบน ย้ายไปอยู่ LOWER_VOWEL_TABLE ด้านล่างแทน ***
UPPER_VOWEL_TABLE:
	db $D1,$D4,$D5
UPPER_VOWEL_TABLE_LEN equ 3

; สระล่าง 2 ตัว: อุ(D6) อู(D7) -- ผู้ใช้ยืนยันเอง ("◌ุ กับ ◌ู วาดที่ N+1") ตรงกับฟอนต์บิตแมป
; จริงที่ผู้ใช้อัปโหลด (thaifont.asm) ที่ label โค้ดนี้ตรงตัวว่า "ุ"/"ู" พอดี -- ซ้อนแถว+1 (ใต้
; พยัญชนะ) ไม่ใช่แถว-1 เหมือนสระบน และไม่มีการผสมกับวรรณยุกต์ (ดู .lower_vowel ใน PRINTHOOK)
LOWER_VOWEL_TABLE:
	db $D6,$D7
LOWER_VOWEL_TABLE_LEN equ 2

; วรรณยุกต์ 4 รูป: ่(E8) ้(E9) ๊(EA) ๋(EB) -- ยืนยัน E8/E9 จาก THAI_UNSHIFTED_TABLE
; (scan code J,H) ส่วน EA/EB เป็นการอนุมานจากชุดวรรณยุกต์ไทยที่ทราบครบ (4 รูป
; ตามลำดับ mai-ek,mai-tho,mai-tri,mai-chattawa) -- ยืนยันซ้ำด้วย pixel-match ตรงกับ thaifont.asm
; (แถวบนของ glyph ผสม 0x83/0x88/0x8E ตรงกับ "08,08,00..." ของ E8 เป๊ะ เทียบ E9/EA/EB กับแถวบน
; ของ 0x85/0x86/0x87 ก็ตรงเป๊ะเช่นกัน แม้ comment auto-generate ในไฟล์นั้นจะ label E8-EB เป็นเลข
; ไทย ๐๑๒๓ ผิดก็ตาม -- pixel data ไม่โกหก)
TONE_MARK_TABLE:
	db $E8,$E9,$EA,$EB
TONE_MARK_TABLE_LEN equ 4

; ---- COMBINE_LOOKUP -----------------------------------------------------------
; entry: A = โค้ดสระบน (ต้องเป็นสมาชิกของ UPPER_VOWEL_TABLE อยู่แล้ว -- ผู้เรียกยืนยันด้วย
;        CLASSIFY_THAI_MARK ก่อนเรียกเสมอ), C = โค้ดวรรณยุกต์ (E8-EB)
; exit:  A = โค้ด glyph ที่ผสมแล้ว (จาก COMBINE_TABLE ด้านล่าง) -- ทำลาย B/C/HL เท่านั้น
;        *** ไม่แตะ D/E เลย *** (PRINTHOOK พึ่งพา E คงค่าคอลัมน์เป้าหมายตลอดทั้งฟังก์ชัน)
COMBINE_LOOKUP:
	ld hl,UPPER_VOWEL_TABLE
	ld b,0                        ; B = ดัชนีสระ (0-based, นับผ่านตาราง)
.find_vowel:
	cp (hl)                       ; cp ไม่แตะ A -- แค่ตั้ง flag เทียบกับ (hl)
	jr z,.found_vowel
	inc hl
	inc b
	jr .find_vowel
.found_vowel:
	ld a,b
	add a,a
	add a,a                        ; A = ดัชนีสระ*4
	ld b,a
	ld a,c
	sub $E8                         ; A = ดัชนีวรรณยุกต์ (0-3)
	add a,b                         ; A = offset ใน COMBINE_TABLE
	ld c,a
	ld b,0
	ld hl,COMBINE_TABLE
	add hl,bc
	ld a,(hl)
	ret

; COMBINE_TABLE -- โค้ด glyph ที่ผสมสระบน+วรรณยุกต์แล้ว เรียงตาม UPPER_VOWEL_TABLE (D1,D4,D5)
; x TONE_MARK_TABLE (E8,E9,EA,EB) = 3x4 = 12 ไบต์ -- ยืนยันสองทาง: (1) disassembly ของ
; original ROM เอง ($5582 ใน printon_algorithm_report.md section 1.5/2.1) และ (2) pixel-match
; ตรงกับฟอนต์บิตแมปจริง (thaifont.asm ที่ผู้ใช้อัปโหลด -- แถวบน 2 แถวของแต่ละ glyph ตรงกับ
; วรรณยุกต์เดี่ยว ๆ เป๊ะ, แถวล่างตรงกับสระบนเดี่ยว ๆ เป๊ะ ทุกไบต์) ผู้ใช้ยืนยันด้วยตนเองด้วย:
; "ไม้หันอากาศ ไม้เอกต้องผสมกัน แล้ววาดแทนไม้หันอากาศเดิม ที่ N-1"
COMBINE_TABLE:
	db $83,$85,$86,$87    ; D1 + (E8,E9,EA,EB)
	db $88,$89,$8A,$8B    ; D4 + (E8,E9,EA,EB)
	db $8E,$8F,$90,$91    ; D5 + (E8,E9,EA,EB)

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
	dec a                        ; แถว -1 (0-based)
	ld l,a
	ld h,0                        ; HL = แถว(0-based)
	add hl,hl                     ; *2
	add hl,hl                     ; *4
	add hl,hl                     ; *8
	ld b,h
	ld c,l                        ; BC = แถว*8
	add hl,hl                     ; *16
	add hl,hl                     ; *32
	add hl,bc                     ; HL = แถว*32 + แถว*8 = แถว*40
	ld d,0                         ; DE = คอลัมน์ (E ตั้งไว้จากผู้เรียกแล้ว)
	add hl,de                     ; HL += คอลัมน์
	; *** บั๊กที่เจอ+แก้แล้ว: "LD DE,(NAMPNT)" ด้านล่างโหลดทั้ง D "และ" E ทับ (ไม่ใช่แค่ D)
	; ทำให้ E (คอลัมน์เป้าหมายของผู้เรียก) ถูกเขียนทับเป็น low byte ของ NAMPNT (=0 ปกติ) --
	; ผู้เรียก (PRINTHOOK ขั้น 5) ใช้ E ต่อหลัง call นี้เพื่อตั้ง CSRX เลยได้ค่าผิด (เจอจริงผ่าน
	; breakpoint: วรรณยุกต์ที่ควรอยู่คอลัมน์เดียวกับพยัญชนะ กลับไปอยู่คอลัมน์ 0 เสมอ) แก้ด้วยการ
	; push/pop DE ครอบขั้นตอนนี้เพื่อกันไม่ให้ E ของผู้เรียกเสียหาย
	push de
	ld de,(NAMPNT)
	add hl,de                     ; HL += NAMPNT base
	pop de
	inc hl                         ; ค่าคงที่ที่ยืนยันแล้ว (ดู comment ด้านบน)
	ret
