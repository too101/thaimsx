#!/bin/bash
# build.sh -- ประกอบ source ด้วย pasmo แล้ว pad ให้เป็น 8KB ROM (มาตรฐาน MSX cartridge)
set -e
cd "$(dirname "$0")"
mkdir -p build
pasmo src/main.asm build/thairom_raw.bin build/thairom.sym
python3 - <<'PYEOF'
data = open('build/thairom_raw.bin','rb').read()
print(f"assembled size: {len(data)} bytes")
target = 8192
if len(data) > target:
    raise SystemExit(f"ERROR: ROM too big for 8KB ({len(data)} bytes)")
padded = data + b'\xff' * (target - len(data))
with open('build/thairom.rom','wb') as f:
    f.write(padded)
print(f"padded to {target} bytes -> build/thairom.rom")
PYEOF
# 9.43: รุ่นโหลดลง RAM -- BLOAD"THAIMSX.BIN",R
pasmo --equ RAMVER=1 src/main.asm build/thaimsx_ram.bin build/thaimsx_ram.sym
pasmo src/loader_bload.asm build/THAIMSX.BIN
python3 scripts/mkcas.py build/THAIMSX.BIN build/THAIMSX.CAS THAI
python3 scripts/cas2wav.py build/THAIMSX.CAS build/THAIMSX.WAV
echo "RAM image: $(stat -c %s build/thaimsx_ram.bin) bytes, BLOAD file: $(stat -c %s build/THAIMSX.BIN) bytes -> build/THAIMSX.BIN"
