set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/phase3_probe.txt" w]

after realtime 3.0 { type "call thaion\r" }
after realtime 4.8 {
    global outf
    set prevk [debug read_block "memory" 0xFD0B 3]
    binary scan $prevk c3 pk
    puts $outf "after THAION, PREV_KEYC = $pk"
    flush $outf
}
after realtime 5.0 { type "print 1+1\r" }
after realtime 6.0 {
    global outf
    puts $outf "reg PC after print attempt = [reg PC]"
    flush $outf
    screenshot -prefix probe -raw
}
after realtime 6.3 { close $outf }
after realtime 6.5 { exit }
