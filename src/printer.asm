; ==========================================================================
; printer.asm -- 9.36: พิมพ์ภาษาไทย 3 ระดับออกเครื่องพิมพ์ (ตามต้นฉบับ MSXTHA102 $5667-$5824, CALL LPRINT $4311)
;
; เครื่องพิมพ์ไทยของยุคนั้นมีชุดตัวอักษรเดียวกับจอ (รวม glyph ผสมสระบน+วรรณยุกต์ $83-$9D) แต่พิมพ์ได้ทีละแถว
; ต้นฉบับจึง (เฉพาะตอน PRINTON) พักตัวอักษรของบรรทัดไว้ แล้วตอนขึ้นบรรทัด (LF) ส่งออกเป็น 3 แถว: แถวสระบน/วรรณยุกต์,
; แถวพยัญชนะ, แถวสระล่าง -- แต่ละแถวตามด้วย LF CR และ CALL LPRINT ตั้งระยะบรรทัด 8/72" (ESC A 8) ให้ 3 แถวชิดกัน
; ตอนไม่ได้ PRINTON ส่งตรงทุกตัว (เครื่องพิมพ์จัดการเอง)
;
; ต่างจากต้นฉบับ: ต้นฉบับข้ามการส่งของ BIOS ด้วยการแก้ stack (ที่มาของบั๊ก MSX2+) -- ของเราคืน A = 0 (NUL ซึ่ง
; เครื่องพิมพ์ไม่พิมพ์อะไร) ให้ BIOS ส่งแทนตัวที่พักไว้ แล้วส่ง 3 แถวเองด้วย LPTOUT ตอนขึ้นบรรทัด
; ต้นฉบับเก็บ 3 แถวใน VRAM $1C00/$1C88/$1D10 -- ของเราพักตามลำดับที่ส่งมาใน PR_BUF (RAM ของเรา) แล้วแยก 3 แถวตอนส่ง
; ==========================================================================

; LPTO_BODY: A = ตัวที่ BIOS จะส่ง -> A = ตัวที่ให้ส่งจริง (0 = พักไว้แล้ว) -- คง BC/DE/HL
LPTO_BODY:
	push hl
	push de
	push bc
	ld c,a
	ld a,(ix+PR_BUSY)
	or a
	jr nz,.lp_pass                ; เราส่งเอง
	ld a,(ix+PRINT_MODE)
	or a
	jr z,.lp_pass                 ; ไม่ได้ PRINTON -- ส่งตรง
	ld a,c
	cp $1B
	jr nz,.lp_notesc
	call PR_FLUSH                 ; ESC: ส่งบรรทัดที่ค้างก่อน แล้ว ESC sequence ส่งตรง
	ld (ix+PR_ESC),$1B
	jr .lp_pass
.lp_notesc:
	ld a,(ix+PR_ESC)
	or a
	jr z,.lp_noesc
	ld a,c
	cp $20
	jr nc,.lp_pass                ; พารามิเตอร์ของ ESC -- ส่งตรง (ต้นฉบับ $5682-$5697)
	ld (ix+PR_ESC),0
	jr .lp_pass
.lp_noesc:
	ld a,c
	cp $0A
	jr z,.lp_lf
	cp $20
	jr c,.lp_pass                 ; รหัสควบคุมอื่น (CR, FF, ...) ส่งตรง
	call PR_ISMARK                ; Z = สระบน/ล่าง/วรรณยุกต์
	jr z,.lp_mark
	ld a,(ix+PR_WIDTH)
	or a
	jr nz,.lp_w
	ld a,80
.lp_w:
	ld b,a
	ld a,(ix+PR_COUNT)
	cp b
	call nc,PR_FLUSH              ; เต็มบรรทัด -- ขึ้นบรรทัดใหม่เอง
	inc (ix+PR_COUNT)
	jr .lp_store
.lp_mark:
	ld a,(ix+PR_COUNT)
	or a
	jr nz,.lp_store
	push bc                       ; ยังไม่มีตัวแถวกลาง -- ใส่ช่องว่างให้เกาะ
	ld c,' '
	call PR_PUT
	pop bc
	inc (ix+PR_COUNT)
.lp_store:
	call PR_PUT
	ld c,0                        ; ให้ BIOS ส่ง NUL แทน
.lp_pass:
	ld a,c
	pop bc
	pop de
	pop hl
	ret
.lp_lf:
	ld a,(ix+PR_LEN)
	or a
	jr z,.lp_empty
	call PR_FLUSH                 ; ส่ง 3 แถว (แต่ละแถวจบด้วย LF CR ของมันเอง)
	ld c,0
	jr .lp_pass
