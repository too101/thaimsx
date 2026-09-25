source [file dirname [info script]]/lib.tcl
set throttle off
proc a1 {} { set cg [rd16 0xF924]; binary scan [debug read_block VRAM [expr {$cg+0xA1*8}] 8] cu* v; return $v }
proc show {tag} {
    for {set r 1} {$r <= 24} {incr r} {
        set s ""; foreach x [vramrow $r] { set v [scan $x %x]; if {$v>=32 && $v<127} {append s [format %c $v]} elseif {$v>=128} {append s "<$x>"} else {append s " "} }
        set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" }
    }
}
after time 12 { log "boot A1=[a1]"; kstr "screen 0:width 80\r" }
after time 13 { log "after width80: LINLEN=[rd 0xF3B0] A1=[a1] (font reset by BIOS until next key wait/Thai print)"; kstr "call printon\r" }
after time 14 { log "after next input: A1=[a1]"; kpush [concat [str2b "10 print \""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5 0xBB 0xD9 0xE8} [str2b "\"\r"]] }
after time 15 { keymatrixdown 6 0x10 }
after time 15.1 { keymatrixup 6 0x10 }
after time 15.3 { kpush [concat [str2b "20 print \""] {0xA1}] }
after time 15.6 { keymatrixdown 6 0x01; keymatrixdown 2 0x01 }
after time 15.7 { keymatrixup 2 0x01; keymatrixup 6 0x01 }
after time 16 { kpush [concat [str2b "\""] {13}] }
after time 16.5 { kstr "cls\r" }
after time 17 { kstr "list\r" }
after time 18 { foreach l [dumpprog] { log "PROG $l" }; show LIST; log "cursor pat255: [lrange [binary scan [debug read_block VRAM [expr {[rd16 0xF924]+0x7F8}] 8] cu* v] 0 0] $v"; close $::out; exit }
