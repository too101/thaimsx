source [file dirname [info script]]/lib.tcl
set throttle off
file delete /tmp/d.dsk
diskmanipulator create /tmp/d.dsk 720k
diska /tmp/d.dsk
after time 12 { kstr "10 print \"\xCA\xC7\xD1\xCA\xB4\xD5\"\r" }
after time 13 { kstr "save\"a\"\r" }
after time 16 { kstr "new\r" }
after time 17 { kstr "load\"a\"\r" }
after time 20 { log "PROG after load: [dumpprog]"; kstr "open\"f\"for output as#1\r" }
after time 21 { kstr "print#1,\"hello\":close\r" }
after time 23 { kstr "open\"f\"for input as#1\r" }
after time 24 { kstr "input#1,a$:close:?a$\r" }
after time 26 { kstr "files\r" }
after time 28 { for {set r 1} {$r <= 24} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : "."}] }; log "R$r $s" }; close $::out; exit }