.lp_empty:
	ld a,$0A                      ; บรรทัดว่าง = 3 แถว (ต้นฉบับ $573C) -- ส่ง 2 ตัว + ให้ BIOS ส่งตัวที่ 3
	call PR_OUT
	ld a,$0A
	call PR_OUT
	jr .lp_pass

; PR_ISMARK: C = ตัว -> Z ถ้าเป็นเครื่องหมาย (ตาราง ML_DROP เดียวกับ MLSTR = ตาราง $55A0 ของต้นฉบับ) -- ทำลาย A,B,HL
PR_ISMARK:
	ld a,c
	cp $DA                        ; พินทุ: ต้นฉบับแปลงเป็น '.' แล้วนับเป็นช่องใหม่ในแถวกลาง ($56A4) ทำให้สระบนที่
	ret z                         ; ตามหลังไปเกาะผิดช่อง -- ของเราถือเป็นสระล่าง พิมพ์ '.' ที่แถวล่างใต้พยัญชนะ
	ld hl,ML_DROP
	ld b,ML_DROP_LEN
	ld a,c
.im_loop:
	cp (hl)
	ret z
	inc hl
	djnz .im_loop
	or $FF                        ; NZ
	ret

; PR_PUT: เก็บ C ต่อท้าย PR_BUF (เต็มแล้วส่งบรรทัดก่อน) -- ทำลาย A,HL,DE
PR_PUT:
	ld a,(ix+PR_LEN)
	cp PR_BUF_SIZE
	call nc,PR_FLUSH
	ld l,(ix+PR_LEN)
	ld h,0
	ld de,PR_BUF
	add hl,de
	call IX_HL
	ld (hl),c
	inc (ix+PR_LEN)
	ret

; PR_OUT: ส่ง A ไปเครื่องพิมพ์โดย hook ไม่ยุ่ง -- คง BC/DE/HL (carry = ยกเลิก)
PR_OUT:
	ld (ix+PR_BUSY),1
	push ix
	call LPTOUT
	pop ix
	ld (ix+PR_BUSY),0
	ret

; PR_FLUSH: ส่งบรรทัดที่พักไว้เป็น 3 แถว (บน / กลาง / ล่าง) แต่ละแถวจบ LF CR แล้วล้างบรรทัด -- คง BC
PR_FLUSH:
	ld a,(ix+PR_LEN)
	or a
	ret z
	push bc
	ld b,1                        ; แถวบน
	call PR_ROW
	jr c,.pf_done
	ld b,0                        ; แถวกลาง
	call PR_ROW
	jr c,.pf_done
	ld b,3                        ; แถวล่าง
	call PR_ROW
.pf_done:
	xor a
	ld (ix+PR_LEN),a
	ld (ix+PR_COUNT),a
	pop bc
	ret

; PR_ROW: B = แถว (0 กลาง / 1 บน / 3 ล่าง) -- เดิน PR_BUF: ตัวแถวกลางเปิดช่องใหม่ (ส่งช่องก่อนหน้า), เครื่องหมายเติม
; ช่องปัจจุบัน -- แถวบน: สระบน/ตัวอื่นทับ, วรรณยุกต์ผสมกับสระบนที่มีอยู่ (COMBINE_LOOKUP) -- จบแถวส่ง LF CR
; carry = ยกเลิก
PR_ROW:
	ld hl,PR_BUF
	call IX_HL
	ld e,(ix+PR_LEN)
	ld d,0                        ; D = มีช่องค้างอยู่
.pr_loop:
	ld a,(hl)
	inc hl
	push hl
	push de
	ld c,a
	push bc
	call PR_ISMARK
	pop bc
	jr z,.pr_mark
	ld a,d                        ; ตัวแถวกลาง: ส่งช่องก่อนหน้า
	or a
	jr z,.pr_first
	ld a,(ix+PR_CELL)
	call PR_OUT
	jr c,.pr_abort
.pr_first:
	pop de
	ld d,1
	push de
	ld a,b
	or a
	ld a,c                        ; แถวกลาง: ช่อง = ตัวนั้น
	jr z,.pr_setcell
	ld a,' '
.pr_setcell:
	ld (ix+PR_CELL),a
	jr .pr_next
.pr_mark:
	ld a,c
	call CLASSIFY_THAI_MARK       ; 1 บน / 2 วรรณยุกต์ / 3 ล่าง / 0 = glyph ผสม, $82, $FC, $FD
	or a
	jr nz,.pr_cls
	ld a,c                        ; ตามตารางต้นฉบับ: $82/$FD แถวล่าง ($5571), ที่เหลือแถวบน ($5575 / ทับ)
	cp $82
	ld a,3
	jr z,.pr_cls
	ld a,c
	cp $FD
	ld a,3
	jr z,.pr_cls
	ld a,1
