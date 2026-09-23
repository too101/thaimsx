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
	ret

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
