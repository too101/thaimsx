; ==========================================================================
; equates.asm -- ค่าคงที่ทั้งหมด: BIOS jump table (official, portable),
;                system variable, และตำแหน่ง flag RAM ของเราเอง
; ==========================================================================
; กติกา: ไฟล์นี้เป็นจุดเดียวที่อนุญาตให้มี "raw address" ทั้งหมดในโปรเจกต์
;        ห้ามเขียน hex address ลอย ๆ ในไฟล์ logic อื่นเด็ดขาด -- ถ้าต้องใช้
;        address ใหม่ ให้มาประกาศเป็น EQU ที่นี่ก่อน พร้อมคอมเมนต์แหล่งที่มา

; ---- BIOS official jump table (0x0000-0x0141) ----
; ยืนยันแล้วว่า "JP xxxx" (opcode 0xC3) อยู่ที่ offset เดียวกันทั้ง
; MSX1_bios.rom และ MSX2_bios.rom (verify ด้วย disassembly ตรง ๆ ระหว่าง
; วางแผนโปรเจกต์นี้ -- ไม่ใช่แค่เชื่อเอกสารเฉย ๆ)
RDSLT       equ $000C
ENASLT      equ $0024
CALSLT      equ $001C
RDVRM       equ $004A
WRTVRM      equ $004D
SETRD       equ $0050
SETWRT      equ $0053
FILVRM      equ $0056
LDIRMV      equ $0059
LDIRVM      equ $005C
CHGMOD      equ $005F
CHGCLR      equ $0062
CLRSPR      equ $0069
INITXT      equ $006C
INIT32      equ $006F
INIGRP      equ $0072
INIMLT      equ $0075
CHGCAP      equ $0078   ; MSX2+ only, safe no-op on MSX1/2 impl (still JP entry)
CALPAT      equ $0084
CALATR      equ $0087
CALADR      equ $008A
CHGET       equ $009F
CHPUT       equ $00A2
GTSTCK      equ $00D5
GTTRIG      equ $00D8
SNSMAT      equ $0141
RSLREG      equ $0138
NEWCARD_UNUSED equ 0    ; placeholder, unused

; ---- Hook table (H.xxx) -- มาตรฐาน, portable ทุก generation ----
; H.CHGE / H.KEYC ยืนยันแล้วว่าเป็น address เดียวกันทั้ง MSX1/MSX2/MSX2+ (ตรวจสอบ
; ระหว่างวิเคราะห์ ROM ต้นฉบับก่อนหน้าโปรเจกต์นี้ -- ดู MSXTHA102_analysis_TH.md
; section 2) เป็นกลไก "H.xxx hook table" มาตรฐานของ MSX BIOS เอง ไม่ใช่ internal
; address จึง portable โดยธรรมชาติ
H_CHGE      equ $FDC2
H_KEYC      equ $FDCC
H_READ      equ $FF07   ; 9.22: ยืนยันจาก disassembly -- BASIC เรียกก่อนพิมพ์ "Ok" ($4128 ทั้ง MSX1/2/2+)
                        ; (ค่าเดิม $FE01 ผิด แต่ไม่เคยถูกใช้)
