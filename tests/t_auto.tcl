source [file dirname [info script]]/lib.tcl
# 9.42: AUTO ตอน PRINTON ต้องเก็บบรรทัดลงโปรแกรม (BUF รวมเลขบรรทัด) ไม่ใช่ทำงานทันที
set throttle off
proc scr {tag} { for {set r 1} {$r <= 23} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : "#"}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
after time 9 { kstr "call printon\r" }
after time 10 { kstr "auto\r" }
after time 10.5 { kpush [concat [str2b "print \""] {0xA4 0xD8 0xB3} [str2b "\";\r"]] }
after time 10.4 { log "pre FSTPOS=[rd 0xFBCA],[rd 0xFBCB] CSRY=[rd 0xF3DC] CSRX=[rd 0xF3DD]" }
after time 10.9 { log "typing FSTPOS=[rd 0xFBCA],[rd 0xFBCB]" }
after time 11.5 { set b ""; for {set i 0} {$i<24} {incr i} {append b [format "%02X " [rd [expr {0xF55E+$i}]]]}; log "BUF $b"; log "AUTFLG=[rd 0xF6AA]"; scr S; kpush {3}; }
after time 12 { kstr "list\r" }
after time 12.6 { scr L; close $::out; exit }
