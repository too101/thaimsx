# openMSX regression -- บั๊กจริงข้อ 12 (RAM ของ INPUT_MODE/THAI_MODE ชนกับตัวแปรระบบจริงของ
# BIOS/BASIC ที่ $FCAC/$FCAD -- อาการที่ผู้ใช้รายงานบนฮาร์ดแวร์จริงรอบแรก: "กด bs กลับเป็น english")
# พร้อมด้วย regression ยืนยันบั๊กจริงข้อ 11 (แถวตัวเลข + Shift ตัวบน) แบบ PASS/FAIL อัตโนมัติ
# แทนที่ test_phase3_bug11_live.tcl (ซึ่งเป็นแค่สคริปต์สืบสวนสดที่ไม่เช็ค PASS/FAIL เอง)
#
# *** อัปเดต -- ผู้ใช้รายงานรอบสองว่าไม่ใช่แค่ BS: "เวลา shift กับตัวอักษร หลังจากนั้นก็เป็น
# ภาษาอังกฤษ หรือ enter" คือกด Shift+ตัวอักษร หรือกด Enter ก็ทำให้กลับเป็นอังกฤษได้เหมือนกัน --
# ตรงกับสาเหตุรากที่วินิจฉัยไว้ทุกประการ ($FCAC/$FCAD เป็นตัวแปรระบบจริงที่โดนเขียนทับจากหลาย
# เส้นทางของ BIOS/BASIC เอง ไม่ใช่แค่ตอนกด BS) -- การแก้โดยย้ายไปที่ $FD11/$FD12 (พื้นที่ที่ผ่าน
# การทดสอบ e2e จริงมามากแล้วไม่พบการชนกัน) จึงควรแก้ครอบคลุมทุกเส้นทางพร้อมกัน -- เพิ่มเคส
# Shift+ตัวอักษร->พิมพ์ปกติต่อ และ Enter->พิมพ์ปกติต่อ ด้านล่างเพื่อยืนยันจริงบน build ใหม่
#
# วิธีอ่านผล: ใช้ KEYQ_TAIL (ตัวชี้หางคิวคีย์บอร์ดจริงของเราเอง, ไม่ใช่ค่าคงที่ BIOS) เพื่อคำนวณ
# ตำแหน่งที่ถูกต้องหลังจากพิมพ์แต่ละคำสั่ง แทนการนับ offset คงที่มือ (ซึ่งพลาดง่ายมาก -- ดูบทเรียน
# จาก test_phase3_bug11_live.tcl ที่นับ offset ของ BS ผิดตอนสืบสวนครั้งแรก)

set outf [open "/tmp/msxtest/thairom/bug12_regression_out.txt" w]
set failed 0

proc keyq_tail {} {
    set b [debug read_block "memory" 0xF3F8 2]
    binary scan $b cu2 bytes
    set lo [lindex $bytes 0]
    set hi [lindex $bytes 1]
    return [expr {$lo + ($hi << 8) - 0xFBF0}]
}

after realtime 2.0 { type "call thaion\r" }
after realtime 3.5 { type "call inputon\r" }

# ฐานเริ่มต้น = ท้ายคิวหลังพิมพ์ "call thaion\r"+"call inputon\r" (25 ไบต์)
after realtime 5.0 {
    global outf base
    set base [keyq_tail]
    puts $outf "base offset after thaion+inputon = $base (คาดหวัง 25)"
}

# --- บั๊กจริงข้อ 11: แถวตัวเลข ---
after realtime 5.2 { type "123" }
after realtime 6.0 {
    global outf base failed
    set n [expr {[keyq_tail] - $base}]
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    set expect {163 47 95}
    if {$got eq $expect} {
        puts $outf "PASS: digit row '123' -> $got"
    } else {
        puts $outf "FAIL: digit row '123' -> $got (expected $expect) -- บั๊กจริงข้อ 11 อาจกลับมา"
        set failed 1
    }
    set base [keyq_tail]
    flush $outf
}

# --- บั๊กจริงข้อ 11: Shift+A ต้องได้อักษรไทยชุดที่สอง ไม่ใช่ 'A' อังกฤษ ---
after realtime 6.5 { type "A" }
after realtime 7.2 {
    global outf base failed
    set n [expr {[keyq_tail] - $base}]
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    if {$got == 196} {
        puts $outf "PASS: Shift+A -> $got (0xC4 จาก THAI_SHIFTED_TABLE)"
    } else {
        puts $outf "FAIL: Shift+A -> $got (expected 196) -- บั๊กจริงข้อ 11 อาจกลับมา"
        set failed 1
    }
    set base [keyq_tail]
    flush $outf
}

