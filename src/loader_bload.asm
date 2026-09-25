; ==========================================================================
; loader_bload.asm -- 9.43: ตัวโหลดสำหรับ BLOAD"THAIMSX.BIN",R (ดิสก์ หรือเทป CAS:)
;
; คัดลอก image รุ่น RAM (build/thaimsx_ram.bin, org $4000) ลง RAM ของ page 1 ใน slot เดียวกับ RAM ของ
; page 3 (MSX2/2+ = memory mapper, MSX1 = ต้องมี RAM 64 KB) แล้วทำเหมือน BIOS ทำกับตลับจริง:
;   - SLTATR ช่องของ slot นั้น/page 1 |= $20 -> CALL ของ BASIC ($55CB) ส่งคำสั่งมาที่ $4004 ของ slot นั้น
;   - เรียก INIT ($4002) ผ่าน CALSLT -> ติดตั้ง H.READ -> พอ BASIC ขึ้น "Ok" ครั้งถัดไป = THAION + ข้อความเวอร์ชัน
; ไม่ใช้ HIMEM (ตัวแปรอยู่ต่อท้ายโค้ดใน page 1) -- ตัวโหลดเองอยู่ที่ $9000 ใช้ครั้งเดียวแล้วทิ้งได้
; ==========================================================================

RDSLT   equ $000C
WRSLT   equ $0014
CALSLT  equ $001C
ENASLT  equ $0024
CHPUT   equ $00A2
EXPTBL  equ $FCC1
SLTATR  equ $FCC9
LOADADR equ $9000

	org LOADADR-7
	db $FE
	dw LOADADR, LOAD_END-1, START

START:
	; --- slot ของ RAM ใน page 3 = E000SSPP ---
	in a,($A8)
	rlca
	rlca
	and 3
	ld c,a                        ; primary
	ld b,0
	ld hl,EXPTBL
	add hl,bc
	ld a,(hl)
	and $80
	jr z,.slot_ok
	ld a,($FFFF)
	cpl
	rlca
	rlca
	and 3
	add a,a
	add a,a
	or $80
.slot_ok:
	or c
	ld (TSLOT),a
	; --- SLTATR ช่องนี้/page 1 = primary*16 + secondary*4 + 1 ---
	ld e,a
	and 3
	add a,a
	add a,a
	add a,a
	add a,a
	ld c,a
	ld a,e
	and $0C
	add a,c
	inc a
	ld c,a
	ld b,0
	ld hl,SLTATR
	add hl,bc
	ld (ATRPTR),hl
	bit 5,(hl)
	ld hl,MSG_LOADED
	jr nz,PRINT                   ; มี CALL handler ใน slot/page นี้อยู่แล้ว = โหลดไว้แล้ว
	; --- page 1 ของ slot นี้ต้องเป็น RAM ---
	ld a,(TSLOT)
	ld hl,$4000
	call RDSLT
	cpl
	ld e,a
	push de
	ld a,(TSLOT)
	ld hl,$4000
	call WRSLT
	ld a,(TSLOT)
	ld hl,$4000
	call RDSLT
	ei
	pop de
	cp e
	ld hl,MSG_NORAM
	jr nz,PRINT
	; --- คัดลอก image: เปิด page 1 เป็น RAM ชั่วคราว (interrupt ปิดตลอด) ---
	di
	ld a,(TSLOT)
	ld h,$40
	call ENASLT
	ld hl,IMAGE
	ld de,$4000
	ld bc,IMAGE_END-IMAGE
	ldir
	ld a,(EXPTBL)                 ; คืน page 1 = BASIC ROM (slot ของ main ROM)
	ld h,$40
	call ENASLT
	ei
	; --- ลงทะเบียน CALL แล้วเรียก INIT ---
	ld hl,(ATRPTR)
	set 5,(hl)
	ld a,(TSLOT)
	ld h,a
	ld l,0
	push hl
	pop iy                        ; IYH = slot
	ld ix,(IMAGE+2)               ; INIT
	call CALSLT
	ei
	ret

PRINT:
	ld a,(hl)
	or a
	ret z
	call CHPUT
	inc hl
	jr PRINT

MSG_NORAM:  db "thaimsx: need 64KB RAM (page 1)",13,10,0
MSG_LOADED: db "thaimsx: already loaded",13,10,0
TSLOT:  db 0
ATRPTR: dw 0

IMAGE:
	incbin "build/thaimsx_ram.bin"
IMAGE_END:
LOAD_END:
