# เครื่องจำลอง openMSX ที่ใช้ทดสอบ

| ไฟล์ | เครื่อง | system ROM ที่ต้องมี |
|---|---|---|
| `UserMSX1.xml` | MSX1 (slot 0 ไม่ขยาย) | `MSX.rom` |
| `UserMSX1_expanded.xml` | MSX1 ที่ slot 0 ขยาย (แบบเครื่องจริงหลายรุ่น) | `MSX.rom` |
| `UserMSX2.xml` | MSX2 | `MSX2.rom`, `MSX2EXT.rom` |
| `UserMSX2P.xml` | MSX2+ | `MSX2P.rom`, `MSX2PEXT.rom` |
| `PhilipsDisk.xml` | extension: disk interface WD2793 | `PHILIPSDISK.rom` |

ชื่อไฟล์ ROM ตรงกับชุด `Machines/Shared Roms` ของ blueMSX และระบุ sha1 ไว้ openMSX จึงหาเจอจาก systemroms เอง

ติดตั้ง:
```
cp UserMSX*.xml            ~/.openMSX/share/machines/
cp PhilipsDisk.xml         ~/.openMSX/share/extensions/
cp <blueMSX>/Machines/Shared\ Roms/{MSX,MSX2,MSX2EXT,MSX2P,MSX2PEXT,PHILIPSDISK}.rom ~/.openMSX/share/systemroms/
```
แล้วรัน `scripts/run_tests.sh` ที่ root ของ repo

ทดสอบกับ disk: `openmsx -machine UserMSX2 -ext PhilipsDisk -carta build/thairom.rom`
(ROM อยู่ slot ก่อน disk) หรือ `-ext PhilipsDisk -cartb build/thairom.rom` (disk ก่อน)
