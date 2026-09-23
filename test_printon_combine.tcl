# openMSX regression test สำหรับ PRINTON "ผสมสระบน+วรรณยุกต์เป็น glyph เดียว" +
# "undo ด้วย Backspace" + "สระล่างซ้อนแถว+1" (ดู src/printon.asm comment ใหญ่ต้นไฟล์
# และ SPEC_TH.md section 9.17/9.18 สำหรับที่มาเต็ม ๆ ของกลไกทั้งหมด)
#
# วิธีรัน:
#   export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
#   openmsx -machine UserMSX1_expanded -carta build/thairom.rom \
#           -script test_printon_combine.tcl
#   cat /tmp/printon_combine_out.txt   # ต้องเห็น "PASS" ทุกบรรทัด

set outf [open "/tmp/printon_combine_out.txt" w]

proc scan_for {codes} {
    set b [debug read_block "physical VRAM" 0 960]
    binary scan $b cu960 bytes
    set result {}
    foreach code $codes {
        for {set i 0} {$i<960} {incr i} {
            set v [lindex $bytes $i]
            if {$v==$code} {
                lappend result [format "code=%d,row=%d,col=%d" $v [expr {$i/40+1}] [expr {$i%40}]]
            }
        }
    }
    return $result
}

proc count_code {marks code} {
    set n 0
    foreach m $marks {
        if {[regexp {code=(\d+),row=(\d+),col=(\d+)} $m -> c r cc] && $c==$code} { incr n }
    }
    return $n
}

proc pos_of {marks code} {
    foreach m $marks {
        if {[regexp {code=(\d+),row=(\d+),col=(\d+)} $m -> c r cc] && $c==$code} {
            return [list $r $cc]
        }
    }
    return {}
}

after realtime 2.0 { type "call thaion\r" }
after realtime 3.5 { type_via_keybuf "call printon\r" }

# ---- Test 1: ผสม D1(209)+E8(232) -> ต้องได้ 131 (0x83) ที่แถว-1 คอลัมน์เดียวกับพยัญชนะ
# ไม่ใช่ 209/232 เปล่า ๆ เหลืออยู่เลย ----
after realtime 4.0 { type_via_keybuf "cls\r" }
after realtime 4.3 { type_via_keybuf "print chr\$(161)chr\$(209)chr\$(232)\r" }
after realtime 5.3 {
    global outf
    set marks [scan_for {161 209 232 131}]
    puts $outf "TEST1 (combine D1+E8->131): $marks"
    set ok 0
    if {[count_code $marks 161]==1 && [count_code $marks 131]==1
            && [count_code $marks 209]==0 && [count_code $marks 232]==0} {
        set p161 [pos_of $marks 161]
        set p131 [pos_of $marks 131]
        set r161 [lindex $p161 0]; set c161 [lindex $p161 1]
        set r131 [lindex $p131 0]; set c131 [lindex $p131 1]
        if {$c131==$c161 && $r131==$r161-1} { set ok 1 }
    }
    if {$ok} {
        puts $outf "PASS: TEST1 -- ผสมสระบน+วรรณยุกต์เป็น glyph 131 ทับแถว-1 ถูกต้อง"
    } else {
        puts $outf "FAIL: TEST1"
    }
    flush $outf
}

# ---- Test 2: พิมพ์ชุดเดิมแล้วตามด้วย Backspace ทันที (chr$(8)) -- ต้อง undo กลับเป็น
# สระบนเปล่า ๆ (209) ไม่ใช่ glyph ผสม (131) และไม่ใช่วรรณยุกต์เปล่า (232) ค้างอยู่ด้วย ----
after realtime 5.6 { type_via_keybuf "cls\r" }
after realtime 5.9 { type_via_keybuf "print chr\$(161)chr\$(209)chr\$(232)chr\$(8)\r" }
after realtime 6.9 {
    global outf
    set marks [scan_for {161 209 232 131}]
    puts $outf "TEST2 (backspace undo): $marks"
    set ok 0
    if {[count_code $marks 161]==1 && [count_code $marks 209]==1
            && [count_code $marks 232]==0 && [count_code $marks 131]==0} {
        set p161 [pos_of $marks 161]
        set p209 [pos_of $marks 209]
        set r161 [lindex $p161 0]; set c161 [lindex $p161 1]
        set r209 [lindex $p209 0]; set c209 [lindex $p209 1]
        if {$c209==$c161 && $r209==$r161-1} { set ok 1 }
    }
    if {$ok} {
        puts $outf "PASS: TEST2 -- Backspace undo กลับเป็นสระบนเปล่า ๆ ถูกต้อง"
    } else {
        puts $outf "FAIL: TEST2"
    }
    flush $outf
}

# ---- Test 3: สระล่าง D6(214) ต้องซ้อนแถว+1 (ใต้พยัญชนะ) ไม่ใช่แถว-1 ----
after realtime 7.2 { type_via_keybuf "cls\r" }
after realtime 7.5 { type_via_keybuf "print chr\$(161)chr\$(214)\r" }
after realtime 8.5 {
    global outf
    set marks [scan_for {161 214}]
    puts $outf "TEST3 (lower vowel D6 at row+1): $marks"
    set ok 0
    if {[count_code $marks 161]==1 && [count_code $marks 214]==1} {
        set p161 [pos_of $marks 161]
        set p214 [pos_of $marks 214]
        set r161 [lindex $p161 0]; set c161 [lindex $p161 1]
        set r214 [lindex $p214 0]; set c214 [lindex $p214 1]
        if {$c214==$c161 && $r214==$r161+1} { set ok 1 }
    }
    if {$ok} {
        puts $outf "PASS: TEST3 -- สระล่าง D6 ซ้อนแถว+1 ถูกต้อง"
    } else {
        puts $outf "FAIL: TEST3"
    }
    flush $outf
    close $outf
}
after realtime 8.8 { exit }
