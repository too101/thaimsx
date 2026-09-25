source [file dirname [info script]]/lib.tcl
set throttle off
set BS 0x10
set DEL 0x11
after time 6 { kstr "call thaion\r" }
after time 8 { kstr "call printon\r" }
# 10: last typed mark then BS -> only the mark goes
after time 9  { kpush [concat [str2b "10 print \""] {0xB4 0xD5} $BS 13] }
# 20: ก ด ี ค, BS BS -> ค then (ด+ี)
after time 10 { kpush [concat [str2b "20 print \""] {0xA1 0xB4 0xD5 0xA4} $BS $BS 13] }
# 30: "ดีค" then left x3 -> on ด, DEL -> "ค"
after time 11 { kpush [concat [str2b "30 print \""] {0xB4 0xD5 0xA4} [str2b "\""] {0x1D 0x1D 0x1D} $DEL 13] }
# 40: "ดีค" left x3 -> on ด, INS, type ก -> "กดีค"
after time 12 { kpush [concat [str2b "40 print \""] {0xB4 0xD5 0xA4} [str2b "\""] {0x1D 0x1D 0x1D 0x12 0xA1} 13] }
# 50: "ดค" left x2 -> on ค, INS, type ี -> "ดีค"
after time 13 { kpush [concat [str2b "50 print \""] {0xB4 0xA4} [str2b "\""] {0x1D 0x1D 0x12 0xD5} 13] }
# 60: real BS key through the keyboard matrix
after time 14 { kpush [concat [str2b "60 print \""] {0xB4 0xD5}] }
after time 14.5 { keymatrixdown 7 0x20 }
after time 14.6 { keymatrixup 7 0x20 }
after time 15 { kpush {13} }
# 70: plain BS (no PRINTON-specific) on ascii must still work
after time 15.5 { kpush [concat [str2b "70 print \"abc"] $BS [str2b "\""] 13] }
after time 16.5 {
    foreach l [dumpprog] { log "PROG $l" }
    close $::out; exit
}
