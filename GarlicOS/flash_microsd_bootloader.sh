# Remove old log
rm /sdcard/bootloader_install_log.txt

# Ensure we aren't missing bootloader files
[ ! -f /sdcard/boot.img ] && echo "Missing microsd bootloader files" >> /sdcard/bootloader_install_log.txt
[ ! -f /sdcard/vbmeta.img ] && echo "Missing microsd bootloader files" >> /sdcard/bootloader_install_log.txt

# Back up stock and them flash MicroSD bootloader files
[ ! -f /sdcard/boot_a.img ] && dd if=/dev/block/by-name/boot_a of=/sdcard/boot_a.img 
[ ! -f /sdcard/boot_b.img ] && dd if=/dev/block/by-name/boot_b of=/sdcard/boot_b.img 
[ ! -f /sdcard/vbmeta_a.img ] && dd if=/dev/block/by-name/vbmeta_a of=/sdcard/vbmeta_a.img 
[ ! -f /sdcard/vbmeta_b.img ] && dd if=/dev/block/by-name/vbmeta_b of=/sdcard/vbmeta_b.img 
echo "Backed up stock bootloader files" >> /sdcard/bootloader_install_log.txt 
[ -f /sdcard/boot.img ] && dd if=/sdcard/boot.img of=/dev/block/by-name/boot_a
[ -f /sdcard/boot.img ] && dd if=/sdcard/boot.img of=/dev/block/by-name/boot_b
[ -f /sdcard/vbmeta.img ] && dd if=/sdcard/vbmeta.img of=/dev/block/by-name/vbmeta_a 
[ -f /sdcard/vbmeta.img ] && dd if=/sdcard/vbmeta.img of=/dev/block/by-name/vbmeta_b
echo "Flashed bootloader files" >> /sdcard/bootloader_install_log.txt