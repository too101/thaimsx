source [file dirname [info script]]/lib.tcl
set throttle off
after time 12 {
    for {set r 1} {$r <= 8} {incr r} {
        set s ""; foreach x [vramrow $r] { set v [scan $x %x]; if {$v>=32 && $v<127} {append s [format %c $v]} else {append s " "} }
        log "R$r [string trimright $s]"
    }
    log "THAI_MODE=[rd 0xFD12] H_READ=[format %02X [rd 0xFF07]] H_KEYC=[format %02X [rd 0xFDCC]] H_CHPU=[format %02X [rd 0xFDA4]] KEYQ empty=[expr {[rd 0xF3F8]==[rd 0xF3FA]}]"
    set cg [rd16 0xF924]; binary scan [debug read_block VRAM [expr {$cg+0xA1*8}] 8] cu* v; log "glyph A1 (ko kai) in VRAM: $v"
    kstr "call printon\r"
}
after time 13 { kpush [concat [str2b "10 print \""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} [str2b "\"\r"]] }
after time 14 { foreach l [dumpprog] { log "PROG $l" }; close $::out; exit }
