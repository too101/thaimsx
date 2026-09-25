set ::env(SDL_VIDEODRIVER) dummy

set outf [open "/tmp/msxtest/thairom/debug_out.txt" w]

after realtime 3.0 {
    screenshot -prefix dbg_boot -raw
}

after realtime 3.3 {
    type "call thaion\r"
}

after realtime 5.0 {
    screenshot -prefix dbg_after -raw
}

after realtime 5.1 {
    global outf
    if {[catch {
        set cgpnt_lo [debug read memory 0xF91F]
        set cgpnt_hi [debug read memory 0xF920]
        puts $outf "CGPNT = hi=$cgpnt_hi lo=$cgpnt_lo"
        set thai_mode [debug read memory 0xFCAD]
        puts $outf "THAI_MODE(0xFCAD) = $thai_mode"
        set print_mode [debug read memory 0xFD09]
        puts $outf "PRINT_MODE(0xFD09) = $print_mode"
        set procnm ""
        for {set i 0} {$i < 12} {incr i} {
            set b [debug read memory [expr {0xFD89 + $i}]]
            append procnm [format "%02x " $b]
        }
        puts $outf "PROCNM bytes = $procnm"
        set pc [reg PC]
        set sp [reg SP]
        puts $outf "PC=$pc SP=$sp"
    } err]} {
        puts $outf "ERROR: $err"
    }
    if {[catch {
        puts $outf "debug list: [debug list]"
    } err2]} {
        puts $outf "ERROR2: $err2"
    }
    flush $outf
}

after realtime 5.3 {
    global outf
    if {[catch {
        set vram0 ""
        for {set i 0} {$i < 16} {incr i} {
            set b [debug read "physical VRAM" $i]
            append vram0 [format "%02x " $b]
        }
        puts $outf "physical VRAM 0-15 = $vram0"
    } err3]} {
        puts $outf "ERROR3: $err3"
    }
    flush $outf
    close $outf
}

after realtime 5.5 { exit }
