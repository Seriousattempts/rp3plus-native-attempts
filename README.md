## Attempts at changing operating system on Retroid Pocket 3 Plus


# Purpose
- More games to play (Windows/Linux/Emulation/Android)
- Make multiplayer gaming *easier*:

  1. A lot of this will clearly not run per say, but work with me here I'm ranting
  2. Hamachi
  3. Soapbox
  4. Parsec
  5. FightCade
  6. Arkadyzja
  7. FS/CAPS Amiga
  8. MAMEPPK/Ace/Calice/fba/Nebula/Kawaks - Arcade
  9. GBE+/Mesen/NEStopia/RockNES/VirtualNES/Snes9x/ZSnes/Gopher64-netplay/Project64/TGBDual/SameBoy/DoubleCherryGB/rgbds/Tango/VBALink/No$GBA/melonDS/DeSmuME/mGBA-Dolphin/WiiLinkPatcher/Dolphin-Triforce/Slippi Launcher/Cemu/
  10. Gens/Flycast/Fusion - SEGA
  11. ePSX/Duckstation-Netplay/PCSX2-online/RPCS3/PPSSPP - Sony
  12. XLinkKai - XBOX
  13. Mednafen
 
- Similar to EmuDeck and other shell scripts, downloaded all these files, make one large UI that sets up all these files along with an ipcheck with copy and paste functionality with current controller to join a session or start one. Happy I didn't start that yet (Only one 1 emulation handheld that is an android, guess what it is).

I recommend a linux handheld (more versatility to play Windows, Android and Linux games with ease if setup properly)

Device Info: https://deviceinfohw.ru/devices/item.php?item=108681
- Unisoc T618 with a ums512_1h10 board There's 6 other handhelds with similar specs:
1. Retroid Pocket Flip https://retrocatalog.com/retro-handhelds/retroid-pocket-flip
2. PowKiddy X18S https://handheldsarena.com/devices/powkiddy/x18s/
3. Powkidding X28 https://handheldsarena.com/devices/powkiddy/x28/
4. RG505 https://retrodb.info/console/rg505
5. RG405M https://retrodb.info/console/rg405m
6. RG-405V https://retrocatalog.com/retro-handhelds/rg-405v

List of Smartphones with same board:
- ZTE Blade V30
- ZTE Blade V40s
- ZTE Blade V40 Pro
- ZTE Axon 20 4G
- ZTE Axon 40 SE
- Realme C25Y RMX3265
- Micromax In 2C E6533
- Symphony Z33
- I know there's more than this (https://en.wikipedia.org/wiki/List_of_UNISOC_systems_on_chips | https://phonesdata.com/en/chipset/unisoc/tiger-t618-(12-nm)/ | https://www.epey.co.uk/phone/chipset/unisoc-t618/ )

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
- Tried a HxD modification to the boot/uboot to prioritize mmcblk1 over mmcblk0. OBviously failed https://mh-nexus.de/en/hxd/

# Tried PostMarketOS
- Couldn't replicate booting intro the device, had issues with using pmbootstrap (APKBUILD file, issues regardless of kernel fork selected https://wiki.postmarketos.org/wiki/Porting_to_a_new_device/Kernel_package/Preparation) https://wiki.postmarketos.org/wiki/Unisoc_Tiger_T610/T618_(UMS512)
- Device is not part of mainline as well.

