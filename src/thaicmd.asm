; ==========================================================================
; thaicmd.asm -- ตารางคำสั่ง (CMDTAB) + handler ของแต่ละคำสั่ง
;
; Phase 1: implement ครบเฉพาะกลุ่ม flag-toggle (PRINTON/OFF, INPUTON/OFF,
; PLOCKON/OFF) และ THAION/THAIOFF แบบง่าย (ยังไม่โหลดฟอนต์จริง -- รอ Phase 2
; ที่จะเติม font install เข้ามาในนี้). SYSTEM/LPRINT/ANSTR/TNSTR/MLSTR เป็น stub
; ที่ยังไม่ implement จริง (แค่ตอบรับว่า "รู้จักคำสั่งนี้" เฉย ๆ) -- Phase 4
; ==========================================================================

CMDTAB:
	db "PRINTON",0
	dw CMD_PRINTON
	db "?ON",0
	dw CMD_PRINTON
	db "PRINTOFF",0
	dw CMD_PRINTOFF
	db "?OFF",0
	dw CMD_PRINTOFF
	db "INPUTON",0
	dw CMD_INPUTON
	db "@ON",0
	dw CMD_INPUTON
	db "INPUTOFF",0
	dw CMD_INPUTOFF
	db "@OFF",0
	dw CMD_INPUTOFF
	db "PLOCKON",0
	dw CMD_PLOCKON
	db "PLOCKOFF",0
	dw CMD_PLOCKOFF
	db "THAION",0
	dw CMD_THAION
	db "THAIOFF",0
	dw CMD_THAIOFF
	db "SYSTEM",0
	dw CMD_STUB
	db "LPRINT",0
	dw CMD_STUB
	db "ANSTR",0
	dw CMD_STUB
	db "TNSTR",0
	dw CMD_STUB
	db "MLSTR",0
	dw CMD_STUB
	db $FF

; --- flag toggle handlers -------------------------------------------------
; PLOCK_MODE=TRUE หมายถึงล็อก PRINTON/PRINTOFF ไว้ไม่ให้เปลี่ยน (ตามต้นฉบับ)

CMD_PRINTON:
	pop hl
	ld a,(ix+PLOCK_MODE)
	or a
	jp nz,STMT_DONE          ; ถูกล็อกอยู่ -- ไม่ทำอะไร แต่ถือว่า "จัดการแล้ว"
	ld a,TRUE
	ld (ix+PRINT_MODE),a
	jp STMT_DONE

CMD_PRINTOFF:
	pop hl
	ld a,(ix+PLOCK_MODE)
	or a
	jp nz,STMT_DONE
	xor a
	ld (ix+PRINT_MODE),a
	; เปิด blinking-cursor กลับ (PRINTHOOK ปิดไว้ตอน PRINTON -- ดู comment เต็มที่
	; CURSOR_BLINK_FLAG ใน equates.asm)
	ld a,TRUE
	ld (CURSOR_BLINK_FLAG),a
	jp STMT_DONE

CMD_INPUTON:
	pop hl
	ld a,TRUE
	ld (ix+INPUT_MODE),a
	jp STMT_DONE

CMD_INPUTOFF:
	pop hl
	xor a
	ld (ix+INPUT_MODE),a
	jp STMT_DONE

CMD_PLOCKON:
	pop hl
	ld a,TRUE
	ld (ix+PLOCK_MODE),a
	jp STMT_DONE

CMD_PLOCKOFF:
	pop hl
	xor a
	ld (ix+PLOCK_MODE),a
	jp STMT_DONE

; --- THAION / THAIOFF ------------------------------------------------------
; แนวทาง portable: CGPNT (0xF91F, documented system variable) บอกตำแหน่ง VRAM
; ของ pattern-generator table ปัจจุบัน "ไม่ว่า generation ไหน" -- เราแค่อ่านค่า
; นี้แล้วเขียนฟอนต์ไทยทับลงไปตรงนั้นผ่าน LDIRVM (jump table แท้ ไม่ใช่ internal
; address) ไม่ต้องคำนวณ VRAM address เองเลย
;
; *** อัปเดต (คำขอผู้ใช้: THAIOFF ไม่ต้องเคลียร์หน้าจอ) -- เดิม CMD_THAIOFF เรียก INITXT
; (jump table 0x006C) เพื่อ reload ฟอนต์มาตรฐานกลับเข้า VRAM แบบง่าย/portable (ไม่ต้องสำรอง
; 2040 ไบต์ของฟอนต์เดิมไว้ใน RAM เอง ซึ่งต้องเดาตำแหน่ง RAM ว่าง เสี่ยงแบบเดียวกับบั๊กข้อ 12) แต่
; INITXT เคลียร์ทั้งจอ + รีเซ็ต cursor ไปด้วยเสมอ (เป็นผลข้างเคียงของการ init โหมดข้อความใหม่ทั้งหมด
; ไม่ใช่แค่ reload ฟอนต์อย่างเดียว) ทำให้ผู้ใช้เสียเนื้อหาที่กำลังดู/แก้ไขอยู่ทุกครั้งที่สั่ง THAIOFF --
; ตรวจสอบแล้วว่าฟอนต์ไทย (FONT_THAI, คัดลอกจาก ROM ต้นฉบับตรง ๆ) กับฟอนต์มาตรฐานของระบบ เหมือนกัน
; แทบทุกไบต์ในช่วง ASCII พิมพ์ได้ (0x20-0x7E): เทียบ byte-by-byte จริงบน openMSX (VRAM dump หลัง cold
; boot ปกติ ไม่มี cartridge เทียบกับ assets/font_raw.bin) พบต่างแค่ 1 ตัวอักษร ('b' รหัส 98) และต่างแค่
; เศษพิกเซลเดียว (ไม่กระทบการอ่านเลย) -- จึงไม่จำเป็นต้อง reload ฟอนต์ตอน THAIOFF เลย เอา INITXT ออก
; ตรง ๆ ปลอดภัย ไม่มีผลข้างเคียงที่มองเห็นได้จริง

