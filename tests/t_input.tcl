source [file dirname [info script]]/lib.tcl
set throttle off
after time 6 { kstr "call thaion\r" }
after time 8 { kstr "call printon\r" }
after time 9 { kstr {50 input a$:for i=1 to len(a$)} }
after time 10 { kstr ":print asc(mid\$(a\$,i,1));:next\r" }
after time 11 { kstr "run\r" }
after time 12 { kpush {0xB4 0xD5 0xE8 13} }
after time 13 {
    for {set r 1} {$r <= 24} {incr r} {
        set s ""
        foreach x [vramrow $r] { set v [scan $x %x]; if {$v>=32 && $v<127} {append s [format %c $v]} elseif {$v==0} {append s " "} else {append s "<$x>"} }
        set s [string trimright $s]
        if {$s ne ""} { log "R$r $s" }
    }
    close $::out; exit
}
