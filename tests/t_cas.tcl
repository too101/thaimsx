source [file dirname [info script]]/lib.tcl
# 9.43: BLOAD"CAS:",R จากเทป (เครื่องไม่มีดิสก์)
set throttle off
proc scr {tag} { for {set r 1} {$r <= 24} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : "#"}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
cassetteplayer insert [file dirname [info script]]/../build/THAIMSX.CAS
# openMSX พิมพ์ BLOAD"CAS:",R ให้เองตอนใส่เทป (autorun)
after time 120 { kstr "?fre(0)\r" }
after time 121 { scr A; kstr "call printon\r" }
after time 122 { kpush [concat [str2b "10 ?\""] {0xA4 0xD8 0xB3 0xAA 0xD7 0xE8 0xCD} [str2b "\"\r"]] }
after time 122.6 { kstr "list\r" }
after time 123.5 { kstr "run\r" }
after time 124.5 { scr B; close $::out; exit }
