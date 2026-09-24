source [file dirname [info script]]/lib.tcl
set throttle off
proc g {c} { set cg [rd16 0xF924]; binary scan [debug read_block VRAM [expr {$cg + $c*8}] 8] cu* v; return $v }
proc key {scan t} { set r [expr {$scan>>3}]; set b [expr {1<<($scan&7)}]; after time $t "keymatrixdown $r $b"; after time [expr {$t+0.08}] "keymatrixup $r $b" }
after time 9 { kpush [concat [str2b "10 rem "] {0xCA 0xC7 0xB4 0xD5} {13}]; log "on A1=[g 0xA1] 41=[g 0x41]" }
key 0x34 9.5
after time 9.8 { kstr "call thaioff\r" }
after time 11 { log "off A1=[g 0xA1] 41=[g 0x41] F91F=[format %02X [rd 0xF91F]]:[format %04X [rd16 0xF920]] H_KEYC=[format %02X [rd 0xFDCC]] rows: [lrange [vramrow 6] 0 12]" }
key 0x16 11.2
after time 11.5 { log "typed after off: [lrange [vramrow [rd 0xF3DC]] 0 4]"; close $::out; exit }
