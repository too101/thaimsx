source [file dirname [info script]]/lib.tcl
set throttle off
proc pat255 {} {
    set cg [rd16 0xF924]
    binary scan [debug read_block VRAM [expr {$cg + 0x7F8}] 8] cu* v
    set s {}; foreach x $v { lappend s [format %02X $x] }; return $s
}
proc patof {c} {
    set cg [rd16 0xF924]
    binary scan [debug read_block VRAM [expr {$cg + $c*8}] 8] cu* v
    set s {}; foreach x $v { lappend s [format %02X $x] }; return $s
}
proc cell {} { set base [rd16 0xF922]; return [format %02X [lindex [binary scan [debug read_block VRAM [expr {$base + ([rd 0xF3DC]-1)*40 + [rd 0xF3DD]}] 1] cu v] 0]] }
proc st {tag} { log "$tag: INPUT_MODE=[rd 0xFD11] CSTYLE=[rd 0xFCAA] WAIT=[rd 0xFD36] ACTIVE=[rd 0xFD37] REAL=[format %02X [rd 0xFD38]] CURSAV=[format %02X [rd 0xFBCC]] pat255=[pat255]" }
after time 6 { kstr "call thaion\r" }
after time 8 { st "1 english idle" }
after time 8.2 { keymatrixdown 6 0x10 }
after time 8.3 { keymatrixup 6 0x10 }
after time 8.6 { st "2 toggled->thai while waiting" }
after time 8.8 { kstr "10 rem abc" }
after time 9.2 { kpush {0x1D 0x1D} }
after time 9.6 { st "3 thai, cursor on b"; log "   pattern of b = [patof 98]" }
after time 9.8 { kpush {0x12} }
after time 10.2 { st "4 thai INS on b" }
after time 10.4 { keymatrixdown 6 0x10 }
after time 10.5 { keymatrixup 6 0x10 }
after time 10.8 { st "5 toggled->english INS on b" }
after time 11 { kpush {0x12 0x1C 0x1C 13} }
after time 11.6 {
    st "6 after enter"; foreach l [dumpprog] { log "   PROG $l" }
    set r [expr {[rd 0xF3DC]-1}]
    log "   row above: [lrange [vramrow $r] 0 12]"
    set r [expr {[rd 0xF3DC]-2}]
    log "   2 rows above: [lrange [vramrow $r] 0 12]"
    close $::out; exit
}
