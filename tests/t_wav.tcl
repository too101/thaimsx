source [file dirname [info script]]/lib.tcl
# 9.44: โหลดจากไฟล์เสียง .WAV (จำลองการเล่นเทปจริงเข้าเครื่อง) -- WAV=path ของไฟล์
set throttle off
proc scr {tag} { for {set r 1} {$r <= 24} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : "#"}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
cassetteplayer insert $::env(WAV)
after time 6 { kstr "bload\"cas:\",r\r" }
after time 150 { kstr "?fre(0)\r" }
after time 151 { kpush [concat [str2b "call tnstr(\"2568\",a$):?asc(a$)\r"]] }
after time 152 { scr A; close $::out; exit }
