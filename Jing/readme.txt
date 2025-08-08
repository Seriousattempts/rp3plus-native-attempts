Jing Base1:

0x5500
0x9EFFFE00
nr_fixnv1
splloader
prodnv
miscdata
uboot_log
vbmeta
vbmeta_system
vbmeta_vendor
nr_spl
nr_sml
nr_boot
nr_pmsys
l_agdsp
l_modem_a
l_deltanv_a 
l_gdsp_
l_ldsp_a
l_agdsp_a
nr_runtimenv1
nr_modem
nr_v3phy
nr_nrphy
nr_nrdsp1
nr_nrdsp2
nr_deltanv
gnssmodem
wcnmodem
boot
dtbo
recovery
system
vendor
rootfs
rfactory
userdata
logo
fbootlogo
lowbattery
cache
socko
odmko
misc
sysdumpdb
trustos
teecfg
sml
uboot
persist
metadata
splloader
splloader

Stock 3.5:

cache.img
dtbo.img
odmko.img
misc.img
socko.img
u-boot-sign.bin
u-boot-spl-16k-sign.bin
gnssmodem.bin
EXEC_KERNEL_IMAGE.bin
fdl1-sign.bin
fdl2-sign.bin
Halium boot.img
persist.img
prodnv.img
teecfg-sign.bin
tos-sign.bin
userdata.img
sml-sign.bin


Add 3 images for:
bootlogo
fastbootlogo
low battery

Flash sharkl5pro_cm4.bin to
- nr_pmsys & l_pmsys
- rfactory will have the files within the image with the selected files earlier

Flash sharkl5pro_pubcp_customer_nvitem.bin to
- nr_fixnv1 & nr_deltanv

Use fixnv1 (sharkl5pro_pubcp_customer_nvitem.bin) with nr_v3phy & nr_nrphy
- Same Base1 size

Replace SPL_LOADER_UFS with u-boot-spl-16k-sign.bin but left unchecked

Unchecked ERASESPL



[PAC_ums512_1h10]
VBMETA_SYSTEM_EXT=1@vbmeta_system_ext.img@0x980@0xCFDEB4
DSP_LTE_LTE=1@sharkl5pro_pubcp_LTEA_DSP.bin@0x1400000@0x169CB08
SML=1@sml-sign.bin@0xF6C4@0x1ECE90
ERASEUBOOTLOG=1@
MODEM_WCN=1@EXEC_KERNEL_IMAGE.bin@0xE73B0@0xC0BAB8
BOOTLOGO=1@unisoc_HD_720_1280_24bit.bmp@0xF5284@0xF6C0C
DSP_LTE_CDMA=1@sharkl5pro_pubcp_CDMA_DSP.bin@0x100000@0x10719EE9C
BOOT=1@boot.img@0x4000000@0x10319EE9C
VBMETA_PRODUCT=1@vbmeta_product.img@0x980@0x2A9CB08
DFS=1@sharkl5pro_cm4.bin@0x100000@0x100F76D88
PERSIST=1@persist.img@0x200000@0x100C368FC
SOCKO=1@socko.img@0x20E3088@0x2B93710
CONFILE=0@
ODMKO=1@odmko.img@0x73088@0x100F03D00
ERASEMETADATA=1@
PRODNV=1@prodnv.img@0xB04C@0xCF2E68
ERASEMISC=1@
MODEM_LTE=1@SC9600_sharkl5pro_pubcp_modem.dat@0x1900000@0x10189EE9C
TRUSTOS=1@tos-sign.bin@0x1AFBB4@0x1009ABFA0
SUPER=1@super.img@0xFBD35808@0x4C76798
ERASEUBOOT=1@
FDL=1@fdl1-sign.bin@0xE874@0xE8398
USERDATA=1@userdata.img@0x228114@0x101676D88
MODEM_LTE_DELTANV=1@sharkl5pro_pubcp_customer_deltanv.bin@0x1004@0x2B9270C
VBMETA=1@vbmeta-sign.img@0x100000@0x14FF834
DTBO=1@dtbo.img@0x800000@0xCFE834
TEECFG=1@teecfg-sign.bin@0xFB4@0x169BB54
CACHE=1@cache.img@0xB04C@0x1690B08
MODEM_GNSS=1@gnssmodem.bin@0x912D4@0x15FF834
VBMETA_VENDOR=1@vbmeta_vendor.img@0x1000@0x14FE834
FASTBOOT_LOGO=1@unisoc_HD_720_1280_24bit.bmp(1)@0xF5284@0x2A9D488
DSP_LTE_AG=1@sharkl5pro_pubcp_AGCP_DSP.bin@0x600000@0x101076D88
FLASH_LTE=1@
ERASESYSDUMPDB=1@
DSP_LTE_GGE=1@sharkl5pro_pubcp_DM_DSP.bin@0xA00000@0x1FC554
FDL2=1@fdl2-sign.bin@0xCD404@0x1AF94
UBOOTLOADER=1@u-boot-sign.bin@0xCD404@0x100E368FC
NV_LTE=1@sharkl5pro_pubcp_customer_nvitem.bin@0xDADA8@0x100B5BB54
PHASECHECK=1@
SPLLOADER=1@u-boot-spl-16k-sign.bin@0xF564@0xBFC554
VBMETA_SYSTEM=1@vbmeta_system.img@0x1000@0x1EBE90
[Selection]
SelectProduct=PAC_ums512_1h10