## If anyone get's a different operating system running natively:
- Check RAM usage (Can check in developer mode)
- Test performance against past performance: https://www.google.com/search?sca_esv=bfd7f0276b7e69c9&q=%223.2+v1.r27p0-01eac0.bfc9f89b34c882ca6dc6566781e4f990%22&udm=2&fbs=ABzOT_CWdhQLP1FcmU5B0fn3xuWpA-dk4wpBWOGsoR7DG5zJBsxayPSIAqObp_AgjkUGqel3rTRMIJGV_ECIUB00muput9Zp8VMKUi0ZjqPs3JlrgNjQ9rOqRdXcDwEBQ82jIzIeJKF_t4xlLNL8OlcUPXuD4mOHi5CwSvqoRYVHDp8kIKIKk9txe0fwpxc-El6CFYl-jFdhssameWHw9C9RusrnI0QBZA&sa=X&ved=2ahUKEwjXxvX5n9iMAxUVATQIHRnNDP0QtKgLegQIGhAB
# The plan?
- ARM Compute Library https://github.com/ARM-software/ComputeLibrary
# Windows:
- ARM Server build https://betawiki.net/wiki/Windows_Server_2016_build_14282_(rs1_onecore_mqsrv_sc)
- Lumia applications / drivers https://woa-project.github.io/LumiaWOA/
- Visual Studio 2019 at minimum https://learn.microsoft.com/en-us/visualstudio/releases/2019/compatibility
- MESA3D ARM 64 (https://github.com/mmozeiko/build-mesa/releases), .NET (https://learn.microsoft.com/en-us/dotnet/core/install/windows?WT.mc_id=dotnet-35129-website#install-with-windows-package-manager-winget)
- GL4ES https://github.com/ptitSeb/gl4es
- GLFW https://github.com/glfw/glfw
- ARM64EC / ARM64X http://www.emulators.com/docs/abc_arm64ec_explained.htm
- WoW64 https://en.wikipedia.org/wiki/WoW64
- Vendor 2022 Product 3001 / Vendor_18d1_Product_5018 / Vendor_18d1_Product_0200 for device controls
- Discord/BetterDiscord/Vencord https://github.com/Vencord/Vesktop
- Nexus Mod https://github.com/Nexus-Mods/NexusMods
- ShaderGlass: https://github.com/mausimus/ShaderGlass
- Windows on ARM apps: https://www.worksonwoa.com/en
- Battery Bar https://batterybarpro.com/
- Reshade with shaderGlass https://itch.io/post/11717383
- CloudGamePad for Chome browsers https://github.com/ls-ramos/CloudGamepad
- SaveState https://github.com/Matteo842/SaveState
- Syncthing
- antstream
- EA App
- Emu Deck
- Epic Games Launcher
- Fightcade
- Flashpoint Archive
- Moonlight/GameStream Client
- Sunshine/GameStream Server
- Apollo and Artemis
- GeForce NOW
- GOG Galaxy
- Itch.io
- HumbleBumble
- PICO-8
- PS Remote Play
- RetroArch
- Steam
- TCNO Account Switcher
- Ubisoft Connect
- TeknoParrot
- TIC-80
- Vircon32
- Virtual Desktop Streamer
- WireGuard


# Linux:
- Armbian ARM64 https://www.armbian.com/uefi-arm64/
- Manjaro ARM https://github.com/manjaro-arm
- VK hdr layer (yeah probably wasn't going to work but fk it) https://github.com/Zamundaaa/VK_hdr_layer
- MangoHud https://github.com/flightlessmango/MangoHud
- Bottles https://github.com/bottlesdevs/Bottles
- Box64 https://github.com/ptitSeb/box64
- FEX https://github.com/FEX-Emu/FEX
- WireGuard https://rocknix.org/configure/vpn/
- Limo Nexus Mod https://github.com/limo-app/limo
- Waydroid https://github.com/waydroid/waydroid
- https://github.com/GloriousEggroll/wine-ge-custom
- https://github.com/Open-Wine-Components/umu-launcher
- spotube https://github.com/KRTirtho/spotube
- Wine Custom https://github.com/GloriousEggroll/wine-ge-custom
- Umu launcher https://github.com/Open-Wine-Components/umu-launcher
- GL4ES https://github.com/ptitSeb/gl4es
- GLFW https://github.com/glfw/glfw
- NonSteamLauncher https://github.com/moraroy/NonSteamLaunchers-On-Steam-Deck
- Copy MuOS Hotspot https://github.com/nvcuong1312/hotspotmuos
- Self Hosted Cloud Gaming (Estiate 15USD for 30 Hrs per month) https://github.com/PierreBeucher/cloudypad
- CloudGamePad for Chome browsers https://github.com/ls-ramos/CloudGamepad
- PRoton DB 
- WineTrix
- Syncthing
- ReShade
- antstream
- Emu Deck
- Fightcade
- Flashpoint Archive
- Moonlight/GameStream Client
- Sunshine/GameStream Server
- Apollo and Artemis
- PICO-8
- RetroArch
- Steam
- TCNO Account Switcher
- Ubisoft Connect
- TeknoParrot
- TIC-80
- Vircon32
- Virtual Desktop Streamer
- WireGuard

# Files I've uploaded
- Mockups of a compute setup, opencl integration and init of ideas I had as well.
- Last attempt at Zackptg5's dual boot setup.
- Write up of thoughts
