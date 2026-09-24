; ==========================================================================
; workram.asm -- 9.27: RAM ส่วนตัวของ ROM (ย้ายออกจาก SLTWRK $FD09-$FD5B)
;
; เดิมตัวแปรทั้งหมดอยู่ที่ $FD09-$FD5B ซึ่งเป็น SLTWRK ของ BIOS (ช่องของ slot อื่น) -- ถ้าเครื่องมี ROM
; อื่นใช้ช่องนั้น (เช่น disk interface) จะชนกัน. วิธีมาตรฐานของ cartridge MSX:
;   1. INIT ลด HIMEM ($FC4A) ลง WORK_SIZE ไบต์ = จองพื้นที่ใต้ขอบบนของ BASIC (BASIC ตั้ง stack/
;      buffer จาก HIMEM หลัง cartridge init ทั้งหมดเสร็จ จึงไม่มีใครใช้พื้นที่นี้อีก)
;   2. เก็บ address ของบล็อกไว้ใน SLTWRK "ช่องของ slot เราเอง" (page 1) -- ช่องนี้เป็นของเราตามข้อกำหนด
;   3. ทุกจุดเข้า (hook ทุกตัว, CALL, INIT) โหลด IX = บล็อก แล้วอ้างตัวแปรแบบ (ix+offset)
; ผลข้างเคียงที่เห็นได้: "Bytes free" ลดลง WORK_SIZE ไบต์
; ==========================================================================

; SLOT_WORK_ADDR: HL = address ของช่อง SLTWRK ของเรา (slot ปัจจุบันของ page 1, page 1)
; SLTWRK + primary*32 + secondary*8 + page*2 -- ทำลาย AF,BC (คง DE)
SLOT_WORK_ADDR:
	call GET_MY_SLOT              ; A = E000SSPP
	ld c,a
	and 3
	rrca
	rrca
	rrca                          ; primary*32
	ld b,a
	ld a,c
	and $0C
	add a,a                       ; secondary*8
	add a,b
	add a,2                       ; page 1
	ld c,a
	ld b,0
	ld hl,SLTWRK
	add hl,bc
	ret

; GET_IX: IX = บล็อก RAM ของเรา -- คงทุก register อื่น (รวม flag)
GET_IX:
	push af
	push bc
	push hl
	call SLOT_WORK_ADDR
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	push hl
	pop ix
	pop hl
	pop bc
	pop af
	ret

; WORK_ALLOC: จองบล็อก (ครั้งแรกเท่านั้น -- INIT อาจถูกเรียกซ้ำ) -- ทำลาย AF,BC,DE,HL
WORK_ALLOC:
	call SLOT_WORK_ADDR
	ld a,(hl)
	inc hl
	or (hl)
	ret nz                        ; จองไว้แล้ว
	dec hl
	push hl
	; 9.29: disk ROM ตัวหลัก (master) ใช้ RAM ตายตัว $F1C9-$F37F เป็นพื้นที่ระบบของ DOS เสมอ -- ตอน INIT
	; ล้างช่วงนี้แล้วลด HIMEM ลง $1BF จากค่าปัจจุบัน (disassembly disk ROM $57A9-$57C3) ถ้าเรา init ก่อน
	; (HIMEM ยังเป็น $F380) แล้วจองจาก $F380 ลงมา บล็อกจะทับตัวแปร DOS -> Disk BASIC พัง ("Bad file number",
	; FILES = Syntax error) -- ถ้ามี disk ROM ใน slot อื่นจึงจองใต้ $F1C9 แทน (disk ROM จะกันช่วงบนไว้ให้ DOS เอง)
	ld hl,(HIMEM)
	ld de,$F380
	or a
	sbc hl,de
	jr nz,.wa_normal              ; มีคนลด HIMEM ไปแล้ว (disk ROM init ก่อนเรา) -> จองต่อจากนั้นได้เลย
	call DISK_PRESENT
	ei                            ; RDSLT ปิด interrupt ไว้
	jr nc,.wa_normal
	ld hl,DOS_AREA
	ld (HIMEM),hl
