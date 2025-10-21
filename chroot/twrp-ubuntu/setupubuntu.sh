#!/bin/bash
export ZSH_DISABLE_COMPFIX=true
export TERM=xterm-256color
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games
export PYTHONHASHSEED=0

echo "=== Ubuntu Hardware Setup - Installing all packages ==="
echo "This will take 10-15 minutes depending on network speed..."

# Update system
apt-get update && apt-get -y upgrade

# Base system tools
echo "Installing base tools..."
apt-get install -y zsh curl wget git sed lsb-release neofetch nano vim htop

# Weston and graphics stack
echo "Installing Weston (Wayland compositor)..."
apt-get install -y weston libdrm2 libdrm-common libgbm1 libinput10 libegl1 libgles2 libwayland-server0 mesa-utils mesa-vulkan-drivers

# Audio support
echo "Installing audio stack..."
apt-get install -y pulseaudio alsa-utils alsa-base pipewire-audio

# Core system & block devices
echo "Installing system utilities..."
apt-get install -y udev util-linux coreutils parted gdisk mmc-utils

# Serial & TTY
echo "Installing serial tools..."
apt-get install -y setserial minicom screen

# USB support
echo "Installing USB tools..."
apt-get install -y usbutils usb-modeswitch usb-modeswitch-data

# Video devices
echo "Installing video tools..."
apt-get install -y v4l-utils

# Network tools
echo "Installing network tools..."
apt-get install -y net-tools iproute2 wireless-tools wpasupplicant

# Modem support (UNISOC)
echo "Installing modem support..."
apt-get install -y modemmanager libqmi-utils libmbim-utils

# Input, sensors, GPIO, I2C, SPI
echo "Installing hardware interface tools..."
apt-get install -y input-utils evtest libiio-utils gpiod i2c-tools python3-spidev

# Framebuffer, RNG, watchdog
echo "Installing framebuffer and hardware tools..."
apt-get install -y fbset rng-tools5 haveged watchdog

# Fix LSB release
python3 /root/change_lsb.py

# Create ZSH config
cat > /root/.zshrc <<-'EOM'
export ZSH_DISABLE_COMPFIX=true
export TERM=xterm-256color
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games
export PYTHONHASHSEED=0
clear
echo "Ubuntu Hardware Desktop - Type 'weston' to start GUI"
EOM

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "To test Weston:"
echo "  1. Exit this shell"
echo "  2. In TWRP terminal: sh start.sh"
echo "  3. Inside Ubuntu: weston --backend=drm-backend.so --tty=1"
echo ""
