; kwtables_data.asm -- 9.30: คำสั่ง BASIC ที่พิมพ์ด้วย GRAPH+A..Z (KW_TABLE_N) และ GRAPH+SHIFT+A..Z (KW_TABLE_S)
; ข้อความตรงตามตารางของ MSXTHA102 ($4F32/$4FF2) -- สตริงต่อกัน จบด้วย 0 แต่ละคำ ลำดับ A..Z
KW_TABLE_N:
	db "ASC(",0	; A
	db "BIN$(",0	; B
	db "CHR$(",0	; C
	db "DATA",0	; D
	db "ELSE",0	; E
	db "FOR",0	; F
	db "GOTO",0	; G
	db "HEX$(",0	; H
	db "IF",0	; I
	db "INPUT",0	; J
	db "KEY",0	; K
	db "LEFT$(",0	; L
	db "MID$(",0	; M
	db "NEXT",0	; N
	db "OPEN",0	; O
	db "POKE",0	; P
	db "SOUND",0	; Q
	db "READ",0	; R
	db "SCREEN",0	; S
	db "THEN",0	; T
	db "USR(",0	; U
	db "VPOKE",0	; V
	db "WIDTH",0	; W
	db "XOR",0	; X
	db "CIRCLE",0	; Y
	db "PAINT",0	; Z
KW_TABLE_S:
	db "AND",0	; A
	db "BASE(",0	; B
	db "CLS",0	; C
	db "DIM",0	; D
	db "PSET",0	; E
	db "FILES",0	; F
	db "GOSUB",0	; G
	db "PRESET",0	; H
	db "INKEY$",0	; I
	db "INT(",0	; J
	db "KILL",34,0	; K
	db "LINE",0	; L
	db "MAXFILES = ",0	; M
	db "NOT",0	; N
	db "OR",0	; O
	db "PEEK(",0	; P
	db "PLAY",0	; Q
	db "RETURN",0	; R
	db "SPRITE",0	; S
	db "TAB(",0	; T
	db "USING",0	; U
	db "VPEEK(",0	; V
	db "VAL(",0	; W
	db "LOCATE",0	; X
	db "BLOAD",0	; Y
	db "BSAVE",0	; Z
