#!/data/data/com.termux/files/usr/bin/bash

time1="$( date +"%r" )"

# Function to detect and mount ext4 SD card
detect_and_mount_ext4_sd() {
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Checking for ext4 SD card...\n" >&2
    
    # Check if running as root or can use su
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v su &> /dev/null; then
            printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Root access required but 'su' command not found\n" >&2
            return 1
        fi
    fi
    
    # Check if mmcblk1p1 exists
    if [ ! -b "/dev/block/mmcblk1p1" ]; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m SD card block device /dev/block/mmcblk1p1 not found\n" >&2
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[INFO]:\e[0m \x1b[38;5;87m Available block devices:\n" >&2
        ls -la /dev/block/mmcblk* 2>/dev/null >&2
        return 1
    fi
    
    # Check filesystem type
    FS_TYPE=$(su -c "blkid /dev/block/mmcblk1p1 | grep -oP 'TYPE=\"\K[^\"]+'" 2>/dev/null)
    if [ "$FS_TYPE" != "ext4" ]; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m SD card is not ext4 format (detected: $FS_TYPE)\n" >&2
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[INFO]:\e[0m \x1b[38;5;87m Please format SD card as ext4 in TWRP\n" >&2
        return 1
    fi
    
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Found ext4 SD card at /dev/block/mmcblk1p1\n" >&2
    
    # Create mount point
    MOUNT_POINT="/data/local/3PLUSLINUX"
    su -c "mkdir -p $MOUNT_POINT" 2>/dev/null
    
    # Check if already mounted
    if mount | grep -q "$MOUNT_POINT"; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m SD card already mounted at $MOUNT_POINT\n" >&2
    else
        # Mount the SD card
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Mounting ext4 SD card to $MOUNT_POINT...\n" >&2
        su -c "mount -t ext4 /dev/block/mmcblk1p1 $MOUNT_POINT" 2>/dev/null
        
        if [ $? -ne 0 ]; then
            printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Failed to mount SD card\n" >&2
            return 1
        fi
    fi
    
    # Set permissions
    su -c "chmod 755 $MOUNT_POINT" 2>/dev/null
    su -c "chown $(id -u):$(id -g) $MOUNT_POINT" 2>/dev/null
    
    # Test write access
    if ! touch "$MOUNT_POINT/.test" 2>/dev/null; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Cannot write to mounted SD card\n" >&2
        return 1
    fi
    rm -f "$MOUNT_POINT/.test"
    
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m SD card successfully mounted and writable\n" >&2
    echo "$MOUNT_POINT"
    return 0
}

install1 () {

# Detect and mount ext4 SD card
INSTALL_BASE=$(detect_and_mount_ext4_sd)
if [ $? -ne 0 ] || [ -z "$INSTALL_BASE" ]; then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m ext4 SD card detection/mounting failed\n"
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[INFO]:\e[0m \x1b[38;5;87m Please ensure:\n"
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[INFO]:\e[0m \x1b[38;5;87m 1. SD card is formatted as ext4\n"
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[INFO]:\e[0m \x1b[38;5;87m 2. Device has root access\n"
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[INFO]:\e[0m \x1b[38;5;87m 3. Magisk is installed and working\n"
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

cp setupubuntu.sh ubuntu-fs/root/ 2>/dev/null || printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Could not copy setupubuntu.sh\n"
cp change_lsb.py ubuntu-fs/root/ 2>/dev/null || printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Could not copy change_lsb.py\n"

# Create TWRP launcher script
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Creating TWRP launcher script...\n"
cat > start-twrp.sh <<- 'TWRPEOF'
#!/system/bin/sh
# Ubuntu in TWRP - ext4 SD Card Launcher

MOUNT_POINT="/data/local/3PLUSLINUX"
SD_DEVICE="/dev/block/mmcblk1p1"

# Check if SD device exists
if [ ! -b "$SD_DEVICE" ]; then
    echo "ERROR: SD card device $SD_DEVICE not found"
    exit 1
fi

# Create mount point if doesn't exist
mkdir -p "$MOUNT_POINT"

# Check if already mounted
if ! mount | grep -q "$MOUNT_POINT"; then
    echo "Mounting ext4 SD card..."
    mount -t ext4 "$SD_DEVICE" "$MOUNT_POINT"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to mount SD card"
        exit 1
    fi
fi

# Check if Ubuntu installation exists
if [ ! -d "$MOUNT_POINT/ubuntu-fs" ]; then
    echo "ERROR: Ubuntu installation not found at $MOUNT_POINT/ubuntu-fs"
    exit 1
fi

echo "Entering Ubuntu environment..."
cd "$MOUNT_POINT" || exit 1

# Use chroot to enter Ubuntu
chroot "$MOUNT_POINT/ubuntu-fs" /bin/bash --login || chroot "$MOUNT_POINT/ubuntu-fs" /bin/sh
TWRPEOF

chmod +x start-twrp.sh

printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Installation location: ${INSTALL_BASE}\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m TWRP launcher: ${INSTALL_BASE}/start-twrp.sh\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The installation has been completed! You can now launch Ubuntu with ./startubuntu.sh\n"
printf "\e[0m"

}

install1
