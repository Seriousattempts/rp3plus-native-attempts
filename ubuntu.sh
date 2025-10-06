#!/data/data/com.termux/files/usr/bin/bash

time1="$( date +"%r" )"

# Function to detect and mount F2FS SD card
detect_and_mount_sdcard() {
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Detecting F2FS SD card...\n"
    
    # Check if mmcblk1p1 exists
    if [ ! -b "/dev/block/mmcblk1p1" ]; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m SD card block device /dev/block/mmcblk1p1 not found\n"
        return 1
    fi
    
    # Verify it's F2FS formatted
    FSTYPE=$(su -c "blkid /dev/block/mmcblk1p1 | grep -o 'TYPE=\"[^\"]*\"' | cut -d'\"' -f2")
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Detected filesystem: $FSTYPE\n"
    
    if [ "$FSTYPE" != "f2fs" ]; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m SD card is not F2FS formatted (found: $FSTYPE)\n"
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[INFO]:\e[0m \x1b[38;5;87m Please format SD card as F2FS in TWRP first\n"
        return 1
    fi
    
    # Create mount point
    MOUNT_POINT="/data/local/3PLUSLINUX_SD"
    su -c "mkdir -p $MOUNT_POINT"
    
    # Check if already mounted
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m SD card already mounted at $MOUNT_POINT\n"
        return 0
    fi
    
    # Mount the SD card
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Mounting F2FS SD card to $MOUNT_POINT...\n"
    su -c "mount -t f2fs /dev/block/mmcblk1p1 $MOUNT_POINT"
    
    if [ $? -ne 0 ]; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Failed to mount SD card\n"
        return 1
    fi
    
    # Set permissions
    su -c "chmod 777 $MOUNT_POINT"
    su -c "chown $(whoami):$(whoami) $MOUNT_POINT"
    
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m SD card successfully mounted at $MOUNT_POINT\n"
    return 0
}

install1 () {

# Detect and mount F2FS SD card
detect_and_mount_sdcard
if [ $? -ne 0 ]; then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m SD card detection/mount failed\n"
    printf "\e[0m"
    exit 1
fi

# Set installation base to SD card
INSTALL_BASE="/data/local/3PLUSLINUX_SD/3PLUSLINUX"
SD_MOUNT="/data/local/3PLUSLINUX_SD"

# Create installation directory on SD card
mkdir -p "$INSTALL_BASE"
if [ $? -ne 0 ]; then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Failed to create directory on SD card\n"
    printf "\e[0m"
    exit 1
fi

cd "$INSTALL_BASE" || exit 1
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Working directory: $INSTALL_BASE\n"

apt-get update && apt-get upgrade -y
apt-get update
apt-get install -y wget proot git

mkdir -p mnt
directory=ubuntu-fs
UBUNTU_VERSION=jammy

if [ -d "$directory" ];then
    first=1
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Skipping the download and the extraction\n"
elif [ -z "$(command -v proot)" ];then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Please install proot.\n"
    printf "\e[0m"
    exit 1
elif [ -z "$(command -v wget)" ];then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Please install wget.\n"
    printf "\e[0m"
    exit 1
fi

if [ "$first" != 1 ];then
    if [ -f "ubuntu.tar.gz" ];then
        rm -rf ubuntu.tar.gz
    fi
    if [ ! -f "ubuntu.tar.gz" ];then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Downloading the ubuntu rootfs, please wait...\n"
        ARCHITECTURE=$(dpkg --print-architecture)
        case "$ARCHITECTURE" in
            aarch64) ARCHITECTURE=arm64;;
            arm) ARCHITECTURE=armhf;;
            amd64|x86_64) ARCHITECTURE=amd64;;
            *)
                printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Unknown architecture :- $ARCHITECTURE"
                exit 1
            ;;
        esac

        wget https://partner-images.canonical.com/core/${UBUNTU_VERSION}/current/ubuntu-${UBUNTU_VERSION}-core-cloudimg-${ARCHITECTURE}-root.tar.gz -q -O ubuntu.tar.gz 
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Download complete!\n"
    fi

    cur=`pwd`
    mkdir -p $directory
    cd $directory
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Decompressing the ubuntu rootfs, please wait...\n"
    proot --link2symlink tar -zxf $cur/ubuntu.tar.gz --exclude='dev'||:
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The ubuntu rootfs have been successfully decompressed!\n"
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Fixing the resolv.conf, so that you have access to the internet\n"
    printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > etc/resolv.conf
    stubs=()
    stubs+=('usr/bin/groups')
    for f in ${stubs[@]};do
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Writing stubs, please wait...\n"
        echo -e "#!/bin/sh\nexit" > "$f"
    done
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully wrote stubs!\n"
    cd $cur
