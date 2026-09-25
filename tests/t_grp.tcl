source [file dirname [info script]]/lib.tcl
set throttle off
proc scr {tag} { for {set r 1} {$r <= 23} {incr r} { set s ""; foreach x [vramrow $r] { scan $x %x v; append s [expr {$v>=32 && $v<127 ? [format %c $v] : [format {<%02X>} $v]}] }; set s [string trimright $s]; if {$s ne ""} { log "$tag R$r $s" } } }
after time 9 [list kstr "10 screen $::env(SC):open\"grp:\"as#1\r"]
after time 9.5 { kpush [concat [str2b "20 preset(16,16):?#1,\""] {0xCA 0xC7 0xD1 0xCA 0xB4 0xD5} [str2b "\"\r"]] }
after time 10 { kpush [concat [str2b "30 preset(16,40):?#1,\""] {0xB9 0xE9 0xED 0xD2 0x20 0xB7 0xD5 0xE8} [str2b "\"\r"]] }
after time 10.5 { kpush [concat [str2b "40 preset(16,64):?#1,\""] {0xA1 0xD8 0xA1 0xD4 0xEC 0xBB 0xD1 0xE9} [str2b "\"\r"]] }
after time 11 { kstr "50 a\$=input\$(1)\r" }
after time 11.5 { kstr "run\r" }
after time 14 { if {[rd 0xFCAF] < 2} { scr T }; log "FEC6=[format {%02X %02X %02X %02X %02X} [rd 0xFEC6] [rd 0xFEC7] [rd 0xFEC8] [rd 0xFEC9] [rd 0xFECA]] SCR=[rd 0xFCAF] CGPNT=[format %02X [rd 0xF91F]]:[format %04X [rd16 0xF920]]"
  set f [open /tmp/vram_$::env(SC)_$::env(M).bin wb]; puts -nonewline $f [debug read_block VRAM 0 [expr {$::env(SC) >= 5 ? 0x10000 : 0x4000}]]; close $f
  close $::out; exit }
