# 9.43: ใช้ร่วมกับเทสอื่น (-script tests/ram_boot.tcl -script tests/t_xxx.tcl) โดยไม่เสียบตลับ --
# วางไฟล์ BLOAD ลง RAM ที่ $9000 แล้วสั่ง DEFUSR/USR ให้ตัวโหลดทำงาน (เหมือน BLOAD ,R) ก่อนเทสเริ่ม
set ::ram_bin [file dirname [info script]]/../build/THAIMSX.BIN
after time 5 {
    set f [open $::ram_bin rb]; set b [read $f]; close $f
    debug write_block memory 0x9000 [string range $b 7 end]
    set s "defusr=&h9000:a=usr(0)\r"
    foreach c [split $s ""] { set p [expr {[debug read memory 0xF3F8] + 256*[debug read memory 0xF3F9]}]; debug write memory $p [scan $c %c]; incr p; if {$p >= 0xFC18} {set p 0xFBF0}; debug write memory 0xF3F8 [expr {$p&255}]; debug write memory 0xF3F9 [expr {$p>>8}] }
}