CMD_THAION:
	pop hl
	push hl
	call THAION_CORE
	pop hl
	jp STMT_DONE

; THAION_CORE (9.22): งานของ THAION ทั้งหมด แยกออกมาให้ BOOT_HOOK เรียกตอนบูตได้ด้วย -- ทำลายทุก register
THAION_CORE:
	ld a,TRUE
	ld (ix+THAI_MODE),a
	; DI/EI รอบ LDIRVM: เก็บไว้เป็น defensive practice (กัน interrupt แทรกกลางการ copy
	; VRAM 2040 ไบต์) *** แก้ข้อมูลที่เข้าใจผิดไว้ก่อนหน้า: diff 862/2040 ไบต์ที่เจอตอนแรก
	; ไม่ได้เกิดจากปัญหานี้จริง ๆ -- พิสูจน์แล้วว่าเป็น test-script อ่าน VRAM เร็วเกินไป (อ่านก่อน
	; LDIRVM ทำงานเสร็จ) ไม่ใช่ interrupt แย่ง VDP latch (ใส่ DI/EI แล้ว diff เดิมยังอยู่เท่าเดิม
	; จนกว่าจะแก้ timing ของ test script เอง ถึงหาย) แต่ DI/EI ยังถูกต้องในหลักการเลยคงไว้
	di
	ld hl,FONT_THAI
	ld de,(CGPNT)
	ld bc,FONT_THAI_END-FONT_THAI
	call LDIRVM
	ei
	; เปิดใช้งานอีกครั้งด้วยกลไกใหม่ (RST 30H / CALLF แทน trampoline เดิม -- ดู comment เต็มที่
	; KEYC_INSTALL ใน src/keyboard.asm) หลังปิดไปชั่วคราวตอนบั๊กข้อ 8 ยังไม่จบ
	; *** 9.19: กันติดตั้งซ้ำ -- ROM นี้สั่ง CALL THAION เองตอนบูตอยู่แล้ว ถ้าผู้ใช้สั่ง THAION ซ้ำ
	; installer จะสำรอง "hook ของเราเอง" ไว้เป็นค่าเดิม ทำให้ THAIOFF คืนค่ากลับเป็น hook ของเรา
	; (ถอดไม่ออก) -- นี่คือที่มาของ "H_KEYC opcode after thaioff" ที่อ่านผิดใน 9.17 -- ถ้า H_CHPUT
	; ชี้มาที่ PRINTHOOK อยู่แล้ว แปลว่าติดตั้งครบแล้ว ข้ามการติดตั้งทั้งชุด
	ld a,(H_CHPUT)
	cp RST30_OPCODE
	jr nz,.thaion_install
	ld hl,(H_CHPUT+2)
	ld de,PRINTHOOK
	or a
	sbc hl,de
	jr z,.thaion_done
.thaion_install:
	call KEYC_INSTALL
	; ติดตั้ง PRINTON compositing hook ด้วย (ต้องเรียก "หลัง" KEYC_INSTALL เสมอ เพราะใช้
	; MY_SLOT_ID ที่ KEYC_INSTALL คำนวณไว้ซ้ำ -- ดู comment เต็มที่ PRINTHOOK_INSTALL ใน
	; src/printon.asm) -- ติดตั้งไว้ตลอดที่ THAION ไม่ผูกกับ PRINT_MODE โดยตรง เพราะตัว
	; PRINTHOOK เองเช็ค PRINT_MODE ทุกครั้งอยู่แล้ว
	call PRINTHOOK_INSTALL
.thaion_done:
	ret

CMD_THAIOFF:
	pop hl
	push hl
	xor a
	ld (ix+THAI_MODE),a
	ld (ix+PRINT_MODE),a
	ld (ix+INPUT_MODE),a
	ld (ix+PLOCK_MODE),a
	; เปิด blinking-cursor กลับด้วย เผื่อ PRINTON ยังเปิดค้างอยู่ตอนสั่ง THAIOFF (ดู comment
	; เต็มที่ CURSOR_BLINK_FLAG ใน equates.asm)
	ld a,TRUE
	ld (CURSOR_BLINK_FLAG),a
	; *** ไม่เรียก INITXT อีกต่อไป (คำขอผู้ใช้: ไม่ต้องเคลียร์หน้าจอ) -- ดู comment เต็มด้านบน ***
	call KEYC_UNINSTALL
	call PRINTHOOK_UNINSTALL
	pop hl
	jp STMT_DONE

; --- stub สำหรับคำสั่งที่ยังไม่ implement (Phase 4) ------------------------
CMD_STUB:
	pop hl
	jp STMT_DONE
