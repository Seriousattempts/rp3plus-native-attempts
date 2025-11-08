#!/bin/bash
# Debian Linux Hardware Support Package Installation Script
# Tailored for UNISOC device with Panfrost GPU and Fluxbox window manager
# Optimized for ARM Mali GPU with comprehensive hardware support

LOG_FILE="/data/package_install.log"
echo "=== Debian Package Installation Started at $(date) ===" > "$LOG_FILE"

# Function to log messages
log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to install packages with error handling
install_pkg() {
    local pkg="$1"
    log_msg "Installing: $pkg"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
        log_msg "  ✓ SUCCESS: $pkg"
        return 0
    else
        log_msg "  ⚠ FAILED/SKIPPED: $pkg"
        return 1
    fi
}

# Function to install from backports repository
install_backports_pkg() {
    local pkg="$1"
    log_msg "Installing from backports: $pkg"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y -t bookworm-backports "$pkg" >> "$LOG_FILE" 2>&1; then
        log_msg "  ✓ SUCCESS: $pkg (backports)"
        return 0
    else
        log_msg "  ⚠ FAILED/SKIPPED: $pkg (backports)"
        return 1
    fi
}

# Update package database
log_msg "=== Updating package database ==="
apt-get update >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1
apt-get modernize-sources -y >> "$LOG_FILE" 2>&1


# Extra tool support
log_msg "=== Installing Extra tools support ==="
install_pkg android-tools-adb
install_pkg android-tools-fastboot
install_pkg rng-tools
install_pkg libcommons-daemon-java
install_pkg libcap2
install_pkg libcap2-bin
install_pkg grep
install_pkg kmod
install_pkg cron
install_pkg kbd
install_pkg libssl3
install_pkg cryptsetup
install_pkg acl
install_pkg attr
install_pkg libmount1
install_pkg libpcre2-8-0
install_pkg openssl
install_pkg libblkid1
install_pkg wine
install_pkg steam-devices
install_pkg libglvnd-dev
install_pkg libxkbcommon-dev
install_pkg meson
install_pkg cmake
install_pkg libvulkan-dev
install_pkg libglm-dev
install_pkg libpango1.0-dev
install_pkg libcairo2-dev
install_pkg libxml2-dev
install_pkg gcc
install_pkg g++
install_pkg extrepo
install_pkg libselinux1
install_pkg strace

log_msg "Note: mdevd and mdev-conf not needed on Debian (uses udev)"

# Development build Tools
log_msg "=== Installing Development Tools and Build Dependencies ==="
install_pkg build-essential
install_pkg gcc
install_pkg g++
install_pkg make
install_pkg cmake
install_pkg libc6-dev
log_msg "Note: Debian uses glibc (libc6-dev) instead of musl"

# Detect architecture and install appropriate kernel headers
ARCH=$(dpkg --print-architecture)
log_msg "Detected architecture: $ARCH"
case "$ARCH" in
    amd64)
        install_pkg linux-headers-amd64
        ;;
    arm64)
        install_pkg linux-headers-arm64
        ;;
    armhf)
        install_pkg linux-headers-armmp
        ;;
    i386)
        install_pkg linux-headers-686
        ;;
    *)
        log_msg "⚠ Unknown architecture, attempting generic headers"
        install_pkg linux-headers-generic || log_msg "⚠ Could not install kernel headers"
        ;;
esac

install_pkg opencl-headers

# Core System & Device Management (for all block devices)
log_msg "=== Installing Core System Packages ==="
install_pkg udev
install_pkg libudev1
install_pkg util-linux
install_pkg coreutils
install_pkg parted
install_pkg gdisk
install_pkg mmc-utils
log_msg "Note: busybox-extras not needed on Debian (uses full GNU utilities)"

# Serial Communication (8 ttyGS + 2 ttyS devices)
log_msg "=== Installing Serial Communication Packages ==="
install_pkg setserial
install_pkg minicom
install_pkg screen
install_pkg socat
log_msg "Note: agetty is included in util-linux (already installed)"

