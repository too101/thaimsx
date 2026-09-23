set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/plock_verify.txt" w]
after realtime 3.0 { type "call thaion\r" }
after realtime 4.5 { type "call printoff\r" }
after realtime 6.0 { type "call plockon\r" }
after realtime 7.5 { type "call printon\r" }
after realtime 9.0 {
    global outf
    set pm [debug read memory 0xFD09]
    set pl [debug read memory 0xFD0A]
    puts $outf "PRINT_MODE=$pm PLOCK_MODE=$pl (expect PRINT_MODE=0 since PLOCKON should block)"
    flush $outf
    close $outf
}
after realtime 9.2 { exit }