.wa_normal:
	ld hl,(HIMEM)
	ld de,-WORK_SIZE
	add hl,de
	ld (HIMEM),hl
	push hl
	ld b,WORK_SIZE
.wa_zero:
	ld (hl),0
	inc hl
	djnz .wa_zero
	pop de                        ; DE = บล็อก
	pop hl                        ; HL = ช่อง SLTWRK
	ld (hl),e
	inc hl
	ld (hl),d
	; fall through -> FIX_FILES

; FIX_FILES: BASIC จัดพื้นที่ file buffer (FILTAB/FCB) ไว้ใต้ HIMEM "ก่อน" เรียก INIT ของ cartridge
; (MSX1/2/2+: ตั้งที่ $7CCC ก่อน scan slot ที่ $7D14 และไม่คำนวณใหม่หลัง scan) -- ถ้าแค่ลด HIMEM
; บล็อกของเราจะทับ buffer ของไฟล์ #1 (OPEN ... AS #1 เขียนทับตัวแปร/ hook ที่สำรองไว้ -> ค้าง)
; จึงจัดใหม่ตามสูตรเดียวกับที่ BASIC ใช้ตอน MAXFILES= / CLEAR โดยใช้ตัวแปรระบบที่ documented:
;   FILTAB = HIMEM - $10B*(MAXFIL+1), MEMSIZ = FILTAB-2, STKTOP = MEMSIZ - (ขนาด string space เดิม)
;   FILTAB[i] = FCB i (ต่อกันทีละ $109 ไบต์ เริ่มหลังตาราง), ไบต์แรกของ FCB = 0, NULBUF = FCB0+9
; SP ไม่ต้องย้าย: หลัง scan BASIC ตั้ง stack ใหม่จาก STKTOP เอง ($6287 -> $62E5) -- ทำลายทุก register
FIX_FILES:
	ld hl,(STKTOP)
	push hl                       ; STKTOP เดิม (ใช้ย้าย stack ตอนท้าย)
	ld hl,(MEMSIZ)
	ld de,(STKTOP)
	or a
	sbc hl,de
	push hl                       ; ขนาด string space
	ld a,(MAXFIL)
	ld b,a
	inc b                         ; B = จำนวน FCB (รวม #0)
	ld hl,(HIMEM)
	ld de,-$10B
.ff_sub:
	add hl,de
	djnz .ff_sub
	ld (FILTAB),hl
	dec hl
	dec hl
	ld (MEMSIZ),hl
	pop de
	or a
	sbc hl,de
	ld (STKTOP),hl
	ld a,(MAXFIL)
	ld b,a
	inc b
	ld hl,(FILTAB)
	ld e,b
	ld d,0
	ex de,hl
	add hl,hl
	add hl,de
	ex de,hl                      ; HL = ตาราง, DE = FCB0 (หลังตาราง)
	push de
.ff_fcb:
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	xor a
	ld (de),a
	push hl
	ld hl,$109
	add hl,de
	ex de,hl
	pop hl
	djnz .ff_fcb
	pop hl
	ld bc,9
	add hl,bc
	ld (NULBUF),hl
	ld hl,(STKTOP)
	dec hl
	dec hl
	ld (SAVSTK),hl
	; ย้าย stack ที่ใช้อยู่ (SP..STKTOP เดิม) ลงไปเท่ากับที่ STKTOP ลด -- ให้ SP <= STKTOP เสมอ แบบเดียวกับที่
	; disk ROM ทำตอนย้ายหน่วยความจำ ($5F02-$5F19 ใน disk ROM ของ Philips): disk ROM ที่ init ทีหลังคำนวณ
	; ขนาด stack จาก STKTOP-SP ถ้า SP ยังอยู่เหนือ STKTOP ใหม่ จะคัดลอกผิดแล้วค้าง (บูตไม่ขึ้น prompt)
	pop hl                        ; STKTOP เดิม
	ld de,(STKTOP)
	or a
	sbc hl,de
	ld b,h
	ld c,l                        ; BC = ระยะที่เลื่อน
	ld hl,0
	add hl,sp
	ex de,hl                      ; DE = SP ปัจจุบัน (ต้นทาง)
	ld l,e
	ld h,d
	or a
	sbc hl,bc                     ; HL = ปลายทาง
	ld sp,hl                      ; push ต่อจากนี้ลงใต้ปลายทาง ไม่ทับต้นทาง
	push hl
	ld hl,(STKTOP)
	add hl,bc                     ; STKTOP เดิม
	or a
	sbc hl,de
	inc hl
	ld b,h
	ld c,l                        ; BC = STKTOP เดิม - SP + 1
	ex de,hl                      ; HL = ต้นทาง
	pop de                        ; DE = ปลายทาง
	ldir                          ; เลื่อนลง (ปลายทาง < ต้นทาง) -- คัดลอกจากล่างขึ้นบนปลอดภัย
	ret                           ; return address ที่ย้ายแล้ว

; DISK_PRESENT: carry=1 ถ้ามี disk ROM ใน slot อื่น (ไม่นับ slot เรา) -- ลายเซ็น: "AB" ที่ $4000 และ JP ($C3)
; ที่ $4010/$4013/$4016/$4019/$401C (DSKIO/DSKCHG/GETDPB/CHOICE/DSKFMT ตามข้อกำหนด disk driver ของ MSX-DOS;
; ตรวจกับ disk ROM ของ Philips/Panasonic/National/Microsol, MSX-DOS 2.3, Sunrise IDE, Beer IDE แล้ว)
; อ่านผ่าน RDSLT (BIOS $000C) -- ทำลายทุก register, ออกมาแบบ DI
DISK_PRESENT:
	ld b,0                        ; B = slot หลัก
.dp_prim:
	ld hl,EXPTBL
	ld a,l
	add a,b
	ld l,a
	ld a,(hl)
	and $80
	or b
	ld c,a                        ; C = slot ID (E000SSPP)
.dp_sec:
	push bc
	ld a,c
	call CHECK_DISK
	pop bc
	ret c
	bit 7,c
	jr z,.dp_next                 ; ไม่ได้ขยาย -> มี slot เดียว
	ld a,c
	add a,4
	ld c,a
	and $0C
	jr nz,.dp_sec
.dp_next:
	inc b
	ld a,b
	cp 4
	jr nz,.dp_prim
	or a
	ret

; CHECK_DISK: A = slot ID -> carry=1 ถ้าเป็น disk ROM (และไม่ใช่ slot เราเอง)
CHECK_DISK:
	ld e,a
	push de
	call GET_MY_SLOT
	pop de
	cp e
	ret z                         ; slot เราเอง (carry=0)
	ld hl,DISK_SIG
.cd_loop:
	ld a,(hl)
	or a
	scf
	ret z                         ; ครบทุกไบต์ -> เป็น disk ROM
	push hl
	push de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a                        ; HL = address ที่จะอ่าน
	ld a,e
	call RDSLT
	pop de
	pop hl
	inc hl
	inc hl
	cp (hl)
	inc hl
	jr z,.cd_loop
	or a
	ret

DISK_SIG:                         ; (address, ค่าที่ต้องเป็น) -- จบด้วย 0 (low byte ของ address ไม่เคยเป็น 0 ยกเว้น $4000 ที่ขึ้นก่อน)
	dw $4001
	db 'B'
	dw $4010
	db $C3
	dw $4013
	db $C3
	dw $4016
	db $C3
	dw $4019
	db $C3
	dw $401C
	db $C3
	db 0

; IX_HL: HL = IX + HL / IX_DE: DE = IX + DE (offset -> address จริง) -- คง register อื่น
IX_HL:
	push de
	push ix
	pop de
	add hl,de
	pop de
	ret

IX_DE:
	push hl
	push ix
	pop hl
	add hl,de
	ex de,hl
	pop hl
	ret

; CHPUT_IX: CHPUT แบบคง IX (กันกรณี BIOS/sub-ROM ใช้ IX ระหว่างทาง)
CHPUT_IX:
	push ix
	call CHPUT
	pop ix
	ret

; ---- จุดเข้าทั้งหมด: ตั้ง IX แล้วเรียกตัวจริง (_BODY) -- คง IX ของผู้เรียกไว้เสมอ ----
INIT:
	push ix
	call WORK_ALLOC
	call GET_IX
	call INIT_BODY
	pop ix
	ret

STATEMENT:
	push ix
	call GET_IX
	call STATEMENT_BODY
	pop ix
	ret

BOOT_HOOK:
	push ix
	call GET_IX
	call BOOT_BODY
	pop ix
	jp H_READ                     ; ต่อไปยัง hook เดิม (BOOT_BODY คืนค่าเดิมกลับเข้า H_READ แล้ว)

KEYC_HOOK_REAL:
	push ix
	call GET_IX
	call KEYC_BODY
	pop ix
	ret

PRINTHOOK:
	push ix
	call GET_IX
	call PRINTHOOK_BODY
	pop ix
	ret

CHGE_HOOK:
	push ix
	call GET_IX
	call CHGE_BODY
	pop ix
	ret

INLIN_HOOK:
	push ix
	call GET_IX
	call INLIN_BODY
	pop ix
	ret

DSPC_HOOK:
	push ix
	call GET_IX
	call DSPC_BODY
	pop ix
	ret

ERAC_HOOK:
	push ix
	call GET_IX
	call ERAC_BODY
	pop ix
	ret

; TIMI_HOOK: หลังทำงานเสร็จต้องกระโดดต่อไปที่ hook เดิม (สำรองไว้ในบล็อกที่ ix+PREV_TIMI) โดยทุก
; register ต้องเหมือนตอนเข้ามา -- ใส่ address ปลายทางไว้บน stack แล้ว RET
TIMI_HOOK:
	push ix
	call GET_IX
	call TIMI_BODY
	ex (sp),ix                    ; IX = ของผู้เรียก, (sp) = บล็อก
	ex (sp),hl                    ; HL = บล็อก, (sp) = HL เดิม
	push af
	push de
	ld de,0+PREV_TIMI
	add hl,de
	pop de
	pop af                        ; flag เดิมกลับมาด้วย
	ex (sp),hl                    ; HL = ค่าเดิม, (sp) = ปลายทาง
	ret

; GRPO_HOOK (9.33): H.FEC6 -- ทำงานแล้วส่งต่อ hook เดิม (บล็อก+PREV_GRPO) ด้วย A ที่อาจเปลี่ยนแล้ว (register
; อื่นคืนตามเดิมทุกตัว) แบบเดียวกับ TIMI_HOOK
GRPO_HOOK:
	push ix
	call GET_IX
	call GRPO_BODY
	ex (sp),ix
	ex (sp),hl
	push af
	push de
	ld de,0+PREV_GRPO
	add hl,de
	pop de
	pop af
	ex (sp),hl
	ret

; LPTO_HOOK (9.36): H.LPTO -- ทำงานแล้วส่งต่อ hook เดิม (บล็อก+PREV_LPTO) ด้วย A ที่อาจเปลี่ยนแล้ว แบบ TIMI_HOOK
LPTO_HOOK:
	push ix
	call GET_IX
	call LPTO_BODY
	ex (sp),ix
	ex (sp),hl
	push af
	push de
	ld de,0+PREV_LPTO
	add hl,de
	pop de
	pop af
	ex (sp),hl
	ret
