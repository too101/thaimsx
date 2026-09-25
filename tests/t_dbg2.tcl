source [file dirname [info script]]/lib.tcl
set throttle off
proc rep {lst n} { set r {}; for {set i 0} {$i<$n} {incr i} { set r [concat $r $lst] }; return $r }
proc show {tag} {
    for {set r 1} {$r <= 24} {incr r} {
        set s ""; foreach x [vramrow $r] { set v [scan $x %x]; if {$v>=32 && $v<127} {append s [format %c $v]} elseif {$v==0xA1} {append s "k"} else {append s "?"} }
        set s [string trimright $s]; if {$s ne ""} { log "$tag R[format %02d $r] |$s" }
    }
    set lt {}; for {set r 1} {$r<=24} {incr r} { lappend lt [format %02X [rd [expr {0xFBB1+$r}]]] }
    log "$tag LINTTB $lt  CSRY=[rd 0xF3DC] CSRX=[rd 0xF3DD] PRINT_ROW=[wv 0xFD18] WRAP=[wv 0xFD48]"
}
after time 12 { kstr "call printon\r" }
after time 13 { kpush [concat [str2b "10 print \""] [rep {0xA1} 26]] }
after time 13.5 { show A }
after time 13.6 { kpush {0xA1} }
after time 14 { show B }
after time 14.1 { kpush {0xA1 0xA1} }
after time 14.5 { show C }
after time 14.6 { kpush [concat [str2b "\""] 13] }
after time 15 { show D; foreach l [dumpprog] { log "PROG $l" }; close $::out; exit }
