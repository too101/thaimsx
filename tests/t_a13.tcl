source [file dirname [info script]]/lib.tcl
set throttle off
set INPUT_MODE 8
proc key {scan t} { set r [expr {$scan>>3}]; set b [expr {1<<($scan&7)}]; after time $t "keymatrixdown $r $b"; after time [expr {$t+0.08}] "keymatrixup $r $b" }
proc letter {ch t} { key [expr {0x16 + [scan $ch %c] - 65}] $t }
proc scr {tag} { for {set r 1} {$r <= 24} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : "."}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
# A1: GRAPH+F G I ; GRAPH+SHIFT+C  -> "FOR" "GOTO" "IF" "CLS"
after time 8.5 { kstr "10 " }
after time 8.7 { keymatrixdown 6 0x04 }
letter F 8.9
letter G 9.1
letter I 9.3
after time 9.5 { keymatrixdown 6 0x01 }
letter L 9.6
after time 9.8 { keymatrixup 6 0x01 }
after time 9.9 { keymatrixup 6 0x04 }
letter A 10.1
after time 10.5 { scr A1 }
key 0x3F 10.7
after time 11.1 { log "PROG: [dumpprog]" }
# A3: toggle thai, type 2 thai letters, Enter in direct mode -> INPUT_MODE back to 0
after time 11.5 { keymatrixdown 6 0x10 }
after time 11.6 { keymatrixup 6 0x10 }
after time 11.8 { log "after toggle INPUT_MODE=[var $INPUT_MODE]" }
letter D 12
letter F 12.2
key 0x3F 12.5
after time 13 { log "after Enter INPUT_MODE=[var $INPUT_MODE]" }
# program-mode: INPUT inside running program should NOT revert
after time 13.5 { kstr "new\r20 input a\$\r30 print len(a\$)\rrun\r" }
after time 15 { keymatrixdown 6 0x10 }
after time 15.1 { keymatrixup 6 0x10 }
letter D 15.4
key 0x3F 15.7
after time 16.3 { log "after Enter in program INPUT_MODE=[var $INPUT_MODE] CURLIN=[format %04X [rd16 0xF41C]]"; scr END; close $::out; exit }
