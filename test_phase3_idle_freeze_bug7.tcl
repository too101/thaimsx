set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/idle_freeze_bug7_out.txt" w]

# บั๊กจริงข้อ 7 (ดู src/keyboard.asm หัวข้อ 4 และ equates.asm): บนเครื่องจริง/blueMSX ผู้ใช้
# รายงานว่าเครื่อง "ค้างสนิท" หลัง `call thaion` -- นั่งเฉย ๆ ที่ prompt สักพัก (ให้ BASIC แย่ง
# slot ของหน้า 1 กลับไปจากตอน idle) แล้ว "กดปุ่มจริง" (ผ่าน matrix scan, ไม่ใช่ poke ตรงเข้า
# keyboard buffer) คือจุดที่ interrupt-driven H.KEYC ถูกเรียกด้วย call ธรรมดาไปเจอโค้ดของ BASIC
# เองแทนที่จะเป็นของเรา -- สคริปต์นี้จำลองครบทั้งสองขั้น: (1) idle ยาว ๆ ให้ BASIC แย่ง slot คืน
# (2) กดปุ่มจริงผ่าน `type` (matrix simulation) หลัง idle เพื่อ trigger เส้นทางที่ทำให้ค้างจริง ๆ
# (`type_via_keybuf` ที่ใช้ในสคริปต์ทดสอบอื่น ๆ ของโปรเจกต์นี้ poke ตรงเข้า buffer โดยไม่ผ่าน
# H.KEYC เลย จึง**ไม่มีทาง**ทำให้เจอบั๊กนี้ได้ -- นี่คือเหตุผลที่ regression test เดิมของโปรเจกต์
# ไม่เคยจับบั๊กนี้ได้มาก่อน)

after realtime 3.0 { type "call thaion\r" }

after realtime 4.5 {
    global outf
    set hk [debug read_block "memory" 0xFDCC 3]
    binary scan $hk cu3 hkv
    puts $outf "0) after THAION: H_KEYC bytes = $hkv"
    set d [debug read_block "memory" 0x4169 4]
    binary scan $d cu4 dv
    puts $outf "0b) bytes at 0x4169 right after THAION = $dv"
    flush $outf
}

# นั่งเฉย ๆ ยาว ๆ (ไม่พิมพ์อะไรเลย) ~5 วินาที (~300 เฟรมที่ 60Hz) เพื่อให้ BASIC idle loop มีเวลา
# แย่ง slot ของหน้า 1 กลับไปเป็นของตัวเองแน่ ๆ (ยืนยันแยกต่างหากแล้วว่าเกิดขึ้นจริงหลัง thaion
# แทบจะทันที -- ดู idle_freeze scratch diagnostics)
after realtime 9.5 {
    global outf
    set d [debug read_block "memory" 0x4169 4]
    binary scan $d cu4 dv
    puts $outf "1) bytes at 0x4169 after ~5s idle = $dv (ถ้า slot ของเราเอง byte แรกควรเป็น 243=0xF3 DI; ถ้า BASIC แย่งไปแล้วจะเป็นค่าอื่น)"
    flush $outf
}

# หัวใจของเทสนี้: กดปุ่มจริงผ่าน matrix scan (ไม่ใช่ keybuf) หลัง idle ยาว ๆ -- คีย์ 'A' (scan 0x16)
# ที่ตอนนี้ THAI_MODE+INPUT_MODE เปิดอยู่ ควรจะ map เป็น ฟ (0xBF) ถ้า hook ทำงานถูกต้อง
#
# *** ข้อจำกัดที่พบจริงระหว่างเขียนเทสนี้ (บันทึกไว้ตรง ๆ ไม่ปิดบัง) ***: ยืนยันแยกต่างหากแล้วว่า
# ที่อยู่ 0x4169 ระหว่าง idle (หลัง thaion) มีค่า AF 32 AA F6 จริง -- **ตรงกับ debugger screenshot
# ของผู้ใช้บน blueMSX เป๊ะทุกไบต์** (ยืนยันอิสระว่าทฤษฎี slot-aliasing ถูกต้องจริง ไม่ใช่แค่ทฤษฎี)
# แต่ทดสอบแล้วพบว่า openMSX's `type` command (matrix simulation) ส่ง keypress เดี่ยว ๆ แบบนี้ไม่
# น่าเชื่อถือพอที่จะ trigger เส้นทาง interrupt-driven H.KEYC ให้เห็นผลต่างระหว่าง build ที่มีบั๊ก
# กับ build ที่แก้แล้วได้ชัดเจน (สอดคล้องกับข้อค้นพบเดิมของโปรเจกต์ใน SPEC_TH.md section 9.8 ว่า
# `type` ไวต่อ latency ผิดปกติในสถานการณ์นี้) -- ทดสอบทั้งสอง build (ก่อนแก้บั๊กข้อ 7 / หลังแก้)
# ด้วยสคริปต์นี้แล้วไม่มี build ไหนแสดงอาการค้างจริงใน openMSX เอง (ต่างจาก blueMSX ที่ผู้ใช้ยืนยัน
# ว่าค้างจริง) -- ดังนั้นเทสนี้ยังคงมีประโยชน์สำหรับยืนยัน "byte ที่ 0x4169 ตรงกับที่ผู้ใช้เจอจริง"
# (ข้อ 0b/1 ด้านบน) และ "ไม่มี regression ที่เห็นได้จาก openMSX" แต่**ไม่ใช่**การพิสูจน์ freeze/fix
# แบบ end-to-end เต็มรูปแบบ -- หลักฐานหลักของการแก้บั๊กจริงคือ debugger screenshot ของผู้ใช้ +
# unit test ของ trampoline logic เอง (test_phase3_keyboard.py, test_phase3_e2e_biosreal.py)
after realtime 9.8 { type "A" }

set pc_samples {}
for {set i 1} {$i <= 6} {incr i} {
    set t [expr {9.9 + $i * 0.3}]
    after realtime $t "lappend ::pc_samples \[reg PC\]"
}

after realtime 12.0 {
    global outf pc_samples
    puts $outf "2) PC samples right after real matrix keypress: $pc_samples"
    set uniq [lsort -unique $pc_samples]
    puts $outf "   unique PC values: [llength $uniq] -- $uniq"
    screenshot -prefix idle_freeze_bug7_keypress -raw
    flush $outf
}

# ถ้ายังไม่ค้าง ลองพิมพ์ต่อผ่าน keybuf (ธรรมเนียมเดิมของโปรเจกต์ เลี่ยง latency ของ `type` ตอน
# พิมพ์หลายตัวติด ๆ กัน) เพื่อดูว่าระบบยังทำงานสมบูรณ์ต่อได้จริง ไม่ใช่แค่ "ไม่ค้างตอนกดปุ่มเดียว"
after realtime 12.3 { type_via_keybuf "print 111+222\r" }
after realtime 12.8 {
    global outf
    screenshot -prefix idle_freeze_bug7_final -raw
    puts $outf "3) typed 'print 111+222' via keybuf after real keypress -- screenshot saved"
    puts $outf "   final PC=[reg PC]"
    flush $outf
}

after realtime 13.1 { type_via_keybuf "call thaioff\r" }
after realtime 13.5 {
    global outf
    set hk [debug read_block "memory" 0xFDCC 1]
    binary scan $hk cu hkv
    puts $outf "4) after THAIOFF: H_KEYC opcode = $hkv (expect 201 = 0xC9 RET, restored)"
    close $outf
}
after realtime 13.8 { exit }
