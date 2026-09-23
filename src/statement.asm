; ==========================================================================
; statement.asm -- STATEMENT vector: BASIC เรียกทุกครั้งที่เจอ keyword ที่ไม่รู้จัก
;
; โปรโตคอลนี้ "ยืนยันจากพฤติกรรมจริง" ของ MSXTHA102.ROM ต้นฉบับ (ไม่ได้เดา):
; ระหว่างวางแผนโปรเจกต์นี้ได้ disassemble 0x41EE ของ ROM เดิมโดยตรง พบว่า:
;   - เข้ามาด้วย HL = "continuation pointer" (ตำแหน่งใน BASIC text ที่จะพาร์สต่อ
;     ถ้า statement นี้ตรงกับที่เรารู้จัก)
;   - เปรียบเทียบชื่อกับ buffer ที่ documented address 0xFD89 (PROCNM -- ระบบ
;     BASIC มาตรฐานสำหรับ extended-statement/CALL name matching)
;   - ไม่พบ: HL คืนค่าเดิม, carry=1 (SET), RET
;   - พบ: กระโดดไป handler โดยค่า HL เดิม (continuation pointer) ยังอยู่บน stack
;     ให้ handler POP HL เอาไปใช้เอง แล้วจบด้วย XOR A (carry=0, CLEAR) + EI + RET
;
; *** แก้บั๊กจริงที่เจอจากการทดสอบพิมพ์ "call thaion"/"thaion" บน real MSX1 BIOS ผ่าน
; openMSX: ตอนแรกเข้าใจ polarity ของ carry flag กลับด้าน (คิดว่า carry=1=สำเร็จ,
; carry=0=ไม่พบ) ทำให้ BASIC ขึ้น "Syntax error" ทุกครั้งแม้ handler จะทำงานถูกต้องแล้ว
; จริงๆ (flag/ฟอนต์ถูกตั้งค่าถูกต้อง เห็นจาก memory dump แต่ BASIC ก็ยังไม่ยอมรับว่า
; statement นี้ถูกจัดการ) -- ไปยืนยันแหล่งที่มาอีกรอบด้วยการ disassemble ต้นฉบับให้
; ละเอียดขึ้น พบว่า path "สำเร็จ" ที่แท้จริง (เช่น PRINTON handler จบด้วย "JP 0x44FB"
; ไม่ใช่กระโดดไป epilogue เดียวกับ not-found) ไปเข้า 0x44FB ซึ่งทำ "POP HL; XOR A;
; EI; RET" (carry=0!) ส่วน path not-found จริงๆ (0x422A) ทำ "XOR A; SCF; POP HL;
; EI; RET" (carry=1) -- กลับด้านจากที่เข้าใจไว้แต่แรกทั้งคู่ ตอนนี้แก้ไขให้ตรงแล้ว
;
; ตารางคำสั่ง (CMDTAB) ใช้ฟอร์แมตเดียวกับต้นฉบับ (ถอดออกมาได้ตรง ๆ จาก raw bytes
; ที่ 0x46ED ระหว่างวางแผน): "NAME",0  แล้วตามด้วย dw handler_addr ซ้ำไปเรื่อย ๆ
; จบด้วย $FF
; ==========================================================================

STATEMENT_BODY:
	ei
	push hl                ; เก็บ continuation pointer ไว้ก่อน
	ld hl,CMDTAB
.entry:
	ld a,(hl)
	cp $FF
	jr z,.notfound
	push hl                 ; เก็บตำแหน่งเริ่มต้นของ entry นี้ไว้
	ld de,PROCNM
.cmpchar:
	ld a,(hl)
	or a
	jr z,.name_ended
	ld b,a
	ld a,(de)
	cp b
	jr nz,.mismatch
	inc hl
	inc de
	jr .cmpchar
.name_ended:
	ld a,(de)
	cp ' '
	jr z,.match
	or a
	jr z,.match
	cp ':'
	jr z,.match
.mismatch:
	pop hl                   ; คืน hl ไปที่จุดเริ่ม entry นี้
.skipname:
	ld a,(hl)
	inc hl
	or a
	jr nz,.skipname
	inc hl
	inc hl                   ; ข้าม address 2 ไบต์ -> hl ชี้ entry ถัดไป
	jr .entry
.match:
	; hl ชี้ null terminator ของชื่อที่ match แล้ว -- address ตามมาทันที
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a                   ; hl = handler address
	pop de                   ; ทิ้งค่าที่เก็บไว้ (ไม่ใช้แล้ว)
	jp (hl)                  ; กระโดดเข้า handler -- continuation pointer ยังอยู่บน stack
.notfound:
	pop hl                   ; คืน continuation pointer เดิม ไม่แก้ไข
	scf                      ; carry=1 = "ไม่รู้จักคำสั่งนี้" (ยืนยันจาก ROM เดิมจริง)
	ei
	ret

; ---- epilogue ที่ handler ทุกตัวเรียกใช้ร่วมกันตอนจบงานสำเร็จ ----
STMT_DONE:
	xor a                     ; carry=0 = "รู้จักและจัดการแล้ว" (ยืนยันจาก ROM เดิมจริง)
	ei
	ret
