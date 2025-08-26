# Remove old log
rm /sdcard/bootloader_install_log.txt

# Ensure we aren't missing bootloader backups
[ ! -f /sdcard/boot_a.img ] && echo "Missing stock bootloader files" >> /sdcard/bootloader_install_log.txt
[ ! -f /sdcard/boot_b.img ] && echo "Missing stock bootloader files" >> /sdcard/bootloader_install_log.txt
[ ! -f /sdcard/vbmeta_a.img ] && echo "Missing stock bootloader files" >> /sdcard/bootloader_install_log.txt
[ ! -f /sdcard/vbmeta_b.img ] && echo "Missing stock bootloader files" >> /sdcard/bootloader_install_log.txt

# Restore stock boot if all of them exist
[ -f /sdcard/boot_a.img ] && dd if=/sdcard/boot_a.img of=/dev/block/by-name/boot_a 
[ -f /sdcard/boot_b.img ] && dd if=/sdcard/boot_b.img of=/dev/block/by-name/boot_b 
[ -f /sdcard/vbmeta_a.img ] && dd if=/sdcard/vbmeta_a.img of=/dev/block/by-name/vbmeta_a 
[ -f /sdcard/vbmeta_b.img ] && dd if=/sdcard/vbmeta_b.img of=/dev/block/by-name/vbmeta_b 
echo "Flashed stock bootloader files" >> /sdcard/bootloader_install_log.txt
rm /sdcard/boot_a.img
rm /sdcard/boot_b.img
rm /sdcard/vbmeta_a.img
rm /sdcard/vbmeta_b.img
echo "Removed backup stock bootloader files" >> /sdcard/bootloader_install_log.txt