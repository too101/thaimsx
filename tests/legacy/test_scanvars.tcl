set ::env(SDL_VIDEODRIVER) dummy
set outf [open "/tmp/msxtest/thairom/scanvars_out.txt" w]
after realtime 3.0 {
    global outf
    if {[catch {
        for {set a 0xF91E} {$a < 0xF940} {incr a} {
            set v [debug read memory $a]
            puts $outf "[format 0x%04X $a] = [format 0x%02X $v]"
        }
    } err]} { puts $outf "ERROR: $err" }
    flush $outf
    close $outf
}
after realtime 3.2 { exit }
