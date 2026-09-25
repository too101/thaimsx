set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/phase3_full_out.txt" w]

# ก่อน THAION: hook table ควรยังเป็นค่า default (RET)
after realtime 3.0 {
    global outf
    set d [debug read_block "memory" 0xFDCC 1]
    binary scan $d cu v
    puts $outf "1) before THAION: H_KEYC opcode = $v (expect 201 = 0xC9 RET)"
    flush $outf
}

# ใช้ type ปกติ (matrix simulation) เพื่อพิมพ์ thaion เอง -- ก่อนติดตั้ง hook ยังปลอดภัย
after realtime 3.3 { type "call thaion\r" }

after realtime 5.0 {
    global outf
    set d [debug read_block "memory" 0xFDCC 3]
    binary scan $d cu3 v
    puts $outf "2) after THAION: H_KEYC bytes = $v (expect 195=0xC3 then addr of KEYC_HOOK)"
    flush $outf
}

# จากนี้ไป hook ติดตั้งแล้ว -- ใช้ type_via_keybuf (poke ตรงเข้า keyboard buffer ไม่ผ่าน
# matrix scan) เพื่อเลี่ยงความไวต่อ latency ของการจำลอง matrix ใน openMSX เอง (ดู
# src/keyboard.asm หัวข้อ 4 และ SPEC_TH.md section 9.8)
after realtime 5.2 { type_via_keybuf "print 111+222\r" }

after realtime 5.6 {
    global outf
    puts $outf "3) typed 'print 111+222' via keybuf after hook install"
    screenshot -prefix p3full_a -raw
    flush $outf
}

after realtime 5.8 { type_via_keybuf "call printon\r" }
after realtime 6.2 { type_via_keybuf "call printoff\r" }
after realtime 6.6 { type_via_keybuf "call plockon\r" }
after realtime 7.0 { type_via_keybuf "call thaioff\r" }

after realtime 7.4 {
    global outf
    set d [debug read_block "memory" 0xFDCC 1]
    binary scan $d cu v
    puts $outf "4) after THAIOFF: H_KEYC opcode = $v (expect 201 = 0xC9 RET, restored)"
    screenshot -prefix p3full_b -raw
    flush $outf
}

# hook ควรถูกถอดแล้ว -- ทดสอบว่า `type` ปกติ (matrix) กลับมาใช้งานได้ตามเดิม
after realtime 7.6 { type "print 4+4\r" }
after realtime 8.0 {
    global outf
    screenshot -prefix p3full_c -raw
    puts $outf "final PC=[reg PC]"
    flush $outf
    close $outf
}
after realtime 8.3 { exit }
