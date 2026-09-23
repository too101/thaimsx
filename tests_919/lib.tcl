# ---- helpers ----
set ::out [open $::env(OUTF) w]
proc log {s} { puts $::out $s; flush $::out }
proc rd {a} { binary scan [debug read_block memory $a 1] cu v; return $v }
proc rd16 {a} { return [expr {[rd $a] + 256*[rd [expr {$a+1}]]}] }
proc wr {a v} { debug write memory $a $v }
# push bytes into the BIOS keyboard queue (PUTPNT=$F3F8, KEYBUF=$FBF0..$FC17)
proc kpush {bytes} {
    foreach b $bytes {
        set p [rd16 0xF3F8]
        wr $p $b
        incr p
        if {$p >= 0xFC18} { set p 0xFBF0 }
        wr 0xF3F8 [expr {$p & 255}]
        wr 0xF3F9 [expr {$p >> 8}]
    }
}
proc str2b {s} { set r {}; foreach c [split $s ""] { lappend r [scan $c %c] }; return $r }
proc kstr {s} { kpush [str2b $s] }
# find byte sequence in RAM 0x8000-0xF37F; return list of addresses
proc findseq {seq} {
    set blk [debug read_block memory 0x8000 0x7380]
    binary scan $blk cu* bytes
    set n [llength $seq]; set res {}
    for {set i 0} {$i < [llength $bytes]-$n} {incr i} {
        set ok 1
        for {set j 0} {$j < $n} {incr j} { if {[lindex $bytes [expr {$i+$j}]] != [lindex $seq $j]} {set ok 0; break} }
        if {$ok} { lappend res [format %04X [expr {0x8000+$i}]] }
    }
    return $res
}
# dump program line text: walk TXTTAB
proc dumpprog {} {
    set p [rd16 0xF676]
    set lines {}
    for {set k 0} {$k < 20} {incr k} {
        set nxt [rd16 $p]
        if {$nxt == 0} break
        set ln [rd16 [expr {$p+2}]]
        set s {}
        for {set q [expr {$p+4}]} {$q < $nxt-1} {incr q} { lappend s [format %02X [rd $q]] }
        lappend lines "$ln: $s"
        set p $nxt
    }
    return $lines
}
proc vramrow {r} {
    # SCREEN0 width40: name table at NAMPNT ($F922)
    set base [rd16 0xF922]
    set w [expr {[rd 0xFCAF] != 0 ? 32 : ([rd 0xF3B0] > 40 ? 80 : 40)}]; set b [debug read_block "VRAM" [expr {$base + ($r-1)*$w}] $w]
    binary scan $b cu* v
    set s {}; foreach x $v { lappend s [format %02X $x] }
    return $s
}