# --- บั๊กจริงข้อ 12: พิมพ์ 'a' -> กด BS -> พิมพ์ 'a' อีกที ต้องได้ 191 (ฟ) ทั้งสองครั้ง ---
after realtime 7.7 { type "a" }
after realtime 8.4 {
    global outf base failed
    set n [expr {[keyq_tail] - $base}]
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    if {$got == 191} {
        puts $outf "PASS: 'a' ก่อนกด BS -> $got"
    } else {
        puts $outf "FAIL: 'a' ก่อนกด BS -> $got (expected 191)"
        set failed 1
    }
    set base [keyq_tail]
    flush $outf
}
after realtime 8.9 { type "\x08" }
after realtime 9.6 {
    global outf base
    # BS ไม่ได้ map ในตารางไทย จึงปล่อยผ่านเป็น ascii 8 ตามปกติ (ดูคอมเมนต์อธิบายใน
    # test_phase3_bug11_live.tcl เดิม -- นี่คือพฤติกรรมที่ถูกต้อง ไม่ใช่สิ่งที่ต้องแก้)
    set base [keyq_tail]
    puts $outf "base offset after BS = $base"
    flush $outf
}
after realtime 10.1 { type "a" }
after realtime 10.8 {
    global outf base failed
    set n [expr {[keyq_tail] - $base}]
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    if {$got == 191} {
        puts $outf "PASS: 'a' หลังกด BS -> $got (ยังเป็นไทยปกติ -- บั๊กจริงข้อ 12 แก้แล้ว)"
    } else {
        puts $outf "FAIL: 'a' หลังกด BS -> $got (expected 191, got english 97 or other = บั๊กจริงข้อ 12 ยังไม่แก้)"
        set failed 1
    }
    set base [keyq_tail]
    flush $outf
}

# --- บั๊กจริงข้อ 12 (รายงานรอบสอง): Shift+ตัวอักษร แล้วพิมพ์ตัวอักษรธรรมดาต่อ ต้องยังเป็นไทย ---
after realtime 11.3 { type "A" }
after realtime 12.0 {
    global outf base
    set base [keyq_tail]
    puts $outf "base offset after Shift+A (2nd time) = $base"
    flush $outf
}
after realtime 12.5 { type "a" }
after realtime 13.2 {
    global outf base failed
    set n [expr {[keyq_tail] - $base}]
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    if {$got == 191} {
        puts $outf "PASS: 'a' หลังกด Shift+A -> $got (ยังเป็นไทยปกติ)"
    } else {
        puts $outf "FAIL: 'a' หลังกด Shift+A -> $got (expected 191) -- อาการที่ผู้ใช้รายงานรอบสอง"
        set failed 1
    }
    set base [keyq_tail]
    flush $outf
}

# --- บั๊กจริงข้อ 12 (รายงานรอบสอง): กด Enter แล้วพิมพ์ตัวอักษรธรรมดาต่อ ต้องยังเป็นไทย ---
after realtime 13.7 { type "\r" }
after realtime 14.4 {
    global outf base
    set base [keyq_tail]
    puts $outf "base offset after Enter = $base"
    flush $outf
}
after realtime 14.9 { type "a" }
after realtime 15.6 {
    global outf base failed
    set n [expr {[keyq_tail] - $base}]
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    # 9.31: Enter ใน direct mode กลับเป็นอังกฤษโดยตั้งใจ (ตามต้นฉบับ -- ผู้ใช้ขอ) จึงต้องได้ 'a' = 97
    if {$got == 97} {
        puts $outf "PASS: 'a' หลังกด Enter -> $got (กลับเป็นอังกฤษตามต้นฉบับ 9.31)"
    } else {
        puts $outf "FAIL: 'a' หลังกด Enter -> $got (expected 97 -- 9.31 Enter ใน direct mode = อังกฤษ)"
        set failed 1
    }
    puts $outf "RESULT: [expr {$failed ? {FAIL} : {ALL PASS}}]"
    flush $outf
    close $outf
}
after realtime 16.1 { exit }