; H_CHPUT: พบจากการ disassemble CHPUT ตัวจริงของ MSX1_bios.rom (0x08BC-0x08DE) ตรง ๆ ระหว่างทำ
; PRINTON (ดู printon_algorithm_report.md + SPEC_TH.md section 5 ที่อัปเดตแล้ว) -- CHPUT ตัวจริง
; (ที่ jump table CHPUT=$00A2 กระโดดไปหา) ทำ "CALL $FDA4" เป็นก้าวแรกเสมอ ก่อนจะวาดตัวอักษรลง
; name table ด้วยตัวเอง -- นี่คือ H.xxx hook slot ตระกูลเดียวกับ H_CHGE/H_KEYC ด้านบน (5 ไบต์,
; รูปแบบ RST 30H/CALLF มาตรฐานเดียวกันทุกประการ) ยืนยัน calling-context เดียวกันทั้ง MSX1
; (0x08C0) และ MSX2/MSX2+ (0x091D) จาก disassembly ตรง ๆ ของทั้งสอง BIOS
H_CHPUT     equ $FDA4
; NAMPNT: base ของ name table ปัจจุบันใน VRAM (documented system variable, 2 ไบต์) -- ยืนยันค่า
; จริง = 0x0000 หลัง cold boot ปกติผ่าน openMSX (probe_nampnt.tcl)
NAMPNT      equ $F922
; CURSOR_BLINK_FLAG (0xFCA9): พบระหว่าง disassemble CHPUT จริง ($08C8: "LD A,(0xFCA9);AND A;
; RET Z") -- ถ้า flag นี้ไม่เป็นศูนย์ BIOS จะวาด "cursor block" ทับตำแหน่ง CSRY/CSRX ปัจจุบันซ้ำ
; ๆ (ผ่าน WRITE_CHAR โดยตรง ไม่ผ่าน CHPUT/H_CHPUT เลย) เป็นกลไก blinking-cursor มาตรฐาน --
; PRINTON ต้องปิดตัวนี้ระหว่างเปิดใช้งาน เพราะกลไกยักย้าย CSRY ชั่วคราวของ PRINTHOOK (ดู
; src/printon.asm) ทิ้ง CSRY ไว้ "ผิดตำแหน่งชั่วคราว" ระหว่าง 2 การเรียก hook ติดกัน -- ถ้า blink
; ยิงมาระหว่างนั้นจะไปวาดทับตัวอักษรที่เพิ่งซ้อนไว้เสียหาย (ยืนยันจริงด้วย breakpoint -- ดู
; comment เต็มที่ PRINTHOOK)
CURSOR_BLINK_FLAG equ $FCA9

; ---- System variables ที่มีเอกสารรองรับ (documented, portable) ----
; *** CGPNT แก้ที่อยู่แล้ว (บั๊กจริงที่เจอจากการทดสอบบน real MSX1 BIOS ผ่าน openMSX
; พิมพ์ "call thaion" จริงแล้วจอเพี้ยนทั้งจอ -- ตรงกับที่ผู้ใช้รายงานจาก blueMSX เป๊ะ)
; ค่าเดิม $F91F ผิด (อ่านได้ค่าขยะ 0xBF00 ทำให้ LDIRVM เขียนฟอนต์ทับ VRAM ผิดตำแหน่ง
; จน wrap ไปทับ name table ที่ VRAM 0x0000 -- นี่คือสาเหตุจอเพี้ยน) ยืนยันที่อยู่ที่ถูก
; ต้องด้วยการหา byte pattern ของฟอนต์ smiley (code 1, "3c42a581a599423c") ใน VRAM จริง
; หลัง boot MSX1 ผ่าน openMSX (เจอที่ VRAM 0x0808 = pattern table + 1*8 ดังนั้น pattern
; table base จริง = 0x0800) แล้วไล่หาว่า byte คู่ไหนใน RAM เก็บค่า 0x0800 พบที่ 0xF924
; (low) / 0xF925 (high) พอดี -- ไม่ใช่ 0xF91F ตามที่เข้าใจผิดไว้แต่แรก (ดู
; SPEC_TH.md section 9.7 สำหรับรายละเอียดเต็ม)
CGPNT       equ $F924   ; pattern-generator table base pointer (2 ไบต์) -- ยืนยันแล้วบน MSX1 จริง
EXPTBL      equ $FCC1   ; slot ของ BIOS หลัก, byte แรกใช้เช็ค generation ผ่าน RAM ไม่ได้ตรง ๆ
                        ; -- ใช้ MSXVER ด้านล่างแทนสำหรับเช็ค generation
MSXVER      equ $002D   ; *** เป็นตำแหน่งใน ROM (jump table area) ไม่ใช่ RAM -- อ่านได้ตรง ๆ
                        ; ค่า: 0=MSX1, 1=MSX2, 2=MSX2+, 3=turboR (ยืนยันแล้วจาก MSX1_bios.rom=0,
                        ; MSX2_bios.rom=1 ระหว่างวางแผนโปรเจกต์นี้)
; CSRY/CSRX: ยืนยันแล้วผ่าน emulator จริง (เรียก INITXT แล้วเรียก CHPUT ซ้ำหลายครั้ง
; บน MSX1 BIOS จริง) -- CSRY คงที่, CSRX เพิ่มทีละ 1 ต่อการพิมพ์ 1 ตัวอักษรตามที่ควร
; (ตอนแรกเข้าใจผิดว่าผิดปกติเพราะอ่านรวมเป็น word เดียว ดู SPEC_TH.md section 9.6
; สำหรับรายละเอียด false-alarm นี้)
CSRY        equ $F3DC
CSRX        equ $F3DD
; LINLEN: *** อัปเดต (PRINTON investigation) -- disassemble CALC_ADDR ($0BF2 ของ MSX1 BIOS)
; ตรง ๆ แล้วยืนยันว่า LINLEN **ไม่ได้ใช้เลย** ในการคำนวณ VRAM address ของ name table ตอน
; SCRMOD=0 (โหมด SCREEN 0 ที่โปรเจกต์นี้ใช้ตลอด) -- สูตรจริงคือ (CSRY-1)*40+CSRX ล้วน ๆ (ดูค่า
; คงที่ 40 ที่มาจาก ADD HL,HL ซ้ำ ไม่ได้มาจาก LINLEN) ส่วน LINLEN เข้ามาเกี่ยวก็ต่อเมื่อ SCRMOD!=0
; (โหมดกราฟิก) เท่านั้น ค่า 37 ที่เคยวัดได้จริง (ดู probe_nampnt_out.txt) จึงไม่ใช่ความผิดปกติ --
; เป็นค่าที่ BASIC ใช้ภายในเพื่อ word-wrap เท่านั้น (40 คอลัมน์ - 3) ไม่เกี่ยวกับ VRAM addressing
; เลย ยืนยันด้วย disassembly จริง ไม่ใช่การเดา (แก้ไขข้อสงสัยเดิมใน SPEC_TH.md section 9.6)
LINLEN      equ $F3B0
SCRMOD      equ $FCAF

; ---- Flag RAM ของเราเอง ----
; *** บั๊กจริงข้อ 12 (แก้แล้ว) -- $FCAC/$FCAD ชนกับตัวแปรระบบจริงของ BIOS ***
; เดิมเลือกใช้ตำแหน่งเดียวกับที่ MSXTHA102.ROM ต้นฉบับใช้ (0xFCAC/0xFCAD) เพราะมีหลักฐานเชิงประจักษ์
; จากการทดสอบ r3-r6 ตลอดโปรเจกต์นี้ (หลายสิบรอบ boot + พิมพ์จริงผ่าน emulator บน MSX1/MSX2) ว่า
; ตำแหน่งเหล่านี้ไม่เคยเป็นสาเหตุของปัญหาเลย -- แต่หลักฐานนั้นไม่ครอบคลุมทุกกรณี: ผู้ใช้รายงานว่า
; "กด BS แล้วกลับเป็นอังกฤษ" หลังพิมพ์ไทยได้แล้ว (บั๊กข้อ 9/10/11 แก้หมดแล้ว) สืบด้วย openMSX
; watchpoint (write_mem 0xFCAC) พบว่า **มีการเขียนทับ $FCAC จริงหลังกด BS** จาก PC=$4188 ซึ่งเป็น
; แค่ "ที่อยู่เดียวกันในหน่วยความจำเชิงตรรกะ page 1" ไม่ใช่โค้ดของเราเอง (โค้ดเราที่ $4188 คือ
; "BIT 2,A" ธรรมดา ไม่มีการเขียนหน่วยความจำเลย) -- ยืนยันว่าเป็นโค้ดของ BASIC/system ROM เอง (คนละ
; slot กับ cartridge นี้ แต่บังเอิญ "ที่อยู่ page 1" เดียวกัน เหมือนอาการเดียวกับบั๊กจริงข้อ 7 ที่เคย
; เจอ BASIC ROM มีโค้ดจริงอยู่ที่ $4169 พอดี) ที่ดำเนินการ default handling ของปุ่ม BS (ผ่าน BIOS's
; post-hook dispatch table ตามสัญญาของ RST 30H/CALLF -- ดู comment เต็มที่ KEYC_INSTALL) แล้วเขียน
; ทับ $FCAC เป็นผลข้างเคียงของฟังก์ชันจริงของ BIOS เอง (แม้แต่ต้นฉบับ MSXTHA102 เองก็ใช้ตำแหน่งนี้ --
; ยืนยันแล้วว่า "บังเอิญ" ไม่ใช่ปลอดภัยจริง เพียงแต่ต้นฉบับใช้กลไก stack-hijack ที่ไม่เคยปล่อยให้
; BIOS's default dispatch ทำงานถึงจุดที่เขียนทับตำแหน่งนี้ได้เลย จึงไม่เคยเจอปัญหานี้)
;
; แก้โดยย้าย INPUT_MODE/THAI_MODE ไปใช้ RAM ย่านเดียวกับ PREV_KEYC/MY_SLOT_ID ($FD0B-$FD10) แทน --
; ย่านนี้ผ่านการทดสอบจริงหนักหน่วงตลอด Phase 3 ทั้งหมด (รวมถึง end-to-end ผ่าน BIOS จริงใน
; test_phase3_e2e_biosreal.py) โดยไม่เคยพบการชนกับตัวแปรระบบเลย ($FD11-$FD12 อยู่ในช่องว่างระหว่าง
; MY_SLOT_ID ($FD10) กับ PROCNM ($FD89) ที่ยังไม่มีใครใช้)
; ---- 9.27: ตัวแปรทั้งหมดย้ายไปอยู่ใน "บล็อกส่วนตัว" ที่ INIT จองด้วยการลด HIMEM (วิธีมาตรฐานของ
; cartridge) -- pointer ของบล็อกเก็บใน SLTWRK ช่องของ slot เราเอง (page 1) ตามข้อกำหนด MSX
; ค่า equ ด้านล่างจึงเป็น "offset ในบล็อก" (อ้างผ่าน IX เสมอ: ld a,(ix+THAI_MODE)) -- ตัวเลข $FDxx
; ที่เห็นคือ layout เดิม ใช้แค่คำนวณ offset (ลบด้วย SLTWRK_OLD) ไม่ได้เขียน RAM ตรงนั้นอีกแล้ว
SLTWRK_OLD  equ $FD09
SLTWRK      equ $FD09   ; SLTWRK ของ BIOS: 2 ไบต์ต่อ (slot หลัก, slot รอง, page)
MAXFIL      equ $F85F   ; จำนวนไฟล์สูงสุด (MAXFILES) -- ใช้ใน FIX_FILES (workram.asm)
FILTAB      equ $F860   ; ตาราง pointer ไป FCB ของแต่ละไฟล์
NULBUF      equ $F862   ; buffer ของไฟล์ #0
MEMSIZ      equ $F672   ; ขอบบนของ string space
STKTOP      equ $F674   ; ขอบบนของ stack BASIC
FRETOP      equ $F69B   ; ตำแหน่งว่างถัดไปใน string space (BASIC ตั้ง = MEMSIZ ตอน NEW/CLEAR)
DOS_AREA    equ $F1C9   ; 9.29: ต้นพื้นที่ระบบ DOS ($F1C9-$F37F) ที่ disk ROM ตัวหลักใช้ตายตัว
SAVSTK      equ $F6B1   ; stack ที่ BASIC จำไว้ (STKTOP-2)
CURLIN      equ $F41C   ; 9.30: เลขบรรทัดที่กำลังทำงาน ($FFFF = direct mode)
HIMEM       equ $FC4A   ; ขอบบนของ RAM ที่ BASIC ใช้ -- ลดลงเพื่อจองพื้นที่ของเราเอง
WORK_SIZE   equ $FD5E-SLTWRK_OLD
INPUT_MODE  equ $FD11-SLTWRK_OLD   ; INPUTON/INPUTOFF flag (ประกอบอักษรตอนพิมพ์) -- ย้ายจาก $FCAC (บั๊กข้อ 12)
THAI_MODE   equ $FD12-SLTWRK_OLD   ; THAION/THAIOFF สวิตช์ใหญ่ -- ย้ายจาก $FCAD (บั๊กข้อ 12)
PRINT_MODE  equ $FD09-SLTWRK_OLD   ; PRINTON/PRINTOFF flag (แสดงผล 3 ระดับ) -- ยังไม่พบปัญหา คงตำแหน่งเดิมไว้
PLOCK_MODE  equ $FD0A-SLTWRK_OLD   ; PLOCKON/PLOCKOFF flag -- ยังไม่พบปัญหา คงตำแหน่งเดิมไว้
SHIFT_STATE equ $FBEB   ; *** read-only, BIOS ดูแลเอง (ยืนยันจากต้นฉบับ) -- ห้ามเขียนทับ
PROCNM      equ $FD89   ; buffer ที่ BASIC เก็บชื่อ keyword/CALL ที่ไม่รู้จัก (ยืนยันจาก
                        ; การ disassemble STATEMENT vector ของ ROM ต้นฉบับโดยตรงระหว่าง
                        ; วางแผนโปรเจกต์นี้ -- ไม่ใช่ internal BIOS address แต่เป็นกลไก
                        ; extended-statement มาตรฐานของ BASIC interpreter เอง)
PREV_KEYC   equ $FD0B-SLTWRK_OLD   ; *** บั๊กจริงข้อ 8 ยังไม่จบ + ดู "การออกแบบใหม่ (RST 30H)" ด้านล่าง ***
                        ; 5 ไบต์ (เพิ่มจาก 3 ไบต์เดิม -- ดูเหตุผลด้านล่าง): สำรองเนื้อ hook slot
                        ; เดิมทั้ง 5 ไบต์ของ H_KEYC ไว้ก่อนติดตั้ง hook ของเรา (Phase 3, ดู
                        ; src/keyboard.asm) เพื่อคืนกลับได้ตอน THAIOFF -- อยู่ติดกับ
                        ; PRINT_MODE/PLOCK_MODE ($FD09/$FD0A) ในย่าน RAM เดียวกันที่ทดสอบจริงมา
                        ; แล้วหลายรอบว่าไม่ชนกับตัวแปรระบบ
;
; ---- PRINTON hook state (src/printon.asm) -- ใช้ย่านว่างเดียวกันระหว่าง MY_SLOT_ID ($FD10)
; กับ PROCNM ($FD89) ที่ยืนยันแล้วว่าไม่มีใครใช้ (ดู comment PREV_KEYC ด้านบน) -- ต่อจาก
; INPUT_MODE/THAI_MODE ($FD11/$FD12) โดยตรง *** ยังไม่ผ่านการทดสอบ boot เต็มระบบหนักหน่วงเท่า
; $FD0B-$FD12 เดิม (เพิ่งเพิ่มระหว่าง PRINTON implementation) -- ต้องเฝ้าดูใน regression test
PREV_CHPUT   equ $FD13-SLTWRK_OLD  ; 5 ไบต์ ($FD13-$FD17): สำรองเนื้อ hook slot เดิมของ H_CHPUT (รูปแบบ
                        ; เดียวกับ PREV_KEYC ทุกประการ) ก่อนติดตั้ง PRINTHOOK ตอน THAION
PRINT_ROW    equ $FD18-SLTWRK_OLD  ; 1 ไบต์: "เงา" ของค่า CSRY ที่ถูกต้องจริง (ไม่ถูกยักย้ายชั่วคราว) --
                        ; ใช้แก้ปัญหาที่ CHPUT ตัวจริงของ BIOS ไม่มีสัญญาณ "ฉันจัดการแล้ว ข้าม
                        ; การวาด default" ให้ hook เรียกใช้เลย (ดู comment เต็มที่ PRINTHOOK ใน
                        ; src/printon.asm และ SPEC_TH.md section 5 สำหรับที่มาของ mechanism นี้)
PRINT_REDIRECT equ $FD19-SLTWRK_OLD ; 1 ไบต์ flag: 0=ครั้งก่อนไม่ได้ยักย้าย CSRY (ปกติ), TRUE=ครั้งก่อน
                        ; ยักย้าย CSRY ชั่วคราวเพื่อวาดตัวประกอบ (สระ/วรรณยุกต์) -- ต้องคืนค่า
                        ; CSRY จาก PRINT_ROW ก่อนประมวลผลตัวอักษรถัดไป
;
; ---- PRINTON "combine glyph" deferred-fix state (เพิ่มหลังผู้ใช้แก้ไข: สระบน+วรรณยุกต์ต้อง
; "ผสม" เป็น glyph เดียว (โค้ด 0x83-0x9D ในฟอนต์ ดู COMBINE_TABLE ใน printon.asm) วาดทับตำแหน่ง
; สระบนเดิมที่แถว-1 -- ไม่ใช่ซ้อนแถว-2 แยกต่างหากแบบที่เข้าใจผิดไว้รอบแรก) -- ปัญหา: hook ไม่มีทาง
; "แทนที่" ตัวอักษรที่ BIOS จะวาดเองได้เลย (ดู comment ใหญ่ที่ PRINTHOOK) มีแต่ยักย้ายตำแหน่งได้ --
; จึงปล่อยให้ BIOS วาดวรรณยุกต์ตัวเปล่าทับตำแหน่งแถว-1 ไปก่อน (ผิดชั่วคราว 1 จังหวะ) แล้ว "แก้ทับ"
; ด้วย WRTVRM ตรง ๆ ตอนต้นของการเรียก PRINTHOOK **ครั้งถัดไป** (ก่อนประมวลผลตัวอักษรใหม่ใด ๆ เลย)
; -- แพทเทิร์นเดียวกับ PRINT_ROW/PRINT_REDIRECT ด้านบนทุกประการ เพียงแต่แก้ "เนื้อ VRAM" แทน
; "ตำแหน่งเคอร์เซอร์" -- ข้อจำกัดที่ทราบ: ถ้าผู้ใช้หยุดพิมพ์ทันทีหลังวรรณยุกต์ที่ต้องผสม (ไม่กดอะไร
; ต่อเลย รวมถึง Enter) ช่องนั้นจะค้างแสดงวรรณยุกต์เปล่า (ยังไม่ผสม) จนกว่าจะมี CHPUT ครั้งถัดไป
PRINT_COMBINE_PENDING equ $FD1A-SLTWRK_OLD ; 1 ไบต์ flag: TRUE = มีการแก้ VRAM ค้างอยู่ที่ต้องทำตอนเรียกครั้งถัดไป
PRINT_COMBINE_ROW     equ $FD1B-SLTWRK_OLD ; 1 ไบต์: แถว (1-based เหมือน CSRY) ที่ต้องแก้
PRINT_COMBINE_COL     equ $FD1C-SLTWRK_OLD ; 1 ไบต์: คอลัมน์ (0-based เหมือน CSRX) ที่ต้องแก้
PRINT_COMBINE_CODE    equ $FD1D-SLTWRK_OLD ; 1 ไบต์: โค้ด glyph ที่ผสมแล้ว (0x83-0x9D) ที่ต้องเขียนทับ
;
; ---- PRINTON "undo combine on backspace" state -- ผู้ใช้ยืนยัน: "ถ้าลบวรรณยุกต์ออกต้อง
; กลับมาวาดสระบน" -- ถ้าตัวล่าสุดที่พิมพ์คือวรรณยุกต์ที่ถูกผสมเข้ากับสระบน (ดู PRINT_COMBINE_*
; ด้านบน) แล้วตัวถัดไปที่พิมพ์คือ Backspace ($08) ทันที ต้องเขียน VRAM ทับกลับเป็นสระบนเปล่า ๆ
; (ไม่ใช่ glyph ผสม) -- valid แค่ "1 ครั้งถัดไป" เท่านั้น (ถูกเคลียร์ทิ้งทันทีถ้าตัวถัดไปที่พิมพ์
; ไม่ใช่ BS) ดู comment เต็มที่ PRINTHOOK ขั้น 1.7 ใน src/printon.asm
PRINT_LAST_MARK_VALID equ $FD1E-SLTWRK_OLD ; 1 ไบต์ flag: TRUE = มีการผสมที่เพิ่งเกิด ยกเลิกได้ด้วย BS ครั้งถัดไป
PRINT_LAST_MARK_ROW   equ $FD1F-SLTWRK_OLD ; 1 ไบต์: แถว (1-based) ที่จะคืนค่า
PRINT_LAST_MARK_COL   equ $FD20-SLTWRK_OLD ; 1 ไบต์: คอลัมน์ (0-based) ที่จะคืนค่า
PRINT_LAST_MARK_VOWEL equ $FD21-SLTWRK_OLD ; 1 ไบต์: โค้ดสระบนเดิม (ก่อนผสม) ที่จะเขียนทับกลับคืน
;
; ---- PRINTON + ตัวแก้ไขบรรทัดของ BASIC (9.19) -- ดู comment เต็มที่หัวข้อ "INLIN_REBUILD" ใน
; src/printon.asm: ตอนกด Enter BIOS อ่านบรรทัดกลับจาก VRAM "เฉพาะแถวที่ cursor อยู่" สระบน/ล่าง/
; วรรณยุกต์ที่ PRINTON วาดไว้แถวบน/ล่างจึงหายจากโปรแกรม -- ต้องดักแล้วอ่านแถวบน/ล่างรวมกลับเข้า BUF
; *** หมายเหตุ RAM: ย่าน $FD09-$FD88 คือ SLTWRK ของ BIOS (2 ไบต์ต่อ slot/page) -- โปรเจกต์นี้ใช้ย่าน
; นี้มาตั้งแต่ต้น (ทดสอบแล้วว่าไม่มีใครใช้บน config ที่ทดสอบ) ตัวแปรชุดใหม่นี้ต่อท้ายจากเดิม
; ($FD22-$FD33) ซึ่งครอบคลุม SLTWRK ของ slot 0-3 และ slot 1-0 -- ถ้าเครื่องจริงมี ROM อื่น (เช่น
; disk interface) ใน slot 1-0 อาจชนได้ ควรย้ายไปจองผ่าน HIMEM ในอนาคตถ้าเจอปัญหา
PREV_CHGE      equ $FD22-SLTWRK_OLD  ; 5 ไบต์: สำรอง hook slot เดิมของ H_CHGE ($FD22-$FD26)
PREV_PINL      equ $FD27-SLTWRK_OLD  ; 5 ไบต์: สำรอง hook slot เดิมของ H_PINL ($FD27-$FD2B)
PREV_INLI      equ $FD2C-SLTWRK_OLD  ; 5 ไบต์: สำรอง hook slot เดิมของ H_INLI ($FD2C-$FD30)
INLIN_ACTIVE   equ $FD31-SLTWRK_OLD  ; 1 ไบต์ flag: TRUE = BIOS กำลังรับบรรทัด (PINLIN/INLIN/QINLIN) ขณะ PRINTON
                          ; เปิด -- LF ตัวถัดไปที่ผ่าน PRINTHOOK คือ LF ที่ BIOS พิมพ์หลังอ่านบรรทัดเข้า
                          ; BUF เสร็จ (ยืนยันจาก disassembly: MSX1/MSX2/MSX2+ ที่ $24B9 เหมือนกันทั้ง 3 รุ่น)
