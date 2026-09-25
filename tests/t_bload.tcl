source [file dirname [info script]]/lib.tcl
# 9.43: BLOAD"THAIMSX.BIN",R จากดิสก์ (ไม่มีตลับ) -- ต้องมี -ext PhilipsDisk
set throttle off
proc scr {tag} { for {set r 1} {$r <= 24} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : "#"}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
set d /tmp/bload_$::env(M).dsk
file delete $d
diskmanipulator create $d 720k
diska $d
diskmanipulator import diska [file dirname [info script]]/../build/THAIMSX.BIN
after time 12 { log "before FRE=[rd16 0xF6C6]"; kstr "?fre(0)\r" }
after time 13 { kstr "bload\"thaimsx.bin\",r\r" }
after time 16 { kstr "?fre(0)\r" }
after time 17 { scr A; kstr "call printon\r" }
after time 18 { kpush [concat [str2b "10 ?\""] {0xA4 0xD8 0xB3 0xAA 0xD7 0xE8 0xCD} [str2b "\"\r"]] }
after time 18.6 { kstr "save\"t\"\r" }
after time 20 { kstr "new\r" }
after time 20.5 { kstr "load\"t\"\r" }
after time 22 { kstr "list\r" }
after time 23 { scr B; kstr "call printoff\r" }
after time 23.5 { kpush [concat [str2b "call tnstr(\"2568\",a$):?a$;len(a$)\r"]] }
after time 24.5 { kstr "bload\"thaimsx.bin\",r\r" }
after time 26 { kstr "files\r" }
after time 27.5 { scr C; close $::out; exit }
