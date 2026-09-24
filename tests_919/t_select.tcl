source [file dirname [info script]]/lib.tcl
set throttle off
set PRINT_MODE 0
proc key {scan t} { set r [expr {$scan>>3}]; set b [expr {1<<($scan&7)}]; after time $t "keymatrixdown $r $b"; after time [expr {$t+0.08}] "keymatrixup $r $b" }
proc scr {tag} { for {set r 1} {$r <= 23} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : ($v==32?" ":"#")}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
after time 9 { kstr "print 1" }
key 0x3E 9.5
after time 9.9 { log "after SELECT: PRINT_MODE=[var $PRINT_MODE] CSRY=[rd 0xF3DC] CSRX=[rd 0xF3DD]"; scr S1; kpush [concat [str2b "?\""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} [str2b "\"\r"]] }
after time 10.6 { scr S2; foreach r {1 2 3 4 5 6} { log "V$r [lrange [vramrow $r] 0 12]" } }
key 0x3E 11
after time 11.4 { log "after SELECT2: PRINT_MODE=[var $PRINT_MODE] CSRY=[rd 0xF3DC]"; scr S3; kstr "call plockon\r" }
key 0x3E 12.2
after time 12.6 { log "after SELECT with PLOCK: PRINT_MODE=[var $PRINT_MODE]"; scr S4; close $::out; exit }
