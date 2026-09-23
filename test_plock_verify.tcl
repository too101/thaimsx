set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/plock_verify.txt" w]
after realtime 3.0 { type "call thaion\r" }
after realtime 4.5 { type "call printoff\r" }
after realtime 6.0 { type "call plockon\r" }
after realtime 7.5 { type "call printon\r" }
after realtime 9.0 {
    global outf
    # 9.27: ตัวแปรอยู่ในบล็อกที่ pointer เก็บใน SLTWRK ช่องของ slot เรา (slot ดูจาก hook H.KEYC)
    set s [debug read memory 0xFDCD]
    set e [expr {0xFD09 + ($s&3)*32 + (($s>>2)&3)*8 + 2}]
    set wb [expr {[debug read memory $e] + 256*[debug read memory [expr {$e+1}]]}]
    set pm [debug read memory $wb]
    set pl [debug read memory [expr {$wb+1}]]
    puts $outf "PRINT_MODE=$pm PLOCK_MODE=$pl (expect PRINT_MODE=0 since PLOCKON should block)"
    flush $outf
    close $outf
}
after realtime 9.2 { exit }
