# การถอดรหัส KEYCOD state machine จาก MSXTHA102_original_16k.rom

สถานะ: **ยืนยันโครงสร้างหลักแล้ว** ผ่านการ disassemble จริง (ไม่ใช่การไล่โค้ดด้วยมือแบบเดา) — ยังไม่ได้ไล่ครบทุก
handler ปลายทาง (ดูหัวข้อ "ยังไม่ได้ถอด" ท้ายไฟล์)

## 1. จุดเข้า

`H.KEYC` (0xFDCC) ถูกแพตช์ให้ชี้มาที่ 0x4C57 → ตรรกะจริงเริ่มที่ **0x4D10**

## 2. ตาราง dispatch หลัก ที่ 0x4C7A (scan code C → handler)

รูปแบบ: ตาราง triplet ต่อเนื่อง `[threshold:1][addr_lo:1][addr_hi:1]` เรียงค่า threshold จากน้อยไปมาก
โค้ดที่ 0x4D10-0x4D33 สแกนหา entry แรกที่ `C < threshold` แล้วกระโดดไปที่ addr ของ entry นั้น (ใช้ trick
`PUSH addr; RET C` เพื่อกระโดดทางอ้อม)

ค่าไบต์จริงที่ 0x4C7A: `0a 35 4d 16 71 4d 30 4c 4d 33 e1 4d 34 06 4e 35 ee 4d 3a 8b 4d 3c e1 4d 3d 16 4e 41 e1 4d 42 d6 4d ff e1 4d`

ถอดเป็นตาราง (ยืนยันด้วยการเทียบ addr ปลายทางกับ label ที่ disassemble ได้จริง):

| ช่วง scan code C (hex) | ปลายทาง | หมายเหตุ |
|---|---|---|
| 0x00-0x09 | 0x4D35 | เลขแถวบน 0-9 → ASCII '0'-'9' (+0x30) หรือสัญลักษณ์ shift จากตาราง 0x4C9E |
| 0x0A-0x15 | 0x4D71 | คีย์แถวหนึ่ง (12 คีย์) — ใช้ตาราง 4-way shift ที่ 0x4CB0 |
| 0x16-0x2F | 0x4D4C | คีย์แถวหลัก (26 คีย์) — ใช้ตาราง 4-way shift ที่ 0x4CA8 |
| 0x30-0x32 | 0x4DE1 | (ยังไม่ถอด — คาดว่า default/passthrough) |
| 0x33 | 0x4E06 | (ยังไม่ถอด) |
| 0x34 | 0x4DEE | **คีย์สลับโหมดไทย/อังกฤษ** (ตรงกับ analysis doc เดิมที่บอกว่า routine 0x4DEE คือ toggle ผ่าน flag 0xFCAC) |
| 0x35-0x39 | 0x4D8B | ใช้ตาราง shift ที่ 0xFB99 (system var, ไม่ใช่ ROM เอง) |
| 0x3A-0x3B | 0x4DE1 | default/passthrough |
| 0x3C | 0x4E16 | (ยังไม่ถอด) |
| 0x3D-0x40 | 0x4DE1 | default/passthrough |
| 0x41 | 0x4DD6 | (ยังไม่ถอด) |
| 0x42-0xFF | 0x4DE1 | default/passthrough (ครอบคลุมคีย์ที่เหลือทั้งหมด) |

**สรุป**: มีเพียง scan code 0x00-0x41 (66 ค่าแรก) เท่านั้นที่ได้รับการประกอบอักษรไทยแบบพิเศษ ส่วนที่เหลือ
(0x42 ขึ้นไป) วิ่งเข้า handler เดียวกัน (0x4DE1) ซึ่งน่าจะเป็นทางผ่านตรงแบบไม่ประกอบ (ต้องยืนยันอีกที
ตอน implement Phase 3)

## 3. ตาราง shift-state 4-way ที่ 0x4CA8 (สำหรับ scan code 0x16-0x2F)

อ่านค่า `(0xFBEB) AND 3` (2 บิตสถานะ shift/graph/code) คูณ 2 เป็น index เข้าตาราง word 4 ช่อง:

```
index 0 (ไม่กด modifier)     -> 0x4E25  (push อักขระตรง ๆ เข้าคิว)
index 1 (กด modifier ตัวที่1) -> 0x4E25  (เหมือน index 0)
index 2 (กด modifier ตัวที่2) -> 0x4D61  (ADD A,0x40 แล้วไป 0x4D49)
index 3 (กด ทั้งคู่)          -> 0x4D65  (คำนวณผสมกับ flag 0xFCAB แล้ว ADD A,0x40)
```

## 4. ตาราง 10 คู่สัญลักษณ์ที่ 0x4CB8 (ไม่กด Shift / กด Shift)

