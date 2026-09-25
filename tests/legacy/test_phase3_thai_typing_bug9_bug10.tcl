# openMSX regression test สำหรับบั๊กจริงข้อ 9 (SHIFT_STATE active-low กลับขั้ว) และบั๊กจริงข้อ 10
# (BIOS's post-hook dispatch ดันตัวอักษรซ้ำหลังเปลี่ยนมาใช้ RST 30H/CALLF) -- ดู src/keyboard.asm
# หัวข้อ 4 (บั๊กจริงข้อ 9/10) และ comment เต็มที่ KEYC_INSTALL สำหรับรายละเอียดการวิเคราะห์/แก้ไขเต็ม
#
# วิธีรัน (ตัวอย่าง):
#   export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
#   openmsx -machine UserMSX1_expanded -carta build/thairom.rom \
#           -script test_phase3_thai_typing_bug9_bug10.tcl
#   cat /tmp/bug9_bug10_regression_out.txt   # ต้องเห็น "PASS" ไม่ใช่ "FAIL"
#
# สิ่งที่เทส: CALL THAION -> CALL INPUTON (กดปุ่มสลับโหมดจริงผ่าน "call inputon" ซึ่งภายในกดปุ่ม
# สลับโหมดแทนผู้ใช้) -> พิมพ์ "asd" -- ต้องได้ font code ไทยตรงตาม MAIN_ROW_TABLE เป๊ะ (191,203,161)
# ไม่มีตัวอักษรขยะ/ซ้ำแทรกเข้ามา (บั๊กจริงข้อ 10 จะทำให้มีไบต์เกินมาแทรกขั้นระหว่างตัวอักษรที่ถูกต้อง
# แต่ละตัว) และต้องเกิดขึ้นจริงระหว่างพิมพ์ปกติโดยไม่ต้องพึ่งการตั้งค่าพิเศษใด ๆ (บั๊กจริงข้อ 9 ทำให้
# โหมดไทยไม่เคย engage เลยตอน idle จริง ถ้ายังไม่แก้จะได้ตัวอักษรอังกฤษปกติ a/s/d = 97/115/100 แทน)

# *** อัปเดต (คำขอผู้ใช้: THAION เป็น default ตอน boot) -- INIT ตอนนี้ auto-stuff "CALL THAION:?..."
# เข้าคิวคีย์บอร์ดเองตั้งแต่ boot (ดู src/init.asm) ทำให้คิวไม่ได้เริ่มว่างเปล่าที่ $FBF0 อีกต่อไปตอน
# test เริ่มพิมพ์ของตัวเอง -- เปลี่ยนจาก offset คงที่มือ (0xFBF0+25) เป็นอ่าน KEYQ_TAIL จริงแทน เพื่อ
# ความทนทาน (robust) ไม่ผูกกับความยาวของ auto-exec string ที่อาจเปลี่ยนได้อีกในอนาคต

set outf [open "/tmp/bug9_bug10_regression_out.txt" w]

proc keyq_tail {} {
    set b [debug read_block "memory" 0xF3F8 2]
    binary scan $b cu2 bytes
    set lo [lindex $bytes 0]
    set hi [lindex $bytes 1]
    return [expr {$lo + ($hi << 8) - 0xFBF0}]
}

after realtime 2.0 { type "call thaion\r" }
after realtime 3.5 { type "call inputon\r" }
after realtime 4.7 {
    global base
    set base [keyq_tail]
}
after realtime 5.0 { type "asd" }

after realtime 6.5 {
    global outf base
    set n [expr {[keyq_tail] - $base}]
    if {$n < 0} { set n [expr {$n + 40}] }
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    set expect {191 203 161}
    if {$got eq $expect} {
        puts $outf "PASS: keyboard buffer after THAION+INPUTON, typing 'asd' = $got (ฟ,ส,ด ถูกต้อง ไม่มีตัวอักษรซ้ำ/ขยะแทรก)"
    } else {
        puts $outf "FAIL: keyboard buffer after THAION+INPUTON, typing 'asd' = $got (expected $expect -- บั๊กจริงข้อ 9 และ/หรือ 10 อาจกลับมา)"
    }
    flush $outf
    close $outf
}
after realtime 7.0 { exit }
