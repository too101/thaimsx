source [file dirname [info script]]/lib.tcl
set throttle off
after time 6 { kstr "call thaion\r" }
after time 8 { kstr "call printon\r" }
after time 9 { kpush [concat [str2b "10 print \""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5 0xA4 0xC3 0xD1 0xBA} [str2b "\"\r"]] }
after time 10 { kpush [concat [str2b "20 print \""] {0xB4 0xD5} [str2b "\r"]] }
after time 11 { kpush [concat [str2b "30 print \""] {0xB4 0xD5 0xE8} [str2b "\"\r"]] }
after time 12 { kpush [concat [str2b "40 print \""] {0xBB 0xD9 0xE8} [str2b "\"\r"]] }
after time 13 {
    log "PRINT_MODE=[rd 0xFD09] H_CHGE=[format %02X [rd 0xFDC2]] H_PINL=[format %02X [rd 0xFDDB]] H_INLI=[format %02X [rd 0xFDE5]]"
    foreach l [dumpprog] { log "PROG $l" }
    kstr "cls\r"
}
after time 14 { kstr "list\r" }
after time 15 {
    screenshot -raw /tmp/msxtest/t/shot_list.png
    for {set r 1} {$r <= 24} {incr r} { log "R$r [vramrow $r]" }
    kstr "run\r"
}
after time 16 { screenshot -raw /tmp/msxtest/t/shot_run.png; log done; close $::out; exit }