RB_ROW         equ $FD32-SLTWRK_OLD  ; 1 ไบต์ scratch ของ INLIN_REBUILD: แถว (1-based) ของบรรทัดที่อ่าน
RB_COL         equ $FD33-SLTWRK_OLD  ; 1 ไบต์ scratch ของ INLIN_REBUILD: คอลัมน์ (1-based) ที่กำลังอ่าน
PRINT_IN_LF    equ $FD34-SLTWRK_OLD  ; 1 ไบต์ flag (9.20): PRINTHOOK กำลังเรียก CHPUT(LF) ซ้อนเองเพื่อ scroll -- ตัวซ้อนปล่อยผ่าน
; ---- 9.20: โค้ดส่วนตัวที่ KEYC_HOOK ดันเข้าคิวแทน BS/DEL ระหว่างรับบรรทัดขณะ PRINTON (ดู THAI_BS ใน
; printon.asm) -- INLIN ส่ง control code ที่ไม่อยู่ในตาราง dispatch ของมันไป CHPUT ตรง ๆ ($2428)
; และ CHPUT เองไม่ทำอะไรกับโค้ดเหล่านี้ PRINTHOOK จึงได้จัดการ BS/DEL แบบรู้จักแถวสระบน/ล่างเอง
; ---- 9.21: cursor แยกสถานะไทย/อังกฤษ (ดู CUR_BUILD ใน printon.asm) ----
IN_CHGET       equ $FD35-SLTWRK_OLD  ; 1 ไบต์: CHGE_HOOK ตั้ง = กำลังจะวาด cursor รอคีย์ใน CHGET
CUR_WAITING    equ $FD36-SLTWRK_OLD  ; 1 ไบต์: cursor ของ CHGET แสดงอยู่ (ระหว่าง DSPC..ERAC) -- วาดใหม่ตอนกดสลับภาษาได้
PREV_DSPC      equ $FD39-SLTWRK_OLD  ; 5 ไบต์ ($FD39-$FD3D)
PREV_ERAC      equ $FD3E-SLTWRK_OLD  ; 5 ไบต์ ($FD3E-$FD42)
H_DSPC         equ $FDA9  ; hook ต้น routine แสดง cursor (MSX1 $09E6, MSX2/2+ $0A43 -- logic เหมือนกัน)
H_ERAC         equ $FDAE  ; hook ต้น routine ลบ cursor (MSX1 $0A33, MSX2/2+ $0A90)
H_TIMI         equ $FD9F  ; hook ทุก VDP interrupt (1/60 หรือ 1/50 วินาที) -- A = VDP status ต้องส่งต่อ
BLINK_FRAMES   equ 20     ; สลับติด/ดับทุก 20 frame
CURSAV         equ $FBCC  ; ตัวอักษรใต้ cursor ที่ BIOS เก็บไว้เขียนคืนตอนลบ cursor
CSTYLE         equ $FCAA  ; รูป cursor ของ BIOS: 0 = ทึบ 8 แถว, อื่น = ขีดล่าง 3 แถว (โหมด INS)
FNKSWI         equ $FBCD  ; สถานะ SHIFT ตอนวาดป้าย function key ล่าสุด (BIOS วาดป้ายใหม่ถ้าต่างจากตอนนี้)
PREV_READ      equ $FD43-SLTWRK_OLD  ; 5 ไบต์ ($FD43-$FD47): hook H.READ เดิม ก่อนติดตั้ง BOOT_HOOK (9.22)
; ---- 9.25: บรรทัดยาวต่อแถว (continuation) ขณะ PRINTON -- ดู WRAP_FIX ใน printon.asm ----
WRAP_PENDING   equ $FD48-SLTWRK_OLD  ; 1 ไบต์: เพิ่งพิมพ์ตัวปกติลงคอลัมน์สุดท้าย -> BIOS จะตัดขึ้นแถวถัดไป (แถว+1)
GHOST_PENDING  equ $FD49-SLTWRK_OLD  ; 1 ไบต์: วาดสระของตัวคอลัมน์สุดท้ายเอง แล้วปล่อย BIOS วาดตัวหลอกที่ cursor
GHOST_ROW      equ $FD4A-SLTWRK_OLD
GHOST_COL      equ $FD4B-SLTWRK_OLD
GHOST_CHAR     equ $FD4C-SLTWRK_OLD  ; ตัวเดิมในช่องที่ BIOS วาดตัวหลอกทับ -- เขียนคืนตอน resync
MARK_ROW       equ $FD4D-SLTWRK_OLD  ; แถวของตัวที่สระ/วรรณยุกต์จะไปเกาะ (อาจเป็นแถวก่อนหน้าถ้าเพิ่งต่อแถว)
DC_ROW         equ $FD4E-SLTWRK_OLD  ; แถวที่ DELCOL/INSCOL กำลังทำงาน
RB_M           equ $FD4F-SLTWRK_OLD  ; แถวที่กด Enter (INLIN_REBUILD)
IC_CARRY       equ $FD51-SLTWRK_OLD  ; 3 ไบต์ ($FD51-$FD53): ตัวที่ล้นจากคอลัมน์สุดท้ายตอนแทรก (บน/กลาง/ล่าง)
LT_TMP         equ $FD54-SLTWRK_OLD  ; 1 ไบต์ scratch ของ LT_SET
BLINK_CNT      equ $FD55-SLTWRK_OLD  ; 9.26: ตัวนับ frame ของการกระพริบ cursor ภาษาไทย
BLINK_OFF      equ $FD56-SLTWRK_OLD  ; 9.26: 1 = ตอนนี้ glyph 255 เป็นตัวปกติ (cursor "ดับ")
SF_KIND        equ $FD5D-SLTWRK_OLD  ; 9.30: ชนิดของ ANSTR/TNSTR/MLSTR ที่กำลังทำ
BOOT_SKIP      equ $FD5C-SLTWRK_OLD  ; 9.30: CODE ค้างตอน INIT -> ไม่เปิดระบบไทยตอนบูต
PREV_TIMI      equ $FD57-SLTWRK_OLD  ; 9.26: 5 ไบต์ ($FD57-$FD5B) hook H.TIMI เดิม -- ต้องเรียกต่อเสมอ (disk ROM ใช้)
THAI_INS       equ $FD50-SLTWRK_OLD  ; โหมด INS ของเราเอง ขณะ PRINTON (ดู CHGE_HOOK) -- BIOS เห็น INSFLG=0 ตลอด
; LINTTB marker: ค่าไม่เป็น 0 (BIOS ถือว่า "ไม่ต่อแถว") แต่เราใช้บอกว่าแถวข้อความนี้ต่อไป/ต่อมาจากแถว
; ข้อความที่ห่าง 3 แถว (ข้ามแถวสระล่าง+สระบน) -- ค่าใน LINTTB เลื่อนตามเวลา BIOS scroll จอเอง
LT_MARK        equ $50
LT_DOWN        equ 1      ; แถวนี้ต่อไปที่ แถว+3
LT_UP          equ 2      ; แถวนี้ต่อมาจาก แถว-3
SELECT_CODE    equ $18    ; 9.30: รหัสที่ปุ่ม SELECT ให้ (INLIN ส่งต่อไป CHPUT)
THAI_BS_CODE   equ $10
THAI_DEL_CODE  equ $11
KEY_BS_SCAN    equ $3D    ; matrix แถว 7 bit 5
KEY_DEL_SCAN   equ $43    ; matrix แถว 8 bit 3
ESCCNT         equ $FCA7  ; ตัวนับ ESC sequence ของ CHPUT (ไม่เป็น 0 = กำลังรับพารามิเตอร์ ESC)
INSFLG         equ $FCA8  ; โหมด insert ของตัวแก้ไขบรรทัด (documented)
CNSDFG         equ $F3DE  ; 0 = ไม่แสดง function key, $FF = แสดง (แถวล่างสุดใช้ไม่ได้)

