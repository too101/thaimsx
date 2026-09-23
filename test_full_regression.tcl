set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/regression_out.txt" w]

# หมายเหตุ (Phase 3): หลังจาก "call thaion" ทำงานเสร็จ H.KEYC hook (src/keyboard.asm) จะ
# ติดตั้งอยู่จนกว่าจะ thaioff -- openMSX's `type` (= type_via_keyboard, จำลอง matrix จริง)
# ไวต่อ latency ของ interrupt-driven keyboard scan ที่ H.KEYC เป็นส่วนหนึ่ง (พบระหว่างทดสอบ
# Phase 3 จริง ดู SPEC_TH.md section 9.8 และ src/keyboard.asm หัวข้อ 4) จึงใช้
# `type_via_keybuf` (poke ตัวอักษรเข้า keyboard buffer ตรง ๆ ไม่ผ่าน matrix scan) แทน
# สำหรับคำสั่งทุกตัวที่พิมพ์ "หลัง" thaion เพื่อเลี่ยงข้อจำกัดนี้ของตัวจำลองเอง -- ก่อน
# thaion (ยังไม่ติดตั้ง hook) ใช้ `type` ปกติได้ตามเดิม

after realtime 3.0 { screenshot -prefix reg_boot -raw }
after realtime 3.3 { type "call thaion\r" }
after realtime 4.8 {
    global outf
    if {[catch {
        set pat [debug read_block "physical VRAM" 0x0800 2040]
        set fontfile [open "/tmp/msxtest/thairom/assets/font_raw.bin" rb]
        set expect [read $fontfile]
        close $fontfile
        if {$pat eq $expect} {
            puts $outf "FONT MATCH: OK (pattern table 0x0800 matches font_raw.bin exactly)"
        } else {
            puts $outf "FONT MISMATCH!"
            binary scan $pat c2040 patbytes
            binary scan $expect c2040 expbytes
            set diffcount 0
            for {set i 0} {$i < 2040} {incr i} {
                if {[lindex $patbytes $i] != [lindex $expbytes $i]} {
                    incr diffcount
                    if {$diffcount < 10} {
                        puts $outf "  diff at $i: got [lindex $patbytes $i] want [lindex $expbytes $i]"
                    }
                }
            }
            puts $outf "total diffs: $diffcount / 2040"
        }
    } err]} { puts $outf "ERROR: $err" }
    set hk [debug read_block "memory" 0xFDCC 1]
    binary scan $hk cu hkv
    puts $outf "H_KEYC opcode after thaion = $hkv (expect 247 = 0xF7 RST 30H -- การออกแบบใหม่ CALLF, hook ติดตั้ง)"
    flush $outf
}
after realtime 4.9 { screenshot -prefix reg_after_thaion -raw }
after realtime 5.1 { type_via_keybuf "call printon\r" }
after realtime 5.4 { screenshot -prefix reg_after_printon -raw }
after realtime 5.6 { type_via_keybuf "call printoff\r" }
after realtime 5.9 { screenshot -prefix reg_after_printoff -raw }
after realtime 6.1 { type_via_keybuf "call plockon\r" }
after realtime 6.4 { screenshot -prefix reg_after_plockon -raw }
after realtime 6.6 { type_via_keybuf "call thaioff\r" }
after realtime 7.3 {
    global outf
    set hk [debug read_block "memory" 0xFDCC 1]
    binary scan $hk cu hkv
    puts $outf "H_KEYC opcode after thaioff = $hkv (expect 201 = 0xC9 RET -- hook removed)"
    flush $outf
}
after realtime 7.4 { screenshot -prefix reg_after_thaioff -raw }
after realtime 7.6 {
    global outf
    puts $outf "final PC=[reg PC]"
    flush $outf
    close $outf
}
after realtime 7.8 { exit }
