source [file dirname [info script]]/lib.tcl
set throttle off
proc rep {lst n} { set r {}; for {set i 0} {$i<$n} {incr i} { set r [concat $r $lst] }; return $r }
proc show {tag} {
    set th [dict create 0xCA ส 0xC7 ว 0xD1 ั 0xB4 ด 0xD5 ี 0xA1 ก 0xA4 ค 0xC3 ร 0xBB ป 0xD9 ู 0xE8 ่ 0xFF █ 0x8E ี่]
    for {set r 1} {$r <= 24} {incr r} {
        set s ""; foreach x [vramrow $r] { set v [scan $x %x]; set k [format 0x%02X $v]; if {[dict exists $th $k]} {append s [dict get $th $k]} elseif {$v>=32 && $v<127} {append s [format %c $v]} else {append s "?"} }
        set s [string trimright $s]; if {$s ne ""} { log "$tag R[format %02d $r] |$s" }
    }
}
proc findrow {pat} { set t 0; for {set r 1} {$r <= 24} {incr r} { if {[string match "*$pat*" [vramrow $r]]} { set t $r } }; return $t }
set T $::env(TEST)
after time 12 { kstr "call printon\r" }
if {$T eq "ghost"} {
  after time 13 { kpush [concat [str2b "20 print \""] [rep {0xA1} 26]] }
  after time 13.5 { kpush [concat {0xB4 0xD5 0xE8 0xA4} [str2b "\"\r"]] }
  after time 14.5 { foreach l [dumpprog] { log "PROG $l" }; show S; close $::out; exit }
}
if {$T eq "enter2"} {
  after time 13 { kpush [concat [str2b "10 print \""] [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 4]] }
  after time 13.5 { kpush [concat [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 4] [str2b "\"\r"]] }
  after time 14.5 { kstr "cls\r" }
  after time 15 { kstr "list\r" }
  after time 16 { kstr "10\r" }
  after time 16.5 { foreach l [dumpprog] { log "AFTER DELETE: $l" }; set t [findrow "31 30 20 50 52 49 4E 54"]; set cy [rd 0xF3DC]; log "line10 row=$t cursor=$cy"; set k {}; for {set i 0} {$i < ($cy - ($t+3))/3} {incr i} { lappend k 0x1E }; lappend k 13; kpush $k }
  after time 17.5 { foreach l [dumpprog] { log "PROG $l" }; show S; close $::out; exit }
}
if {$T eq "bs"} {
  after time 13 { kpush [concat [str2b "30 print \""] [rep {0xA1} 27] {0xB4}] }
  after time 13.5 { kpush {0x10 0x10} }
  after time 14 { kpush [concat [str2b "\""] 13] }
  after time 14.5 { foreach l [dumpprog] { log "PROG $l" }; show S; close $::out; exit }
}
if {$T eq "del"} {
  after time 13 { kpush [concat [str2b "40 print \""] [rep {0xA1} 26]] }
  after time 13.3 { kpush {0xB4 0xD5 0xA4 0xC3} }
  after time 13.6 { kpush [concat [str2b "\""] [rep {0x1D} 30]] }
  after time 14 { show BEFORE; kpush {0x11} }
  after time 14.5 { show AFTERDEL; kpush {13} }
  after time 15 { foreach l [dumpprog] { log "PROG $l" }; close $::out; exit }
}
if {$T eq "ins"} {
  after time 13 { kpush [concat [str2b "50 print \""] [rep {0xA1} 26]] }
  after time 13.3 { kpush {0xB4 0xD5} }
  after time 13.5 { kpush [concat [rep {0x1D} 26] {0x12}] }
  after time 14 { kpush {0xBB 0xC3} }
  after time 14.5 { show AFTERINS; kpush {13} }
  after time 15 { foreach l [dumpprog] { log "PROG $l" }; show S; close $::out; exit }
}
if {$T eq "prog"} {
  after time 13 { kpush [concat [str2b "10 for i=1 to 5:print \""] [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 2]] }
  after time 13.15 { kpush [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 1] }
  after time 13.3 { kpush [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 5] }
  after time 13.6 { kpush [concat [rep {0xBB 0xD9 0xE8} 8] [str2b "\";i:next\r"]] }
  after time 14.5 { kstr "cls:run\r" }
  after time 16 { foreach l [dumpprog] { log "PROG $l" }; show S; close $::out; exit }
}

if {$T eq "deldbg"} {
  after time 13 { kpush [concat [str2b "40 print \""] [rep {0xA1} 26] {0xB4 0xD5 0xA4 0xC3}] }
  after time 13.5 { show A; kpush [concat [str2b "\""]] }
  after time 13.8 { show B; kpush [rep {0x1D} 5] }
  after time 14.2 { show C; log "CSRY=[rd 0xF3DC] CSRX=[rd 0xF3DD]"; kpush {0x1D} }
  after time 14.5 { show D; log "CSRY=[rd 0xF3DC] CSRX=[rd 0xF3DD]"; close $::out; exit }
}

if {$T eq "bottom"} {
  after time 13 { kpush {13 13 13 13 13 13} }
  after time 13.5 { log "cursor row before typing: [rd 0xF3DC]"; kpush [concat [str2b "60 print \""] [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 4]] }
  after time 13.8 { kpush [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 3] }
  after time 14.1 { kpush [concat [rep {0xBB 0xD9 0xE8} 6] [str2b "\"\r"]] }
  after time 14.6 { foreach l [dumpprog] { log "PROG $l" }; show S; kstr "list\r" }
  after time 15.5 { show L; close $::out; exit }
}
