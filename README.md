This is for the Retroid Pocket 3 Plus. More information on it:

- [Handhelds Arena](https://handheldsarena.com/devices/retroid/pocket-3-plus/)
- [RetroCatalog](https://retrocatalog.com/retro-handhelds/retroid-pocket-3-plus)
- [Google Compatibility Sheet](https://docs.google.com/spreadsheets/d/1Vf7SIS7ecWa_J301h0mb2bxMWBMtKLvcpAFyaa5-LDc)

If you want one yourself, you can purchase from the following trusted retailers:
- [Alibaba](https://clnk.in/xUTU)
- [AliExpress](https://tidd.ly/4b4EEg2)
- [Amazon](https://amzn.to/4pVkGcm)
- [DHGate](https://tidd.ly/4qiXgxe)
- [eBay](https://ebay.us/T0J08q)

If you ever need to reformat your device (Requires a Windows computer): https://www.youtube.com/watch?v=MsysP8avelk


# For anything Android specific:

## Front-Ends (Free Edition):
1. Daijishō (I used for [Year of the Arcade](https://thesyndicate.zone/2024-2/game-week/)): [https://play.google.com/store/apps/details?id=com.magneticchen.daijishou&pli=1](https://sovrn.co/lx553u3)
2. Dig: [https://play.google.com/store/apps/details?id=com.digdroid.alman.dig](https://sovrn.co/6ue97n6)
3. Pegasus: https://pegasus-frontend.org/#downloads
4. Plain Launcher: [https://bokonon-yossarian.itch.io/plain-launcher](https://bokonon-yossarian.itch.io/plain-launcher?ac=MaWLFKw7mhHDp)
5. Launch-box app: https://www.launchbox-app.com/android-download

- To fix button issues with RetroArch: https://www.reddit.com/r/RetroArch/comments/107kwrk/comment/j3o8slf/
- Other issues with the Pocket 3 Plus: https://www.reddit.com/r/retroid/comments/xl23a9/solutions_to_all_the_retroid_pocket_3_issues/

For advanced features, you need root access:
- Bootloader: https://github.com/Seriousattempts/Bootloader_Unlock_Retroid_Pocket_3Plus
- Magisk: https://github.com/Seriousattempts/RP3Plus-Magisk
- TWRP: https://github.com/Seriousattempts/RP3PLUS-TWRP

## Use root access to do more:
- termux https://github.com/termux/termux-app
- termux-11 https://github.com/termux/termux-x11

Magisk:
- Busybox: https://github.com/Magisk-Modules-Repo/busybox-ndk/blob/master/update.json
- chroot-distro: https://github.com/Magisk-Modules-Alt-Repo/chroot-distro
- This will allow you to run other [Linux/Windows games]([https://github.com/Jacobw1oo/JakeBox](https://github.com/Jacobw1oo/JakeBox/issues/4)) that you may have trouble with using Winlator Bionic Vortex https://github.com/SEGAINDEED/winlator-bionic-vortek/releases

Untested Magisk Modules yet interesting:

- Limbo: https://github.com/limboemu/limbo
- Universal GMS Doze: https://github.com/gloeyisk/universal-gms-doze
- Uperf Game Turbo B: https://github.com/yinwanxi/Uperf-Game-Turbo
- Cross Compiled Binaries: https://github.com/Zackptg5/Cross-Compiled-Binaries-Android
- Kexec tools: https://github.com/evdenis/kexec
- Overlay FS (There's a built in module for the RP3Plus already, though it may not be accessible through normal means): https://github.com/Zenlua/Overlayfs

Other Android non gaming software:
- scrpy: https://github.com/Genymobile/scrcpy | scrpy plus: https://github.com/Frontesque/scrcpy-plus
1. Video tutorial: https://www.youtube.com/watch?v=wZhpagUgIHI
- NewPipe: https://github.com/TeamNewPipe/NewPipe


I'm personally done with Retroid and Unisoc devices
- [I](https://github.com/user-attachments/assets/31ae9c6c-3d7e-4a37-9da1-065a3508984d)
- [am](https://github.com/user-attachments/assets/e1340f8d-3863-401e-a65f-222e1f77eb2c)
- [done](https://github.com/user-attachments/assets/d230e73d-bf46-4a6d-8c9b-1e6509ab3726)
- Tell Retroid's boss he'll need to get another [loan and not botch a response](https://retrohandhelds.gg/a-new-screen-is-coming-for-the-retroid-pocket-mini/) to device failures for me to trust that company again.

Only a few devices can truly boot into an alternative OS natively with [SailfishOS](https://commerce.jolla.com/products/jolla-community-phone), [PostMarketOS](https://wiki.postmarketos.org/wiki/Category:Unisoc) and [Ubuntu Touch](https://devices.ubuntu-touch.io/device/gta8/) while having *screen access* and not even all of those device's respective models as people trying Ubuntu Touch found out.

But this was before I've made these attempts. This is my documention on what I've tried, as organized as possible in my view.

# Table of Contents
  0. [Prelude](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/Prelude)
  1. [An Android Career?](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/1)
  - 1.05. [Layout modifications](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/1.05)
  - 1.15. [Zackptg5](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/1.15)
  2. [Postmarketos](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/2)
  3. [u-boot](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/3)
  4. [Droidian](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/4)
  5. [Unix-like](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/5)
  6. [JingOS](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/6)
  7. [UBPorts](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/7)
  8. [GarlicOS](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/8)
  9. [Ubuntu twrp](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/9)
  10. [Chimera/Void](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/10)
  11. [Alpine](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/11)
  12. [Debian](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/12)
  13. [init](https://github.com/Seriousattempts/rp3plus-native-attempts/releases/tag/13)


