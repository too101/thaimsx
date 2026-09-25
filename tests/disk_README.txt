ทดสอบกับ disk ROM (9.29): ต้องมี ~/.openMSX/share/extensions/PhilipsDisk.xml ชี้ไปที่ PHILIPSDISK.rom ของ blueMSX
  openmsx -machine UserMSX2 -carta build/thairom.rom -ext PhilipsDisk -script <script>   (ROM ก่อน disk)
  openmsx -machine UserMSX2 -ext PhilipsDisk -cartb build/thairom.rom -script <script>   (disk ก่อน ROM)