fi

mkdir -p ubuntu-binds
bin=startubuntu.sh
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Creating the start script, please wait...\n"
cat > $bin <<- EOM
#!/bin/bash
cd \$(dirname \$0)
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
## uncomment following line if you are having FATAL: kernel too old message.
#command+=" -k 4.14.81"
command+=" --link2symlink"
command+=" -0"
command+=" -r $directory"
if [ -n "\$(ls -A ubuntu-binds 2>/dev/null)" ]; then
    for f in ubuntu-binds/* ;do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b /sys"
command+=" -b ubuntu-fs/tmp:/dev/shm"
command+=" -b ${INSTALL_BASE}:/3pluslinux"
command+=" -b /:/host-rootfs"
command+=" -b /sdcard"
command+=" -b /storage"
command+=" -b /mnt"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The start script has been successfully created!\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Fixing shebang of startubuntu.sh, please wait...\n"
termux-fix-shebang $bin
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully fixed shebang of startubuntu.sh! \n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Making startubuntu.sh executable please wait...\n"
chmod +x $bin
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully made startubuntu.sh executable\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Cleaning up please wait...\n"
rm ubuntu.tar.gz -rf
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully cleaned up!\n"

# Copy setup scripts
cp setupubuntu.sh ubuntu-fs/root/ 2>/dev/null || printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Could not copy setupubuntu.sh\n"
cp change_lsb.py ubuntu-fs/root/ 2>/dev/null || printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Could not copy change_lsb.py\n"

# Create TWRP start script
cat > start.sh <<- 'TWRPEOF'
#!/system/bin/sh
# Ubuntu in TWRP Launcher for F2FS SD Card
# Run this from TWRP: sh start.sh

MOUNT_POINT="/data/local/3PLUSLINUX_SD"
INSTALL_PATH="${MOUNT_POINT}/3PLUSLINUX"

echo "Mounting F2FS SD card..."
mkdir -p "$MOUNT_POINT"
mount -t f2fs /dev/block/mmcblk1p1 "$MOUNT_POINT"

if [ ! -d "$INSTALL_PATH/ubuntu-fs" ]; then
    echo "Error: Ubuntu installation not found at $INSTALL_PATH"
    exit 1
fi

cd "$INSTALL_PATH" || exit 1

# Mount necessary filesystems
mount -t proc proc "$INSTALL_PATH/ubuntu-fs/proc" 2>/dev/null
mount -t sysfs sys "$INSTALL_PATH/ubuntu-fs/sys" 2>/dev/null
mount --bind /dev "$INSTALL_PATH/ubuntu-fs/dev" 2>/dev/null

echo "Entering Ubuntu environment..."
chroot "$INSTALL_PATH/ubuntu-fs" /bin/bash --login || chroot "$INSTALL_PATH/ubuntu-fs" /bin/sh
TWRPEOF

chmod +x start.sh

printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Installation location: ${INSTALL_BASE}\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m SD card mount point: ${SD_MOUNT}\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m TWRP launcher: ${INSTALL_BASE}/start.sh\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The installation has been completed! You can now launch Ubuntu with ./startubuntu.sh\n"
printf "\e[0m"

}

install1