# USB Support (bus/usb devices)
log_msg "=== Installing USB Support Packages ==="
install_pkg usbutils
install_pkg libusb-1.0-0
install_pkg libusb-1.0-0-dev
install_pkg usb-modeswitch
install_pkg usb-modeswitch-data
install_pkg udisks2
install_pkg libudisks2-dev

# Audio/ALSA Support (31 ALSA devices in /dev/snd/)
log_msg "=== Installing Audio Support Packages ==="
install_pkg alsa-utils
install_pkg libasound2
install_pkg libasound2-dev
install_pkg alsa-ucm-conf
install_pkg pulseaudio
install_pkg pipewire
install_pkg pipewire-alsa
install_pkg pipewire-pulse
install_pkg libasound2-plugins
install_pkg pavucontrol
install_pkg jackd2

# Video/Camera Support
log_msg "=== Installing Video Support Packages ==="
install_pkg v4l-utils
install_pkg libv4l-dev
install_pkg libv4l-0
install_pkg ffmpeg
install_pkg libavcodec59
install_pkg libavformat59
install_pkg libjpeg62-turbo
install_pkg libvpx7

# Graphics/DRM Support with Panfrost for ARM Mali GPU
log_msg "=== Installing Graphics Support Packages ==="
install_pkg libdrm2
install_pkg libdrm-dev
install_pkg libdrm-tests
install_pkg mesa-utils
install_pkg libglx-mesa0
install_pkg libgl1-mesa-dev
install_pkg libgl1-mesa-dri
install_pkg libgl1
install_pkg libgles2-mesa
install_pkg libegl1-mesa
install_pkg libgbm1
install_pkg mesa-utils-extra
install_pkg kmscube
install_pkg libgbm-dev
install_pkg libegl1-mesa-dev
install_pkg libgles2-mesa-dev
install_pkg mesa-vulkan-drivers
install_pkg mesa-vdpau-drivers
install_pkg drm-info
install_pkg libvirglrenderer-dev
install_pkg libvirglrenderer1

# Vulkan support
log_msg "=== Installing Vulkan Support ==="
install_pkg vulkan-validationlayers
install_pkg libvulkan1
install_pkg vulkan-tools

# OpenBox
log_msg "=== Installing Openbox ==="
install_pkg openbox

# LightDM
log_msg "=== Installing LightDM ==="
install_pkg lightdm

# Wayland
install_pkg libwayland-client0
install_pkg libwayland-server0
install_pkg cage
install_pkg greetd
install_pkg wlgreet
install_pkg libwayland-dev
install_pkg wayland-utils
install_pkg wayland-protocols
install_pkg libweston-14-0
install_pkg libweston-14-dev
install_pkg imv
install_pkg wl-clipboard

# Weston
log_msg "=== Installing Weston ==="
install_pkg weston
install_pkg seatd
install_pkg fonts-dejavu

# Wayfire
log_msg "=== Installing Wayfire ==="
install_pkg wayfire
install_pkg wayfire-dev

# wlroots requirement
log_msg "=== Installing wlroots ==="
install_pkg xorg
install_pkg xvfb
install_pkg wayvnc
install_pkg wlr-randr
install_pkg sway
install_pkg libwlroots-0.18
install_pkg libwlroots-0.18-dev
install_pkg libwlroots-0.18-examples
install_pkg vncviewer

# Network Configuration (for ppp, tun devices)
log_msg "=== Installing Network Packages ==="
install_pkg iproute2
install_pkg net-tools
install_pkg wireless-tools
install_pkg iw
install_pkg wpasupplicant
install_pkg hostapd
install_pkg isc-dhcp-client
install_pkg ppp
install_pkg openssh-client
install_pkg curl
install_pkg wget

# Cellular/Modem Support (UNISOC LTE devices: 47 devices)
log_msg "=== Installing Modem/Cellular Packages ==="
install_pkg modemmanager
install_pkg libqmi-glib5
install_pkg libqmi-utils
install_pkg libmbim-glib4
install_pkg libmbim-utils
install_pkg network-manager
install_pkg mobile-broadband-provider-info

