# openMSX regression test for บั๊กจริงข้อ 8 (SPEC_TH.md 9.11) -- ต้องรันกับ machine config ที่ primary
# slot 0 เป็น "expanded" (subslotted) จริง เช่น UserMSX1_expanded.xml (primary slot 0 มี
# <secondary slot="0"> ครอบ System ROM ไว้) -- machine config แบบไม่ expand (UserMSX1/UserMSX1_abs) จะ
# "ผ่าน" เทสนี้เสมอแม้ยังไม่ได้แก้บั๊ก เพราะเส้นทางง่ายของ ENASLT ไม่แตะ C เลย จึงไม่มีประโยชน์สำหรับเทสนี้
#
# วิธีรัน (ตัวอย่าง):
#   export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
#   openmsx -machine UserMSX1_expanded -carta build/thairom.rom \
#           -script test_phase3_expanded_slot_bug8.tcl
#   cat /tmp/bug8_regression_out.txt   # ต้องเห็น "PASS" ไม่ใช่ "FAIL"
#
# สิ่งที่เทส: พิมพ์ "Hello" หลัง CALL THAION แล้วอ่านคิวคีย์บอร์ดจริง (KEYBUF, $FBF0) เทียบกับไบต์ ASCII
# ของ "Hello" ตรง ๆ -- ก่อนแก้บั๊กข้อ 8 จะได้ 33 190 190 190 190 (ผิด), หลังแก้ต้องได้ 72 101 108 108 111

# *** อัปเดต (คำขอผู้ใช้: THAION เป็น default ตอน boot) -- INIT ตอนนี้ auto-stuff "CALL THAION:?..."
# เข้าคิวคีย์บอร์ดเองตั้งแต่ boot (ดู src/init.asm) ทำให้คิวไม่ได้เริ่มว่างเปล่าที่ $FBF0 อีกต่อไปตอน
# test เริ่มพิมพ์ของตัวเอง -- เปลี่ยนจาก offset คงที่มือ (0xFBFC) เป็นอ่าน KEYQ_TAIL จริงแทน เพื่อความ
# ทนทาน (robust) ไม่ผูกกับความยาวของ auto-exec string ที่อาจเปลี่ยนได้อีกในอนาคต

set outf [open "/tmp/bug8_regression_out.txt" w]

proc keyq_tail {} {
    set b [debug read_block "memory" 0xF3F8 2]
    binary scan $b cu2 bytes
    set lo [lindex $bytes 0]
    set hi [lindex $bytes 1]
    return [expr {$lo + ($hi << 8) - 0xFBF0}]
}

after realtime 2.0 { type "call thaion\r" }
after realtime 3.2 {
    global base
    set base [keyq_tail]
}
after realtime 3.5 { type "Hello" }

after realtime 5.0 {
    global outf base
    set n [expr {[keyq_tail] - $base}]
    if {$n < 0} { set n [expr {$n + 40}] }
    set kbuf [debug read_block "memory" [expr {0xFBF0 + $base}] $n]
    binary scan $kbuf cu$n got
    set expect {72 101 108 108 111}
    if {$got eq $expect} {
        puts $outf "PASS: keyboard buffer after typing 'Hello' (expanded slot 0) = $got"
    } else {
        puts $outf "FAIL: keyboard buffer after typing 'Hello' (expanded slot 0) = $got (expected $expect)"
    }
    flush $outf
    close $outf
}
after realtime 5.5 { exit }
