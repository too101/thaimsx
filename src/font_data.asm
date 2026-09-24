; ==========================================================================
; font_data.asm -- ฟอนต์ไทย ดึงมาจาก MSXTHA102_original_16k.rom ตรง ๆ
; (255 glyph x 8 ไบต์ = 2040 ไบต์, code 0-254)
; ==========================================================================

FONT_THAI:
	incbin "assets/font_raw.bin"
FONT_THAI_END:
	db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; 9.33: glyph 255 (ทึบ) -- BIOS อ่านฟอนต์ 2048 ไบต์จาก CGPNT (SCREEN/GRPPRT)