# Input Device Support (6 input event devices)
log_msg "=== Installing Input Device Packages ==="
install_pkg libinput10
install_pkg libinput-dev
install_pkg evtest
install_pkg libevdev2
install_pkg libevdev-dev
install_pkg xserver-xorg-input-libinput

# Sensor/IIO Support (2 iio:device devices)
log_msg "=== Installing Sensor Packages ==="
install_pkg libiio0
install_pkg libiio-dev
install_pkg iio-sensor-proxy
install_pkg lm-sensors
install_pkg i2c-tools

# GPIO Support (6 gpiochip devices)
log_msg "=== Installing GPIO Packages ==="
install_pkg libgpiod2
install_pkg libgpiod-dev
install_pkg python3
install_pkg python3-dev
install_pkg python3-pip

# I2C Support (6 i2c-* bus devices)
log_msg "=== Installing I2C Packages ==="
install_pkg python3-smbus

# SPI Support
log_msg "=== Installing SPI Packages ==="
install_pkg spi-tools
log_msg "Installing python3-spidev..."
install_pkg python3-spidev

# System Utilities
log_msg "=== Installing System Utilities ==="
install_pkg haveged
install_pkg watchdog
install_pkg device-tree-compiler
install_pkg dmidecode
install_pkg htop
install_pkg nano
install_pkg vim
install_pkg dbus
install_pkg dbus-x11
install_pkg policykit-1
install_pkg sudo
install_pkg upower
install_pkg tlp

# RTC Support (/dev/rtc0)
log_msg "=== RTC Support ==="
log_msg "Note: hwclock is provided by util-linux (already installed)"

# Bluetooth utilities and tools
log_msg "=== Installing Bluetooth ==="
install_pkg bluetooth
install_pkg bluez
install_pkg bluez-obexd
install_pkg bluez-meshd
install_pkg bluez-alsa-utils
install_pkg libopenobex2
install_pkg bluetoothctl

# File Manager and Desktop Utilities
log_msg "=== Installing Desktop Applications ==="
install_pkg pcmanfm
install_pkg feh
install_pkg vlc

# Flatpak Support
log_msg "=== Installing Flatpak Support ==="
install_pkg flatpak
install_pkg xdg-desktop-portal
install_pkg xdg-desktop-portal-gtk
install_pkg xdg-utils

# Enable FUSE support for Flatpak
log_msg "Enabling FUSE module..."
if [ -f /etc/modules ]; then
    if ! grep -q "^fuse$" /etc/modules 2>/dev/null; then
        echo "fuse" >> /etc/modules
        log_msg "  ✓ FUSE module added to /etc/modules"
    else
        log_msg "  ✓ FUSE module already enabled"
    fi
else
    log_msg "  ⚠ /etc/modules not found, skipping FUSE configuration"
fi

# Compression and Archive Tools
log_msg "=== Installing Archive Tools ==="
install_pkg zip
install_pkg unzip
install_pkg tar
install_pkg gzip
install_pkg bzip2
install_pkg xz-utils

# Joystick configuration
log_msg "=== Installing Joystick Tools ==="
install_pkg joystick
install_pkg joystick-dbgsym
install_pkg xserver-xorg-input-joystick
install_pkg xserver-xorg-input-joystick-dbgsym
install_pkg xserver-xorg-input-joystick-dev
install_pkg evtest
install_pkg xboxdrv
install_pkg xboxdrv-dbgsym
install_pkg antimicro

# Browsers
log_msg "=== Installing Web Browsers ==="
install_pkg firefox
install_pkg chromium
install_pkg torbrowser-launcher

log_msg "=== Package Installation Completed at $(date) ==="
log_msg "Check $LOG_FILE for detailed installation log"

# Display summary
echo ""
echo "=========================================="
echo "Installation Summary"
echo "=========================================="
dpkg --get-selections | grep -v deinstall | wc -l | xargs echo "Total packages installed:"
echo ""
echo "Log file: $LOG_FILE"
echo "=========================================="
echo ""
