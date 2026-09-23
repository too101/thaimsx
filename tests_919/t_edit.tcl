source [file dirname [info script]]/lib.tcl
set throttle off
after time 6 { kstr "call thaion\r" }
after time 8 { kstr "call printon\r" }
after time 9 { kpush [concat [str2b "10 print \""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5 0xA4 0xC3 0xD1 0xBA} [str2b "\"\r"]] }
after time 10 { kstr "cls\r" }
after time 11 { kstr "list\r" }
after time 12 { kstr "new\r" }
after time 13 {
    foreach l [dumpprog] { log "AFTER NEW: $l" }
    # find the row that holds "10 PRINT"
    set target 0
    for {set r 1} {$r <= 24} {incr r} { if {[string match "*31 30 20 50 52 49 4E 54*" [vramrow $r]]} { set target $r } }
    set cy [rd 0xF3DC]
    log "line10 row=$target cursor row=$cy"
    set k {}
    for {set i 0} {$i < ($cy - $target)/3} {incr i} { lappend k 0x1E }
    lappend k 13
    kpush $k
}
after time 14 { foreach l [dumpprog] { log "AFTER EDIT-ENTER: $l" }; close $::out; exit }