; ---- hook / system variable ที่ใช้เพิ่ม (documented ทั้งหมด -- MSX Technical Handbook) ----
H_PINL      equ $FDDB   ; hook ต้น PINLIN (บรรทัดคำสั่ง/โปรแกรมใน direct mode)
H_INLI      equ $FDE5   ; hook ต้น INLIN (LINE INPUT, และ QINLIN/INPUT ก็ไหลเข้ามาที่นี่)
LINTTB      equ $FBB2   ; 24 ไบต์: 0 = แถวนี้ต่อเนื่องไปแถวถัดไป (บรรทัดตรรกะยาวหลายแถว)
FSTPOS      equ $FBCA   ; 2 ไบต์: ตำแหน่งเริ่มรับบรรทัดของ INLIN (L=แถว, H=คอลัมน์)
CRTCNT      equ $F3B1   ; จำนวนแถวของจอ (24)
BUF         equ $F55E   ; buffer บรรทัดที่ INLIN ส่งให้ BASIC (258 ไบต์) -- INLIN_REBUILD เขียนทับ
                        ; ตรง ๆ โดยอ่านจาก VRAM ใหม่ทั้งหมด (ไม่อ่านจาก BUF เดิม จึงไม่ต้องมี buffer
                        ; ชั่วคราว -- ห้ามใช้ KBUF เพราะถ้าเป็น INPUT ใน direct mode คำสั่งที่กำลังรัน
                        ; อยู่ใน KBUF)

