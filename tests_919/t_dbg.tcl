source [file dirname [info script]]/lib.tcl
set throttle off
after time 6 { kstr "call thaion\r" }
after time 8 { kstr "call printon\r" }
after time 9 { kpush [concat [str2b "40 print \""] {0xB4 0xD5 0xA4} [str2b "\""] {0x1D 0x1D 0x1D}] }
after time 10 { set r [rd 0xF3DC]; log "before INS: CSRY=$r CSRX=[rd 0xF3DD]"; foreach k {-1 0 1} { log "R[expr {$r+$k}] [lrange [vramrow [expr {$r+$k}]] 0 20]" }; kpush {0x12 0xA1} }
after time 11 { set r [rd 0xF3DC]; log "after:  CSRY=$r CSRX=[rd 0xF3DD] INS=[rd 0xFCA8]"; foreach k {-1 0 1} { log "R[expr {$r+$k}] [lrange [vramrow [expr {$r+$k}]] 0 20]" }; log "LINTTB r-1,r = [rd [expr {0xFBB1+$r-1}]] [rd [expr {0xFBB1+$r}]]"; kpush {13} }
after time 12 { foreach l [dumpprog] { log "PROG $l" }; set r [rd 0xF3DC]; log "CSRY=$r"; for {set k 1} {$k<=24} {incr k} { log "R$k [lrange [vramrow $k] 0 20]" }; close $::out; exit }
