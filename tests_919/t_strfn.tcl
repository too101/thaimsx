source [file dirname [info script]]/lib.tcl
set throttle off
proc scr {tag} { for {set r 1} {$r <= 23} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : [format {<%02X>} $v]}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
after time 8 { kpush [concat [str2b "5 a\$=\"AB"] {0xF1 0xF2} [str2b "3\"\r"]] }
after time 8.3 { kstr "10 call anstr(a\$,b\$):?b\$;len(b\$)\r" }
after time 8.6 { kpush [concat [str2b "20 call tnstr(\"x12\"+\"0\",c\$):?c\$\r"]] }
after time 9.2 { kpush [concat [str2b "30 call mlstr(\""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5 0xE8} [str2b "\",d\$):?len(d\$)\r"]] }
after time 9.8 { kstr "40 call mlstr(\"\",e\$):?len(e\$)\r" }
after time 10.4 { kstr "cls:run\r" }
after time 11.4 { kstr "call anstr(1,b\$)\r" }
after time 12 { kstr "call anstr(\"1\",z)\r" }
after time 12.6 { kstr "call anstr \"1\"\r" }
after time 13.2 { kstr "?fre(\"\")\r" }
after time 13.8 { scr S; close $::out; exit }