```
2d 3d  -> '-' / '='
5c 5b  -> '\' / '['   (ตามลำดับไบต์ที่เจอ, ต้องเช็คทิศทางตอน implement)
5d 3b  -> ']' / ';'
27 60  -> '\'' / '`'
2c 2e  -> ',' / '.'
2f ff  -> '/' / (ไม่มี — end marker?)
5f 2b  -> '_' / '+'
7c 7b  -> '|' / '{'
7d 3a  -> '}' / ':'
22 7e  -> '"' / '~'
3c 3e  -> '<' / '>'
3f ff  -> '?' / (end)
```
(ต้องยืนยัน routine ที่อ่านตารางนี้จริง ๆ ตอน implement Phase 3 — เห็นจาก data dump แต่ยังไม่ได้ผูกกับ
code path ที่อ่านมันแบบ 100% ยืนยัน)

## 5. ตาราง symbol แถวเลขที่กด Shift ที่ 0x4C9E (10 ไบต์)

`29 21 40 23 24 25 5e 26 2a 28` = `)!@#$%^&*(` — ตรงกับแป้นตัวเลข 0-9 แถวบนตอนกด Shift (มาตรฐาน US
keyboard layout)

## 6. routine ร่วม push อักขระเข้าคิว ที่ 0x4E25

ใช้ `CALL 0x10C2` (**ยืนยันแล้วว่า address เดียวกันทั้ง MSX1/MSX2/MSX2+** จาก section 3/8.1 ของ analysis
doc เดิม) — พกพาข้ามรุ่นได้โดยตรง ไม่ต้องแก้ไขอะไรสำหรับจุดนี้ในการ rewrite

## 7. ยังไม่ได้ถอด (deferred ไปทำตอน Phase 3 implementation)

**อัปเดต (Phase 3 ส่วนที่ 2, ดู SPEC_TH.md section 9.9)**: พบและยืนยันตาราง scan-code → font code แล้ว
ทั้งสองตาราง (ไม่ใช่ 44 พยัญชนะครบทุกตัว แต่ครบทุกคีย์ที่แถวอักษรหลัก+row1 มี mapping จริง):
- `0x4EC1` (26 ไบต์): compact index 1-26 (= scan `0x16`-`0x2F`, A-Z) → font code
- `0x4EB5` (12 ไบต์): scan `0x0A`-`0x15` → font code (`0xFF` = ไม่มี mapping)
ยืนยันด้วยวิธี cross-check สามทาง (MSX keyboard matrix มาตรฐาน + Kedmanee layout สาธารณะจาก
`xkeyboard-config` + font code พยัญชนะที่ render จาก `assets/font_raw.bin`) ตรงกันทั้ง 21 ตำแหน่งพยัญชนะ
— ดูรายละเอียดเต็มใน `src/keyboard.asm` หัวข้อ 5 และ `SPEC_TH.md` section 9.9 ค่าถูก copy เข้า
`MAIN_ROW_TABLE`/`ROW1_TABLE` ใน `src/keyboard.asm` แล้ว

ที่ยังไม่ได้ถอด (ไม่กระทบการพิมพ์อักษรไทยแบบเรียบที่ทำเสร็จแล้ว):
- Handler เต็มที่ 0x4DE1 (default/passthrough), 0x4E06, 0x4E16, 0x4DD6, 0x4D8B (ตาราง 0xFB99),
  0x4DEE (toggle Thai/Eng เต็ม routine — ไม่จำเป็นแล้ว เวอร์ชันใหม่เขียนปุ่มสลับโหมดเองทั้งหมด)
- ตารางแถวตัวเลข (`0x00-0x09`) สำหรับสระ/พยัญชนะที่อยู่บนแถวเลขตอนกด Shift (เช่น ภ ถ ุ ู) — dispatch
  เดิมให้แถวนี้เป็น ASCII digit เสมอในโค้ดที่ไล่ตามมา ยังไม่ได้ยืนยันว่ามีเงื่อนไข THAI_MODE แทรกอยู่ตรงไหน
- ทิศทาง/ความหมายที่แน่นอนของ flag `0xFCAB` ที่ routine 0x4D65 ใช้ (shift-state ตัวที่ 3, ให้อักษรไทยชุด
  ที่สองบนบางคีย์ตาม Kedmanee) — เวอร์ชันใหม่ fallback เป็นอังกฤษสำหรับทั้ง shift-state 2 และ 3 อย่าง
  ปลอดภัย (ตรงตามพฤติกรรมต้นฉบับสำหรับ state 2 แต่ยังไม่ครอบคลุม state 3 เต็มรูปแบบ)

**หมายเหตุสำคัญสำหรับการ rewrite**: ไม่จำเป็นต้อง reverse-engineer ให้ครบ 100% ก่อนเริ่มเขียนโค้ด — ตาราง
data ทั้งหมดข้างต้น (0x4C7A dispatch, 0x4CA8/0x4CB0 4-way, 0x4C9E symbols, 0x4CB8 pairs) **ดึงมาใช้เป็น
binary asset ได้เลยแบบเดียวกับฟอนต์** โดยไม่ต้องเข้าใจความหมายทุกไบต์ — ส่วน handler ปลายทางที่ยังไม่ถอด
จะ disassemble ต่อตอนถึง Phase 3 จริง ๆ (ตาราง TaskList #11)
