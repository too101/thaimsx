#!/bin/bash
# รันชุดทดสอบ (openMSX แบบไม่มีหน้าจอ) บนเครื่องจำลอง 4 แบบ -- ผลแต่ละเทสเขียนไว้ที่ out/<machine>_<test>.txt
# ต้องมี: openmsx, machine config ใน openmsx_machines/ ติดตั้งไว้ที่ ~/.openMSX/share/machines/ และ system ROM
# (MSX.rom, MSX2.rom, MSX2EXT.rom, MSX2P.rom, MSX2PEXT.rom) ที่ ~/.openMSX/share/systemroms/
# ใช้: scripts/run_tests.sh [rom]   (ค่าเริ่มต้น build/thairom.rom)
cd "$(dirname "$0")/.."
ROM=${1:-build/thairom.rom}
mkdir -p out
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
run() { # machine outname testscript [TEST]
  M=$1 SC=$([[ $1 == UserMSX1* ]] && echo 2 || echo 5) TEST=$4 OUTF=out/$1_$2.txt \
    timeout 150 openmsx -machine $1 -carta "$ROM" -script tests/$3.tcl >/dev/null 2>&1
}
for m in UserMSX1 UserMSX1_expanded UserMSX2 UserMSX2P; do
  ( for t in t_inlin t_input t_edit t_off t_bs t_scroll t_cursor t_boot t_w80 t_924 t_blink \
             t_a13 t_select t_a45 t_strfn t_d t_grp t_offfont; do run $m $t $t; done ) &
  ( for c in ghost enter2 bs del ins prog bottom; do run $m c_$c t_cont2 $c; done ) &
done
wait
# เครื่องพิมพ์: เทียบไบต์กับผลที่บันทึกไว้ (logger ของ openMSX)
for m in UserMSX1 UserMSX2P; do
  : > out/$m.prn
  PRN=$PWD/out/$m.prn OUTF=out/${m}_t_prn.txt timeout 150 openmsx -machine $m -carta "$ROM" -script tests/t_prn.tcl >/dev/null 2>&1
  cmp -s out/$m.prn tests/t_prn_expected.prn && echo "printer $m: OK" || echo "printer $m: DIFFERENT"
done
ls out/*.txt | wc -l | xargs echo "test logs:"
