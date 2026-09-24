; kwtables_data.asm -- 9.30: คำสั่ง BASIC ที่พิมพ์ด้วย GRAPH+A..Z (KW_TABLE_N) และ GRAPH+SHIFT+A..Z (KW_TABLE_S)
; ข้อความตรงตามตารางของ MSXTHA102 ($4F32/$4FF2) ลำดับ A..Z -- ตัวสุดท้ายของแต่ละคำตั้ง bit 7 (9.40 ประหยัดที่)
KW_TABLE_N:
	db $41,$53,$43,$A8	; A ASC(
	db $42,$49,$4E,$24,$A8	; B BIN$(
	db $43,$48,$52,$24,$A8	; C CHR$(
	db $44,$41,$54,$C1	; D DATA
	db $45,$4C,$53,$C5	; E ELSE
	db $46,$4F,$D2	; F FOR
	db $47,$4F,$54,$CF	; G GOTO
	db $48,$45,$58,$24,$A8	; H HEX$(
	db $49,$C6	; I IF
	db $49,$4E,$50,$55,$D4	; J INPUT
	db $4B,$45,$D9	; K KEY
	db $4C,$45,$46,$54,$24,$A8	; L LEFT$(
	db $4D,$49,$44,$24,$A8	; M MID$(
	db $4E,$45,$58,$D4	; N NEXT
	db $4F,$50,$45,$CE	; O OPEN
	db $50,$4F,$4B,$C5	; P POKE
	db $53,$4F,$55,$4E,$C4	; Q SOUND
	db $52,$45,$41,$C4	; R READ
	db $53,$43,$52,$45,$45,$CE	; S SCREEN
	db $54,$48,$45,$CE	; T THEN
	db $55,$53,$52,$A8	; U USR(
	db $56,$50,$4F,$4B,$C5	; V VPOKE
	db $57,$49,$44,$54,$C8	; W WIDTH
	db $58,$4F,$D2	; X XOR
	db $43,$49,$52,$43,$4C,$C5	; Y CIRCLE
	db $50,$41,$49,$4E,$D4	; Z PAINT
KW_TABLE_S:
	db $41,$4E,$C4	; A AND
	db $42,$41,$53,$45,$A8	; B BASE(
	db $43,$4C,$D3	; C CLS
	db $44,$49,$CD	; D DIM
	db $50,$53,$45,$D4	; E PSET
	db $46,$49,$4C,$45,$D3	; F FILES
	db $47,$4F,$53,$55,$C2	; G GOSUB
	db $50,$52,$45,$53,$45,$D4	; H PRESET
	db $49,$4E,$4B,$45,$59,$A4	; I INKEY$
	db $49,$4E,$54,$A8	; J INT(
	db $4B,$49,$4C,$4C,$A2	; K KILL"
	db $4C,$49,$4E,$C5	; L LINE
	db $4D,$41,$58,$46,$49,$4C,$45,$53,$20,$3D,$A0	; M MAXFILES = 
	db $4E,$4F,$D4	; N NOT
	db $4F,$D2	; O OR
	db $50,$45,$45,$4B,$A8	; P PEEK(
	db $50,$4C,$41,$D9	; Q PLAY
	db $52,$45,$54,$55,$52,$CE	; R RETURN
	db $53,$50,$52,$49,$54,$C5	; S SPRITE
	db $54,$41,$42,$A8	; T TAB(
	db $55,$53,$49,$4E,$C7	; U USING
	db $56,$50,$45,$45,$4B,$A8	; V VPEEK(
	db $56,$41,$4C,$A8	; W VAL(
	db $4C,$4F,$43,$41,$54,$C5	; X LOCATE
	db $42,$4C,$4F,$41,$C4	; Y BLOAD
	db $42,$53,$41,$56,$C5	; Z BSAVE
