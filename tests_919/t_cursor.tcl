source [file dirname [info script]]/lib.tcl
set throttle off
# offsets (equates.asm: $FDxx - $FD09)
set INPUT_MODE 8; set BLINK_OFF 0x4D
proc pat255 {} {
    set cg [rd16 0xF924]
    binary scan [debug read_block VRAM [expr {$cg + 0x7F8}] 8] cu* v
    set s {}; foreach x $v { lappend s [format %02X $x] }; return [join $s ""]
}
proc patof {c} {
    set cg [rd16 0xF924]
    binary scan [debug read_block VRAM [expr {$cg + $c*8}] 8] cu* v
    set s {}; foreach x $v { lappend s [format %02X $x] }; return [join $s ""]
}
# st: เก็บ pat255 6 ครั้งห่างกัน 0.15 วินาที แล้ว log ค่าที่เห็น (ไทย = 2 ค่าสลับ, อังกฤษ = ค่าเดียว)
proc st {tag t} {
    set k [lindex $tag 0]; set ::samp$k {}; set ::tag$k $tag
    for {set i 0} {$i < 6} {incr i} { after time [expr {$t + $i*0.15}] [list lappend ::samp$k {*}{}] ; after time [expr {$t + $i*0.15}] "lappend ::samp$k \[pat255\]" }
    after time [expr {$t + 0.9}] "report $k"
}
proc report {k} { log "[set ::tag$k]: INPUT_MODE=[var $::INPUT_MODE] CSTYLE=[rd 0xFCAA] CURSAV=[format %02X [rd 0xFBCC]] seen=[lsort -unique [set ::samp$k]]" }
st "1 english idle" 7
after time 8.0 { keymatrixdown 6 0x10 }
after time 8.1 { keymatrixup 6 0x10 }
st "2 thai idle (space)" 8.3
after time 9.4 { kstr "10 rem abc" }
after time 9.8 { kpush {0x1D 0x1D} }
st "3 thai on b" 10.1
after time 11.1 { log "   glyph b = [patof 98]"; kpush {0x12} }
st "4 thai INS on b" 11.3
after time 12.3 { keymatrixdown 6 0x10 }
after time 12.4 { keymatrixup 6 0x10 }
st "5 english INS on b" 12.6
after time 13.6 { kpush {0x12 0x1C 0x1C 13} }
after time 14.2 {
    foreach l [dumpprog] { log "   PROG $l" }
    close $::out; exit
}
