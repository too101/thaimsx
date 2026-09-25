# Changelog

เวอร์ชันตั้งชื่อตามวันที่ (`vYYYYMMDD`) — ไฟล์ ROM อยู่ในหน้า [Releases](https://github.com/too101/thaimsx/releases)

## v20260925

รุ่นแรก — ROM 8 KB (`thaimsx-v20260925.rom`) ใช้ได้กับ MSX1 / MSX2 / MSX2+ (มีหรือไม่มี disk drive)

- คำสั่ง CALL ครบตาม MSX-ไทย 1.02: THAION/THAIOFF, PRINTON/PRINTOFF (?ON/?OFF), INPUTON/INPUTOFF (@ON/@OFF),
  PLOCKON/PLOCKOFF, SYSTEM, ANSTR, TNSTR, MLSTR, LPRINT
- แสดงผลไทย 3 ระดับ, แป้นเกษมณี (แก้ bug แป้นของต้นฉบับ), GRAPH + A–Z พิมพ์คำสั่ง BASIC
- ภาษาไทยบนจอกราฟิก (`OPEN "GRP:"`) และเครื่องพิมพ์ 3 แถว
- ฟอนต์จาก MSX-ไทย ปรับตำแหน่งวรรณยุกต์และพินทุ
- แก้: บรรทัดแรกหลัง CLS ตอน PRINTON ไม่มีแถวสระบน; AUTO ตอน PRINTON ทำงานทันทีแทนการเก็บบรรทัด

First release — 8 KB ROM for MSX1 / MSX2 / MSX2+, a new implementation of the MSX-ไทย 1.02 feature set.
