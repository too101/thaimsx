set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/findfont_out.txt" w]

after realtime 3.0 {
    global outf
    if {[catch {
        set vram [debug read_block "physical VRAM" 0 0x4000]
        set target "\x3c\x42\xa5\x81\xa5\x99\x42\x3c"
        set idx [string first $target $vram]
        puts $outf "smiley pattern found at VRAM offset: $idx (hex [format 0x%x $idx])"
        # also dump some system variable candidates
        foreach addr {0xF91F 0xF920 0xF921 0xF922 0xF923 0xF924 0xF925} {
            set v [debug read memory $addr]
            puts $outf "[format 0x%04X $addr] = [format 0x%02X $v]"
        }
    } err]} {
        puts $outf "ERROR: $err"
    }
    flush $outf
    close $outf
}
after realtime 3.2 { exit }