; ---- keyboard type-ahead queue (documented system variables, ยืนยันจาก disassembly
;      ของ routine push คิวคีย์บอร์ดในต้นฉบับที่ 0x4E25-0x4E33 ซึ่งอ้างถึงตำแหน่งเหล่านี้ตรง ๆ
;      ใช้สำหรับ Phase 3 ส่วนที่ 2 -- ดัน font code ของอักษรไทยเข้าคิวคีย์บอร์ดตอนพิมพ์ ดู
;      src/keyboard.asm QUEUE_PUSH_CHAR) ----
KEYQ_TAIL   equ $F3F8   ; 2 ไบต์: pointer ตำแหน่งที่จะเขียนตัวอักษรถัดไปเข้าคิว
KEYQ_END    equ $F3FA   ; ตำแหน่งขอบท้ายคิว (เทียบกับ L ของ KEYQ_TAIL หลัง advance เพื่อเช็คว่าเต็ม)
KEYQ_ADVANCE equ $10C2  ; routine เลื่อน pointer คิวคีย์บอร์ดแบบ circular -- ยืนยันแล้วว่าเป็น
                        ; address เดียวกันทั้ง MSX1/MSX2/MSX2+ (ดู notes/keyboard_extraction.md
                        ; หัวข้อ 6 และ SPEC_TH.md section 9.8/6)

