source [file dirname [info script]]/lib.tcl
set throttle off
proc key {scan t} { set r [expr {$scan>>3}]; set b [expr {1<<($scan&7)}]; after time $t "keymatrixdown $r $b"; after time [expr {$t+0.08}] "keymatrixup $r $b" }
proc scr {tag} { for {set r 1} {$r <= 23} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : [format {<%02X>} $v]}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
# line 10: normal a, CAPS on a, CAPS off
after time 9 { kstr "10 rem " }
key 0x34 9.3
key 0x16 9.5
key 0x33 9.7
key 0x16 9.9
key 0x33 10.1
key 0x16 10.3
key 0x3F 10.6
# line 20: hold $15 + J ; shift + hold $15 + O ; plain $15
after time 11 { kstr "20 rem " }
key 0x34 11.3
after time 11.5 { keymatrixdown 2 0x20 }
key 0x20 11.6
after time 11.8 { keymatrixup 2 0x20 }
after time 12.0 { keymatrixdown 6 0x01; keymatrixdown 2 0x20 }
key 0x25 12.1
after time 12.3 { keymatrixup 2 0x20; keymatrixup 6 0x01 }
key 0x15 12.5
key 0x3F 12.8
# line 30: shift+7 ; sara am key (scan $1A) ; na + tone + sara am
after time 13.2 { kstr "30 rem " }
key 0x34 13.5
after time 13.7 { keymatrixdown 6 0x01 }
key 0x07 13.8
after time 14.0 { keymatrixup 6 0x01 }
key 0x1A 14.2
key 0x3F 14.5
after time 15 { foreach l [dumpprog] { log "PROG $l" }; kstr "call printon\r" }
after time 16 { kpush [concat [str2b "?\""] {0xB9 0xE9 0xED 0xD2 0xB9 0xE9 0xD3} [str2b "\"\r"]] }
after time 16.8 { scr S; foreach r {1 2 3 4 5 6 7 8} { log "V$r [lrange [vramrow $r] 0 12]" }; close $::out; exit }
