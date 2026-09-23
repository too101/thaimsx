source [file dirname [info script]]/lib.tcl
set throttle off
proc rep {lst n} { set r {}; for {set i 0} {$i<$n} {incr i} { set r [concat $r $lst] }; return $r }
proc lt {} { set l {}; for {set r 10} {$r<=23} {incr r} { lappend l [format %02X [rd [expr {0xFBB1+$r}]]] }; return $l }
after time 12 { kstr "call printon\r" }
after time 13 { kpush [concat [str2b "10 for i=1 to 5:print \""] [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 2]] }
after time 13.15 { kpush [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 1] }
after time 13.3 { kpush [rep {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} 5] }
after time 13.6 { kpush [concat [rep {0xBB 0xD9 0xE8} 8] [str2b "\";i:next\r"]] }
after time 14.5 {
  debug set_bp 0x4EBC {[pc_in_slot 1]} { if {[rd 0xFD48]} { log "WRAP_FIX: CSRY=[rd 0xF3DC] CSRX=[rd 0xF3DD] PR=[rd 0xFD18] LT10-23=[lt]" } }
  debug set_bp 0x4E58 {[pc_in_slot 1]} { log "LINK_NEXT A=[reg A] CSRY=[rd 0xF3DC]"; if {[reg A]==22} { show L } }
  kstr "cls:run\r"
}
proc show {tag} {
    set th [dict create 0xCA s 0xC7 w 0xD1 a 0xB4 d 0xD5 i 0xBB p 0xD9 u 0xE8 ` 0xFF #]
    for {set r 1} {$r <= 24} {incr r} {
        set s ""; foreach x [vramrow $r] { set v [scan $x %x]; set k [format 0x%02X $v]; if {[dict exists $th $k]} {append s [dict get $th $k]} elseif {$v>=32 && $v<127} {append s [format %c $v]} else {append s "?"} }
        set s [string trimright $s]; log "$tag R[format %02d $r] |$s"
    }
}
after time 16 { show F; close $::out; exit }
