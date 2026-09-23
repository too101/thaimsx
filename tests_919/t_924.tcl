source [file dirname [info script]]/lib.tcl
set throttle off
after time 12 {
    set r 1; set found ""
    for {set r 1} {$r <= 6} {incr r} { set row [vramrow $r]; if {[string match "*42 41 53 49 43 20*" $row]} { set found $row } }
    log "banner row: [lrange $found 0 25]"
    keymatrixdown 6 0x10
}
after time 12.1 { keymatrixup 6 0x10 }
after time 12.3 { kstr "10 rem " }
after time 12.6 { keymatrixdown 2 0x01 }
after time 12.7 { keymatrixup 2 0x01 }
after time 12.9 { keymatrixdown 6 0x01; keymatrixdown 2 0x01 }
after time 13.0 { keymatrixup 2 0x01; keymatrixup 6 0x01 }
after time 13.3 { kpush {13} }
after time 13.8 { foreach l [dumpprog] { log "PROG $l" }; close $::out; exit }
