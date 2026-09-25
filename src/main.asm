; ==========================================================================
; main.asm -- entry point ของ Thai BASIC cartridge ROM (rewrite จากศูนย์)
; ประกอบด้วย pasmo: pasmo src/main.asm build/thairom.rom build/thairom.sym
; ==========================================================================

	org $4000

	include "src/equates.asm"

; ---- ROM header (มาตรฐาน MSX cartridge) ----
	db "AB"
	dw INIT
	dw STATEMENT
	dw 0            ; DEVICE vector -- ไม่ใช้
	dw 0            ; TEXT vector -- ไม่ใช้

	include "src/workram.asm"
	include "src/init.asm"
	include "src/statement.asm"
	include "src/thaicmd.asm"
	include "src/keyboard.asm"
	include "src/printon.asm"
	include "src/printer.asm"
	include "src/font_data.asm"
	include "src/kwtables_data.asm"

CODE_END:
WORK_RAM    equ CODE_END      ; 9.43: บล็อกตัวแปรของรุ่น RAM (ต่อท้ายโค้ดใน page 1)
	IF DEFINED RAMVER
	IF WORK_RAM+WORK_SIZE > $8000
	.ERROR RAM image + work area exceed page 1
	ENDIF
	ENDIF

