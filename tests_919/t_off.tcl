source [file dirname [info script]]/lib.tcl
set throttle off
after time 6 { kstr "call thaion\r" }
after time 8 { log "on:  KEYC=[format %02X [rd 0xFDCC]] CHPU=[format %02X [rd 0xFDA4]] CHGE=[format %02X [rd 0xFDC2]] PINL=[format %02X [rd 0xFDDB]] INLI=[format %02X [rd 0xFDE5]]"; kstr "call thaioff\r" }
after time 10 { log "off: KEYC=[format %02X [rd 0xFDCC]] CHPU=[format %02X [rd 0xFDA4]] CHGE=[format %02X [rd 0xFDC2]] PINL=[format %02X [rd 0xFDDB]] INLI=[format %02X [rd 0xFDE5]]"; kstr "10 print 1+1\r" }
after time 11 { for {set r 1} {$r <= 14} {incr r} { set s ""; foreach x [vramrow $r] { set v [scan $x %x]; if {$v>=32 && $v<127} {append s [format %c $v]} else {append s " "} }; log "R$r [string trimright $s]" }; foreach l [dumpprog] { log "PROG $l" }; close $::out; exit }