; ---- Slot switching -- ประวัติ: v1 (บั๊กจริงข้อ 7) ใช้ trampoline มือเขียนเอง (ENASLT เรียกตรง ๆ
;      สองครั้ง) ซึ่งพบว่ายังมีบั๊กต่อ (บั๊กจริงข้อ 8: ENASLT เองทับ C ตอน slot expand, แก้แล้วแต่
;      ผู้ใช้ยืนยันว่ายังพิมพ์ไม่ได้บนเครื่องจริงอยู่ดี) -- v2 (ดูหัวข้อ "การออกแบบใหม่ (RST 30H)"
;      ใน src/keyboard.asm) เปลี่ยนมาใช้ **RST 30H / CALLF** ($0030, official BIOS inter-slot call
;      primitive) แทนทั้งหมด โดยอ้างอิงจาก MSXTHA102_MSX2_porting_notes.md ที่ผู้ใช้ให้มา (เทคนิค
;      เดียวกับที่ ROM ต้นฉบับใช้จริงและพิสูจน์แล้วว่าใช้งานได้บนเครื่องจริง) -- ตรวจสอบ disassembly
;      จริงของ CALLF (MSX1_bios.rom 0x0205, เรียกผ่าน RST 30H=$F7 ที่ 0x0030) ยืนยันว่ามันสลับไปใช้
;      shadow register set (EXX/EX AF,AF') รอบ ๆ การคำนวณ slot/เรียก ENASLT ภายใน เพื่อไม่ต้องพึ่ง
;      push/pop ของเราเอง -- primary BC/DE/HL (รวมถึง C=scan code ที่บั๊กข้อ 8 เคยพัง) จึงปลอดภัย
;      โดยธรรมชาติ ไม่ต้องระวังเองแบบ trampoline เดิม -- KEYC_TRAMPOLINE_SRC/KEYC_TRAMPOLINE เดิม
;      (ด้านล่าง) ยังเก็บไว้เฉย ๆ ไม่ได้ลบทิ้ง (dead code) เผื่อย้อนกลับ แต่ KEYC_INSTALL ไม่เรียกใช้
;      แล้ว
; (RSLREG=$0138, EXPTBL=$FCC1, ENASLT=$0024 ประกาศไว้แล้วด้านบนในตาราง BIOS jump table)
RST30_OPCODE equ $F7    ; RST 30H (= CALLF ผ่าน BIOS hook table format มาตรฐานของ MSX: เขียนที่ hook
                        ; slot เป็น F7,slot,addr_lo,addr_hi,C9 5 ไบต์ -- อ้างอิง
                        ; MSXTHA102_MSX2_porting_notes.md หัวข้อ 2 ("ตัว installer: เขียน F7 <slot>
                        ; <lo> <hi> C9 ลงแต่ละ hook") ที่ยืนยันแล้วว่าใช้งานได้จริงบนเครื่องจริง
SLTTBL      equ $FCC5   ; ตาราง readback ของ secondary slot ปัจจุบันต่อ primary slot แต่ละตัว
                        ; (4 ไบต์, = EXPTBL+4 เสมอ) -- ยืนยันจาก MSX2 Technical Handbook
                        ; (Konamiman's MSX2 Technical Handbook, Chapter 5B) และตัวอย่าง GETSLT
                        ; มาตรฐานที่ map.grauw.nl (MSX Assembly Page)
MY_SLOT_ID     equ $FD10-SLTWRK_OLD  ; 1 ไบต์ (ย้ายจาก $FD0E เดิม เพราะ PREV_KEYC ขยายเป็น 5 ไบต์แล้วชนพื้นที่
                          ; เดิม): slot ID (รูปแบบเดียวกับที่ RDSLT/ENASLT ใช้) ของ cartridge นี้เอง
                          ; -- คำนวณครั้งเดียวตอน KEYC_INSTALL (ตอนนั้น page 1 คือ slot ของเราแน่นอน
                          ; เพราะ BASIC เพิ่งเรียกเข้ามาทาง STATEMENT/CALL THAION) ใช้เป็น byte ที่ 2
                          ; ของ RST 30H hook slot (ดูด้านบน)
; SAVED_P1_SLOT: RST 30H/CALLF จัดการ save/restore slot ของ page 1 ให้เองภายในตัว (ดูเหตุผลด้านบน)
; ไม่จำเป็นสำหรับกลไกใหม่แล้ว -- equate นี้เหลือไว้แค่เพราะ KEYC_TRAMPOLINE_SRC (dead code เดิม, ดู
; ด้านล่าง) ยังอ้างถึงอยู่ -- ย้ายไปใช้ RAM ที่ไม่ชนกับ PREV_KEYC 5 ไบต์ใหม่/MY_SLOT_ID
                          ; $FD89 ตัวเดียว) -- ใช้แค่ให้ dead code เดิมคอมไพล์ผ่าน ไม่ได้ถูกเรียกจริง
;
; KEYC_TRAMPOLINE เดิม ($FD10-$FD5A เดิม -- ย้ายไปที่อื่นแล้วเพราะ MY_SLOT_ID ใหม่ใช้ $FD10) เลิกใช้แล้วเช่นกัน (ไม่มี RAM trampoline อีกต่อไป เพราะ
; RST 30H ไม่ต้องการ "โค้ดที่รันได้ก่อน page 1 จะเป็น slot ของเรา" แบบที่ trampoline เดิมต้องการ --
; ตัว RST 30H เองอยู่ใน hook slot ที่ page 1 เท่านั้น [$FDCC, page 3 เสมอ, ไม่ใช่ page 1] และเป็น
; BIOS mechanism ล้วน ๆ ไม่ใช่โค้ดของเรา) -- RAM ย่านนี้ (และ SLTWRK collision risk ที่เคยบันทึกไว้
; ในบั๊กข้อ 7) จึงไม่มีผลอีกต่อไปเพราะเราแทบไม่ใช้ RAM ย่าน SLTWRK เลยแล้ว (เหลือแค่ PREV_KEYC 5
; ไบต์ + MY_SLOT_ID 1 ไบต์ = 6 ไบต์ รวม $FD0B-$FD10)

; ---- ค่าคงที่อื่น ----
TRUE        equ $FF
FALSE       equ $00

; ---- 9.30: routine ภายในของ BASIC ROM ที่ ANSTR/TNSTR/MLSTR ใช้ (เรียกผ่าน CALBAS แบบเดียวกับต้นฉบับ) --
; ตรวจแล้วว่า code ที่ address เหล่านี้เหมือนกันทุกไบต์บน MSX1 / MSX2 / MSX2+ BASIC ROM
CALBAS      equ $0159   ; BIOS: เรียก routine ใน BASIC ROM (IX = address)
BAS_CHRGTR  equ $4666   ; อ่านตัวถัดไปในข้อความ (ข้ามช่องว่าง)
BAS_FRMEVL  equ $4C64   ; ประเมินนิพจน์ -> DAC
BAS_GETYPR  equ $5597   ; ชนิดของผลใน DAC (Z = สตริง)
BAS_PTRGET  equ $5EA4   ; หา/สร้างตัวแปร -> DE = address ค่าของตัวแปร
BAS_STRCPY  equ $6611   ; คัดลอกสตริง (HL -> descriptor) เข้า string space -> DE = descriptor ชั่วคราว
BAS_FRESTR  equ $67D3   ; ปล่อยสตริงชั่วคราวใน DAC -> HL = descriptor
BAS_SNERR   equ $4055   ; "Syntax error"
BAS_TMERR   equ $406D   ; "Type mismatch"
VALTYP      equ $F663   ; ชนิดของค่า (3 = สตริง)

BCALL MACRO addr
	push ix
	ld ix,addr
	call CALBAS
	pop ix
	ENDM
