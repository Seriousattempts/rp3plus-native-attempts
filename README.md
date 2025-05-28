## Attempts to change operating system on Retroid Pocket 3 Plus

I recommend a linux handheld (more versatility to play Windows, Android and Linux games with ease if setup properly)

Device Info: https://deviceinfohw.ru/devices/item.php?item=108681
- Unisoc T618 with a ums512_1h10 board

List of Smartphones with same board:
- ZTE Blade V30
- ZTE Blade V40s
- ZTE Blade V40 Pro
- ZTE Axon 20 4G
- ZTE Axon 40 SE
- Realme C25Y RMX3265
- Micromax In 2C E6533
- Symphony Z33


# Issues to why I've been unable to natively change system (Even when Magisk, TWRP or Bootloader Unlocked | Regardless of combination)
- Unable to flash an empty vbmeta, which makes things fail to install:
- DSU Loader fails to install for device. It reboots once after install and goes back to stock android
- GammaOS after flashing reboots itself. When you load a .pac file, you can inspect within your .img files. When I check the super.img with 7Zip, this is within it:
- product_a.img
- system_a.img
- system_ext_a.img
- vendor_a.img
- product_b
- system_b
- system_ext_b
- vendor_b

If you check the RG505 (Same SoC, can load GammaOS), this is within it's super.img:
- product_a.img
- system_a.img
- system_ext_a.img
- vendor_a.img
- vendor_dlkm_a.img
- product_a-cow.img
- system_a-cow.img
- system_ext_a-cow.img
- vendor_a-cow.img
- vendor_dlkm_a-cow.img

Possible issue: Device’s super partition layout is fundamentally different from the layouts used by devices that work with GammaOS or generic GSI images. The presence of only {product,system,system_ext,vendor}_{a,b} (b files are empty) partitions—and the absence of COW and vendor_dlkm partitions, at least for RG505's example. Can be "fixed" by finding compatibile files, but has it's own issues.

# Attempts to boot from userdata for dualboot
- Zackptg5's OnePlus method: https://gist.github.com/Zackptg5/564230ac47b27fc99891eb99e66fcc5b
  1. blkid doesn't work in twrp terminal
  2. sgdisk works in terminal, but fails in script
- Attempted to decrypt userdata to manually install an OS after partitining userdata (Split remaining userdata space in have, keep partition 76 userdata, creates a partition 77 userdata to reformat in order to boot into different os with dualboot companion app  (https://github.com/Invernomut0/OrangeFox-DualBoot-Guac-Unified/tree/master/data/app)
  1. DFE-NEO would get stuck on boot logo https://github.com/leegarchat/dfe-neo-v2/issues/9
  2. Even if you fix the issue (sometimes DFE-NEO 2 works, most times it doesn't), when you load back into system, /data encrypts. When you boot back into TWRP, it still shows DFE-NEO has been ran, but /data is inaccessible.

Because you don't have access to /data due to encryption, you cannot install Kali Linux (it cannot access partition)

# Flashing other .pac files in order to flash gsi images (to load kali linux to then possibly create a grub menu to boot intro SD card to load Linux/Windows ARM)
- Tried flashing smartphone devices listed above, screen doesn't load, only backlight, and would restart itself.
- Tried PowKiddy X28 firmware, failed to show anything and just boot loop with backlight screen https://www.reddit.com/r/PowKiddy/comments/170eueg/comment/kbam9hf/
- Realme C25Y RMX3265 fails at flashing (it was the vbmeta files and super images) https://realmefirmware.com/realme-c25y-firmware/
- RG505 would show backlight screen, and power & vol up would work (hold power you will feel the vibrate as if it's asking you to select an option after pressing power, trying to go back into Download mode to reflash another firmware after this one is hard because Vol Down and Power doesn't work as normal, and Power and Vol up would simply vibrate the device and continue. You have to do it while unplugged to the PC, holding a combination of Power, Vol Up, Vol Down & Home. Can't tell you if pressing all at the same time works or pressing one at a time, I got lucky) https://drive.google.com/file/d/1WNildo8TZDW6L4tzY9SDEjL3NhPGg_gG/view

*When examining .xml file from the .pac files, I found a few devices with closer patition schemes (RG505 still failed). So this time when flashing:*
- I took the following files from Symphony Z33's .pac file (super, vbmeta_product, vbmeta_system, vbmeta_system_ext, vbmeta_vendor) to replace the stock rp3+ files of the same parititon. It would boot into Symphony Z33 installer. Then it would restart a minute later, a boot loop. You can use the device up till that minute (Uses 2.2GB+ of RAM compared to Retroid's 1.8GB) https://drive.google.com/file/d/1K_bcsiLkNm-7QUIHjbyk8AYXttppOVXl/view
- I took the following files from  Micromax In 2C E6533 (S/w: v12, v07 & 05) .pac file. I took the following files (super, vbmeta_product, vbmeta_system, vbmeta_system_ext, vbmeta_vendor again to replace stock rp3+ files of the same parititon). It would boot intro Micromax In 2C's Android setup and then restart a minute later, another boot loop. You can use the device up till that minute (Uses 2.2GB+ of RAM compared to Retroid's 1.8GB) https://drive.google.com/file/d/1aPmFNelfQDlNwOfItxC4R1NkydiViffw/view
- Realme, RG505, Powkiddy would fail at flashing or bootloop
- Changing socko/odmko/ caused bootloop for Z33. Changing vbmeta-sign/boot.img caused bootloop for Z33 as well, for 2C, touchscreen stopped working, but volume keys worked (still restarted a minute later)

# Trying other boot.img
- Boot loops of course. Except 1 https://github.com/jytmX/OrangeFox-Recovery-Builder-2024/releases/tag/11995394593
- Boots intro OrangeFox recovery (Have to sign it with a vbmeta), but touch screen doesn't work. Doubt it make a difference but the attempt was made.
- Unpacking and repacking didn't work (unless Magisk did it). Didn't care to try APatch.




