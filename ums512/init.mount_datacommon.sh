#!/system/bin/sh

exec >/datacommon/mount.log 2>&1
set -x

# Spreadtrum-specific mount adjustments
ANDROID_WRITABLE="/mnt/androidwritable"
STORAGE_EMULATED="$ANDROID_WRITABLE/emulated/0"
COMMON_DATA="$STORAGE_EMULATED/CommonData"

mount_dir(){
  case "$1" in
    "Android"|"lost+found") return ;;
  esac
  dest="$COMMON_DATA/$1"
  mkdir -p "$dest" || return 1
  # Use bind mounts for Spreadtrum's writable partition
  mount -o bind "/datacommon/$1" "$dest"
  echo "Used bind mounts for Spreadtrum's writable partition"
}

# Create mountpoint if missing
mkdir -p /datacommon
echo "Created mountpoint"

# F2FS integrity check
if command -v blkid >/dev/null 2>&1; then
  if ! blkid /dev/block/mmcblk0p76 | grep -q 'TYPE="f2fs"'; then
    echo "ERROR: userdata not F2FS formatted"
    exit 1
  fi
else
  echo "blkid not available, assuming F2FS filesystem"
fi

# F2FS repair before mount
if command -v fsck.f2fs >/dev/null 2>&1; then
  fsck.f2fs -a /dev/block/mmcblk0p76 || {
    echo "F2FS errors detected, attempting repair..."
    fsck.f2fs -f /dev/block/mmcblk0p76
  }
else
  echo "fsck.f2fs not available, skipping filesystem check"
fi

mount -t f2fs -o rw,lazytime,noatime,nosuid,nodev,discard,compress_algorithm=zstd:6,compress_chksum,atgc,gc_merge,fsync_mode=nobarrier \
  /dev/block/mmcblk0p76 /datacommon || {
  echo "F2FS mount failed, reformatting to EXT4"
  umount /datacommon
  mkfs.ext4 -F -O ^metadata_csum,^64bit /dev/block/mmcblk0p76
  mount -t ext4 -o rw,noatime,nosuid,nodev,discard /dev/block/mmcblk0p76 /datacommon || exit 1
}

# Spreadtrum SELinux context adjustment
chcon -R "u:object_r:media_rw_data_file:s0" /datacommon

# Wait for Android storage initialization
count=0
until [ -d $STORAGE_EMULATED/Android ] || [ -d $ANDROID_WRITABLE/emulated/0/Android ]; do
  sleep 1
  count=$((count+1))
  [ $count -ge 30 ] && exit 2
done

# Primary bind mount
mkdir -p $COMMON_DATA || exit 3
mount -o bind /datacommon $COMMON_DATA || exit 4

# Dynamic mounts with F2FS compression support
if [ -f /datacommon/mounts.txt ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] && mount_dir "$line" || echo "Failed: $line"
  done < /datacommon/mounts.txt
fi

# Symlink for legacy compatibility
ln -sf $COMMON_DATA $ANDROID_WRITABLE/CommonData

exit 0