.pr_cls:
	cp 2
	jr nz,.pr_notone
	ld a,b                        ; วรรณยุกต์ -- แถวบนเท่านั้น
	cp 1
	jr nz,.pr_next
	ld a,(ix+PR_CELL)
	cp ' '
	jr z,.pr_put
	push bc
	call COMBINE_LOOKUP           ; A = สระบนที่อยู่ในช่อง, C = วรรณยุกต์ -> A = glyph ผสม
	pop bc
	jr c,.pr_setcell
	ld a,c                        ; ผสมไม่ได้ -- วรรณยุกต์ทับ (ต้นฉบับ $5285)
	jr .pr_setcell
.pr_notone:
	cp b                          ; เครื่องหมายของแถวนี้?
	jr nz,.pr_next
.pr_put:
	ld a,c
	cp $DA
	jr nz,.pr_setcell
	ld a,'.'                      ; พินทุ -> '.' (เครื่องพิมพ์ไม่มีตัวนี้ -- ต้นฉบับแปลงเหมือนกัน)
	jr .pr_setcell
.pr_next:
	pop de
	pop hl
	dec e
	jr nz,.pr_loop
	ld a,d
	or a
	jr z,.pr_eol
	ld a,(ix+PR_CELL)
	call PR_OUT
	ret c
.pr_eol:
	ld a,$0A
	call PR_OUT
	ret c
	ld a,$0D
	jp PR_OUT
.pr_abort:
	pop de
	pop hl
	scf
	ret

; ---- CALL LPRINT / CALL LPRINT("nn") (ต้นฉบับ $4311) -- ตั้งความกว้างบรรทัด (ไม่ใส่ = 80, 1-135) แล้วส่งคำสั่ง
; ตั้งเครื่องพิมพ์: ESC l 0 (ขอบซ้าย 0), ESC Q n (ขอบขวา n), ESC A 8 (ระยะบรรทัด 8/72") และ LF CR --
; เครื่องพิมพ์ไม่พร้อมพิมพ์ข้อความ "Printer is not ready !" ก่อน (เหมือนต้นฉบับ) ----
CMD_LPRINT:
	pop hl
	push hl
	call LPTSTT
	jr nz,.cl_ready
	ld hl,PR_NOTREADY             ; ไม่พร้อม: แจ้งแล้วจบ (ต้นฉบับแจ้งแล้วส่งต่อ ซึ่งค้างรอจนกด CTRL+STOP)
.cl_msg:
	ld a,(hl)
	or a
	jr z,.cl_nr
	call CHPUT_IX
	inc hl
	jr .cl_msg
.cl_nr:
	pop hl
.cl_skip:
	ld a,(hl)                     ; ข้ามอาร์กิวเมนต์ที่เหลือของคำสั่ง
	or a
	jp z,STMT_DONE
	cp ':'
	jp z,STMT_DONE
	inc hl
	jr .cl_skip
.cl_ready:
	pop hl
	call SKIPSP
	ld c,80
	cp '('
	jr nz,.cl_set
	inc hl
	BCALL BAS_FRMEVL
	call SKIPSP
	cp ')'
	jp nz,SF_SNERR
	inc hl
	push hl
	BCALL BAS_GETYPR
	jp nz,SF_TMERR
	BCALL BAS_FRESTR              ; HL -> descriptor
	ld b,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld c,0
	ld a,b
	or a
	jp z,SF_FCERR
	cp 4
	jp nc,SF_FCERR
.cl_dig:
	ld a,(hl)
	sub '0'
	cp 10
	jp nc,SF_FCERR
	ld e,a
	ld a,c                        ; C = C*10 + ตัวเลข
	add a,a
	ld d,a
	add a,a
	add a,a
	add a,d
	add a,e
	ld c,a
	inc hl
	djnz .cl_dig
	pop hl
	ld a,c
	or a
	jp z,SF_FCERR
	cp $88
	jp nc,SF_FCERR
.cl_set:
	push hl
	ld (ix+PR_WIDTH),c
	ld hl,PR_INIT1
	ld b,5
	call PR_SEQ
	jr c,.cl_done
	ld a,(ix+PR_WIDTH)
	call PR_OUT
	jr c,.cl_done
	ld hl,PR_INIT2
	ld b,5
	call PR_SEQ
.cl_done:
	pop hl
	jp STMT_DONE

; PR_SEQ: ส่ง B ไบต์จาก HL -- carry = ยกเลิก
PR_SEQ:
	ld a,(hl)
	call PR_OUT
	ret c
	inc hl
	djnz PR_SEQ
	ret

PR_INIT1:
	db $1B,'l',0,$1B,'Q'
PR_INIT2:
	db $1B,'A',8,$0A,$0D
PR_NOTREADY:
	db 13,10,"Printer is not ready !",13,10,0
