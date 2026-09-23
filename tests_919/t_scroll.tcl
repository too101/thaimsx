source [file dirname [info script]]/lib.tcl
set throttle off
proc textrows {} {
    set res {}
    for {set r 1} {$r <= 24} {incr r} {
        set s ""
        foreach x [vramrow $r] { set v [scan $x %x]; if {$v>32 && $v<127} {append s [format %c $v]} elseif {$v>=128} {append s "<$x>"} else {append s " "} }
        set s [string trim $s]
        if {$s ne ""} { lappend res "R$r:$s" }
    }
    return $res
}
after time 6 { kstr "call thaion\r" }
after time 8 { kstr "call printon\r" }
after time 9 { kpush [concat [str2b "10 for i=1 to 9:print i;\""] {0xB4 0xD5 0xBB 0xD9} [str2b "\":next\r"]] }
after time 10 { kstr "run\r" }
after time 12 { foreach l [textrows] { log "RUN $l" }; for {set k 1} {$k<=6} {incr k} { log "RAW R$k [vramrow $k]" }; log "CSRY=[rd 0xF3DC] bottom=[expr {([rd 0xF3B1]+[rd 0xF3DE])&255}]"; kstr "? 1\r" }
after time 13 { kstr "? 2\r" }
after time 14 { foreach l [textrows] { log "AFTER $l" }; log "CSRY=[rd 0xF3DC]"; close $::out; exit }
