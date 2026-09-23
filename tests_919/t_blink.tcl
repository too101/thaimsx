source [file dirname [info script]]/lib.tcl
set throttle off
proc pat255 {} {
    set cg [rd16 0xF924]
    binary scan [debug read_block VRAM [expr {$cg + 0x7F8}] 8] cu* v
    set s {}; foreach x $v { lappend s [format %02X $x] }; return [join $s ""]
}
proc samp {tag} {
    set r {}
    for {set i 0} {$i < 1} {incr i} {}
    log "$tag: THAI=[wv 0xFD12] INPUT=[wv 0xFD11] pat255=[pat255] TIMI=[format %02X [rd 0xFD9F]] ic=[wv 0xFD35] w=[wv 0xFD36] cnt=[wv 0xFD55] off=[wv 0xFD56] fnk=[rd 0xFBCD] sh=[rd 0xFBEB] cns=[rd 0xF3DE] hk=[format {%02X %02X %02X %02X} [rd 0xFD9F] [rd 0xFDA0] [rd 0xFDA1] [rd 0xFDA2]] scr=[rd 0xFCAF] prev=[format {%02X %02X} [wv 0xFD57] [wv 0xFD58]]"
}
after time 6 { kstr "10 rem ab" }
# english idle samples
foreach t {7.0 7.2 7.4 7.6 7.8} { after time $t "samp {E $t}" }
after time 8.0 { keymatrixdown 6 0x10 }
after time 8.1 { keymatrixup 6 0x10 }
foreach t {8.4 8.6 8.8 9.0 9.2 9.4 9.6 9.8} { after time $t "samp {T $t}" }
after time 10.0 { keymatrixdown 6 0x10 }
after time 10.1 { keymatrixup 6 0x10 }
foreach t {10.3 10.5 10.7 10.9} { after time $t "samp {E2 $t}" }
after time 11 { kstr "\r" }
after time 11.4 { kstr "call thaioff\r" }
after time 12 { samp "OFF"; log "H_TIMI=[format {%02X %02X %02X %02X %02X} [rd 0xFD9F] [rd 0xFDA0] [rd 0xFDA1] [rd 0xFDA2] [rd 0xFDA3]]"; foreach l [dumpprog] { log "   PROG $l" }; close $::out; exit }
