source [file dirname [info script]]/lib.tcl
set throttle off
# 9.41: หลัง CLS ตอน PRINTON บรรทัดแรกต้องอยู่แถว 2 (มีแถวสระบน) -- ทั้ง direct mode, ในโปรแกรม+INPUT และ HOME
after time 9 { kstr "call printon\r" }
after time 10 { kpush [concat [str2b "cls:?\""] {0xA4 0xD8 0xB3 0xAA 0xD7 0xE8 0xCD} [str2b "\"\r"]] }
after time 11 { log "A CSRY=[rd 0xF3DC]"; foreach r {1 2 3 4 5 6} { log "A$r [lrange [vramrow $r] 0 8]" } }
after time 11.2 { kpush [concat [str2b "10 cls:input\""] {0xA4 0xD8 0xB3 0xAA 0xD7 0xE8 0xCD} [str2b "\";a$\r"]] }
after time 12 { kstr "run\r" }
after time 13 { log "B CSRY=[rd 0xF3DC] CSRX=[rd 0xF3DD]"; foreach r {1 2 3 4} { log "B$r [lrange [vramrow $r] 0 10]" } ; kpush {0xA4 0xD8 0x0D} }
after time 14 { log "C CSRY=[rd 0xF3DC]"; foreach r {1 2 3 4 5 6 7 8} { log "C$r [lrange [vramrow $r] 0 10]" }; close $::out; exit }
