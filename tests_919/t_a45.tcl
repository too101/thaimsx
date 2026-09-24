source [file dirname [info script]]/lib.tcl
set throttle off
set THAI_MODE 9
proc scr {tag} { for {set r 1} {$r <= 23} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : "#"}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
if {[info exists ::env(HOLD)]} { keymatrixdown 6 0x10; after time 9 { keymatrixup 6 0x10 } }
after time 10 { log "THAI_MODE=[var $THAI_MODE] H_KEYC=[format %02X [rd 0xFDCC]]"; kstr "call system\r" }
after time 11 { scr S; close $::out; exit }
