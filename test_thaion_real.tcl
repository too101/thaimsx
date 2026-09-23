set ::env(SDL_VIDEODRIVER) dummy

after realtime 3.0 {
    screenshot -prefix thaion_boot -raw
}

after realtime 3.3 {
    type "call thaion\r"
}

after realtime 5.0 {
    screenshot -prefix thaion_after -raw
}

after realtime 5.1 {
    set cgpnt_lo [debug read memory 0xF91F]
    set cgpnt_hi [debug read memory 0xF920]
    puts "CGPNT = $cgpnt_hi $cgpnt_lo"
    set thai_mode [debug read memory 0xFCAD]
    puts "THAI_MODE(0xFCAD) = $thai_mode"
    set procnm ""
    for {set i 0} {$i < 10} {incr i} {
        set b [debug read memory [expr {0xFD89 + $i}]]
        append procnm [format "%02x " $b]
    }
    puts "PROCNM bytes = $procnm"
    set vram0 ""
    for {set i 0} {$i < 16} {incr i} {
        set b [debug read "VRAM" $i]
        append vram0 [format "%02x " $b]
    }
    puts "VRAM 0-15 = $vram0"
}

after realtime 5.2 { exit }
