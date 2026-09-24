source [file dirname [info script]]/lib.tcl
set throttle off
set printerlogfilename $::env(PRN)
plug printerport logger
after time 27 { kstr "call printon\r" }
after time 28 { kstr "call lprint\r" }
after time 29 { kpush [concat [str2b "lprint \""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5 0x20 0xB9 0xE9 0xD3 0x20 0xB7 0xD5 0xE8} [str2b "\"\r"]] }
after time 30 { kstr "lprint\r" }
after time 31 { kpush [concat [str2b "lprint \"a"] {0xA1 0xD8 0xA1 0xD4 0xEC 0xDA 0xBB 0xD1 0xE9} [str2b "\";\r"]] }
after time 32 { kstr "lprint \"x\"\r" }
after time 33 { kstr "call printoff\r" }
after time 34 { kpush [concat [str2b "lprint \""] {0xCA 0xD1 0xE9} [str2b "\"\r"]] }
after time 36 { for {set r 1} {$r <= 24} {incr r} { set t ""; foreach x [vramrow $r] { scan $x %x v; append t [expr {$v>=32 && $v<127 ? [format %c $v] : "."}] }; log $t }; close $::out; exit }
