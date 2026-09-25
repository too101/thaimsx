# openMSX regression test สำหรับ PRINTON compositing (การซ้อนสระบน/วรรณยุกต์เหนือพยัญชนะ
# ในคอลัมน์เดียวกัน ผ่าน H_CHPUT hook -- ดู src/printon.asm สำหรับกลไกเต็ม และ SPEC_TH.md
# section 9.17/9.18 สำหรับเรื่องราวการ implement/บั๊กที่เจอ+แก้เต็ม ๆ)
#
# *** แก้ไขรอบสอง: เดิมทดสอบว่า D4(212)+E8(232) ซ้อนกัน 3 แถวแยก (พยัญชนะ/สระ/วรรณยุกต์ คนละ
# แถว) ซึ่งเป็นความเข้าใจที่ผิด (ดู printon.asm comment ใหญ่ต้นไฟล์) -- ที่ถูกคือวรรณยุกต์ที่ตามหลัง
# สระบนต้อง "ผสม" เป็น glyph เดียว (โค้ด 0x88 สำหรับ D4+E8) ทับตำแหน่งสระบนเดิมที่แถว-1 ไม่ใช่ซ้อน
# แถว-2 แยก -- แก้ test นี้ให้ตรงแล้ว (ดู test_printon_combine.tcl สำหรับเทสละเอียดกว่านี้ รวม
# Backspace-undo และสระล่างด้วย)
#
# ใช้ PRINT CHR$(...) แทนการพิมพ์ตัวโค้ดไทยดิบที่ prompt ตรง ๆ -- เพราะการพิมพ์โค้ดไทยดิบแล้วกด
# Enter ทำให้ BASIC ตีความเป็น statement ไม่ได้ (Syntax error) ซึ่งกินพื้นที่จอไม่แน่นอน ทำให้ทดสอบ
# ต่อยาก (โดยเฉพาะใกล้ขอบล่างจอ) -- PRINT CHR$() เป็น statement ที่ถูกต้องเสมอ จึงกิน 1 บรรทัด
# ตรรกะที่คาดเดาได้ทุกครั้ง และยังคงเดินผ่าน CHPUT/H_CHPUT เหมือนพิมพ์จริงทุกประการ
#
# ใช้ type_via_keybuf สำหรับคำสั่งทั้งหมด (poke ตรงเข้าคิวคีย์บอร์ด บายพาส matrix scan -- ปลอดภัย
# สำหรับ ASCII ล้วน ๆ อย่างชื่อคำสั่ง/ตัวเลขใน CHR$() ซึ่งไม่ต้องพึ่ง H_KEYC hook แปลอะไรเลย)
#
# วิธีรัน:
#   export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
#   openmsx -machine UserMSX1_expanded -carta build/thairom.rom \
#           -script test_printon_compositing.tcl
#   cat /tmp/printon_compositing_out.txt   # ต้องเห็น "PASS" ทุกบรรทัด

set outf [open "/tmp/printon_compositing_out.txt" w]

proc scan_marks {} {
    set b [debug read_block "physical VRAM" 0 960]
    binary scan $b cu960 bytes
    set result {}
    for {set i 0} {$i<960} {incr i} {
        set v [lindex $bytes $i]
        if {$v==161 || $v==212 || $v==232} {
            lappend result [format "row=%d,col=%d=%d" [expr {$i/40+1}] [expr {$i%40}] $v]
        }
    }
    return $result
}

after realtime 2.0 { type "call thaion\r" }
after realtime 3.5 { type_via_keybuf "call printon\r" }
after realtime 4.0 { type_via_keybuf "cls\r" }
after realtime 4.3 { type_via_keybuf "print chr\$(161)chr\$(212)chr\$(232)\r" }
after realtime 5.3 {
    global outf
    # สแกนหา 161 (พยัญชนะ), 136 (โค้ดผสม D4+E8 ที่ถูกต้อง), และ 212/232 (ต้อง "ไม่เจอเลย" --
    # ถ้าเจอแปลว่า combine ไม่ทำงาน ยังปล่อยตัวเปล่าค้างอยู่)
    set b [debug read_block "physical VRAM" 0 960]
    binary scan $b cu960 bytes
    set marks {}
    for {set i 0} {$i<960} {incr i} {
        set v [lindex $bytes $i]
        if {$v==161 || $v==136 || $v==212 || $v==232} {
            lappend marks [format "row=%d,col=%d=%d" [expr {$i/40+1}] [expr {$i%40}] $v]
        }
    }
    puts $outf "PRINTON: chr\$(161)+chr\$(212)+chr\$(232) -> $marks"
    set ok 0
    if {[llength $marks] == 2} {
        foreach m $marks {
            regexp {row=(\d+),col=(\d+)=(\d+)} $m -> r c v
            if {$v == 161} { set r161 $r; set c161 $c }
            if {$v == 136} { set r136 $r; set c136 $c }
        }
        if {[info exists r161] && [info exists r136]
                && $c161 == $c136 && $r136 == $r161-1} {
            set ok 1
        }
    }
    if {$ok} {
        puts $outf "PASS: PRINTON compositing (ผสมสระบน+วรรณยุกต์เป็น glyph เดียวที่แถว-1) ถูกต้อง"
    } else {
        puts $outf "FAIL: PRINTON compositing ไม่ตรงตามที่คาด"
    }
    flush $outf
}

after realtime 5.6 { type_via_keybuf "call printoff\r" }
after realtime 6.1 { type_via_keybuf "cls\r" }
after realtime 6.4 { type_via_keybuf "print chr\$(161)chr\$(212)chr\$(232)\r" }
after realtime 7.4 {
    global outf
    set marks [scan_marks]
    puts $outf "PRINTOFF: chr\$(161)+chr\$(212)+chr\$(232) -> $marks"
    set ok 0
    if {[llength $marks] == 3} {
        foreach m $marks {
            regexp {row=(\d+),col=(\d+)=(\d+)} $m -> r c v
            if {$v == 161} { set r161 $r; set c161 $c }
            if {$v == 212} { set r212 $r; set c212 $c }
            if {$v == 232} { set r232 $r; set c232 $c }
        }
        if {[info exists r161] && [info exists r212] && [info exists r232]
                && $r161 == $r212 && $r212 == $r232
                && $c212 == $c161+1 && $c232 == $c161+2} {
            set ok 1
        }
    }
    if {$ok} {
        puts $outf "PASS: PRINTOFF -- ตัวอักษรเรียงปกติคนละคอลัมน์ แถวเดียวกัน (ไม่ซ้อน)"
    } else {
        puts $outf "FAIL: PRINTOFF ควรวาดปกติไม่ซ้อน แต่ผลไม่ตรง"
    }
    flush $outf
    close $outf
}
after realtime 7.7 { exit }
