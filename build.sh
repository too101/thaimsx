#!/bin/bash
# build.sh -- ประกอบ source ด้วย pasmo แล้ว pad ให้เป็น 16KB ROM (มาตรฐาน MSX cartridge)
set -e
cd "$(dirname "$0")"
mkdir -p build
pasmo src/main.asm build/thairom_raw.bin build/thairom.sym
python3 - <<'PYEOF'
data = open('build/thairom_raw.bin','rb').read()
print(f"assembled size: {len(data)} bytes")
target = 16384
if len(data) > target:
    raise SystemExit(f"ERROR: ROM too big for 16KB ({len(data)} bytes)")
padded = data + b'\xff' * (target - len(data))
with open('build/thairom.rom','wb') as f:
    f.write(padded)
print(f"padded to {target} bytes -> build/thairom.rom")
PYEOF
