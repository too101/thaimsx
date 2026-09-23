source [file dirname [info script]]/lib.tcl
set throttle off
proc rep {lst n} { set r {}; for {set i 0} {$i<$n} {incr i} { set r [concat $r $lst] }; return $r }
proc show {tag} {
    set th [dict create 0xCA ส 0xC7 ว 0xD1 ั 0xB4 ด 0xD5 ี 0xA1 ก 0xA4 ค 0xC3 ร 0xBB ป 0xD9 ู 0xE8 ่ 0xFF █]
    for {set r 1} {$r <= 24} {incr r} {
        set s ""; foreach x [vramrow $r] { set v [scan $x %x]; set k [format 0x%02X $v]; if {[dict exists $th $k]} {append s [dict get $th $k]} elseif {$v>=32 && $v<127} {append s [format %c $v]} else {append s "?"} }
        set s [string trimright $s]; if {$s ne ""} { log "$tag R[format %02d $r] |$s" }
    }
}
set SWD {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5}
after time 12 { kstr "call printon\r" }
# T1: long line with marks, 8x "สวัสดี" (32 cols) after 10 print "
after time 13 { kpush [concat [str2b "10 print \""] [rep $::SWD 4]] }
after time 13.5 { kpush [concat [rep $::SWD 4] [str2b "\"\r"]] }
# T2: consonant exactly at last column, then vowel (mark goes to previous row), then more
after time 14.5 { kpush [concat [str2b "20 print \""] [rep {0xA1} 26]] }
after time 15   { kpush [concat {0xB4 0xD5 0xA4} [str2b "\"\r"]] }
after time 16 { foreach l [dumpprog] { log "P1 $l" }; show S1; kstr "cls\r" }
after time 16.5 { kstr "list\r" }
after time 17.5 { show LIST }
# T3: move cursor up onto second (continuation) row of line 10 and press Enter -> must store same bytes
after time 18 {
    set target 0
    for {set r 1} {$r <= 24} {incr r} { if {[string match "*31 30 20 50 52 49 4E 54*" [vramrow $r]]} { set target $r } }
    set cy [rd 0xF3DC]; set k {}
    for {set i 0} {$i < $cy - ($target+3)} {incr i} { lappend k 0x1E }
    kstr "new\r"
    after time 1 [list kpush [concat $k 13]]
}
after time 20 { foreach l [dumpprog] { log "P2 $l" } ; kstr "cls\r" }
# T4: BS at start of continuation row, T5: DEL across rows, T6: INS across rows / new row
after time 21 { kpush [concat [str2b "30 print \""] [rep {0xA1} 27] {0xB4 0x10 0x10} [str2b "\"\r"]] }
after time 22 { kpush [concat [str2b "40 print \""] [rep {0xA1} 26] {0xB4 0xD5 0xA4 0xC3} [str2b "\""] [rep {0x1D} 32]] }
after time 22.8 { kpush {0x11 13} }
after time 23.5 { kpush [concat [str2b "50 print \""] [rep {0xA1} 26] [rep {0x1D} 26] {0x12 0xB4 0xC3} 13] }
after time 24.5 { foreach l [dumpprog] { log "P3 $l" }; show S3; close $::out; exit }
