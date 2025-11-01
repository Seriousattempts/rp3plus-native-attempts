#!/bin/bash
# UNISOC Hardware Service Installation Script
# Compatible with both systemd and SysV init systems

echo "=== Installing UNISOC Hardware Service ==="

# Detect init system
INIT_SYSTEM="unknown"
if [ -d "/run/systemd/system" ] && command -v systemctl >/dev/null 2>&1; then
    INIT_SYSTEM="systemd"
elif [ -d "/etc/init.d" ] || [ -w "/etc" ]; then
    INIT_SYSTEM="sysvinit"
fi

echo "Detected init system: $INIT_SYSTEM"

# Function to install for systemd
install_systemd_service() {
    echo "Installing systemd service..."
    
    mkdir -p /etc/systemd/system
    
    cat << 'EOF' > /etc/systemd/system/unisoc-hardware.service
[Unit]
Description=UNISOC Hardware Device Configuration
After=local-fs.target systemd-modules-load.service
Requires=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-unisoc-hardware
StandardOutput=append:/var/log/unisoc-hardware.log
StandardError=append:/var/log/unisoc-hardware.log
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 /etc/systemd/system/unisoc-hardware.service
    
    if systemctl daemon-reload 2>/dev/null; then
        echo "✓ systemd daemon reloaded"
    else
        echo "⚠ Failed to reload systemd"
        return 1
    fi
    
    if systemctl enable unisoc-hardware.service 2>/dev/null; then
        echo "✓ Service enabled"
    else
        echo "⚠ Failed to enable service"
        return 1
    fi
    
    if systemctl start unisoc-hardware.service 2>/dev/null; then
        echo "✓ Service started"
    else
        echo "⚠ Service failed to start"
        return 1
    fi
    
    echo ""
    echo "=== Service Status ==="
    systemctl status unisoc-hardware.service --no-pager 2>/dev/null
    
    echo ""
    echo "To view logs: journalctl -u unisoc-hardware.service"
    echo "To restart: systemctl restart unisoc-hardware.service"
}

# Function to install for SysV init / rc.local
install_rclocal_service() {
    echo "Installing rc.local service..."
    
    # Create rc.local if it doesn't exist
    if [ ! -f /etc/rc.local ]; then
        cat << 'EOF' > /etc/rc.local
#!/bin/sh -e
#
# rc.local - executed at the end of each multiuser runlevel

exit 0
EOF
        chmod +x /etc/rc.local
        echo "✓ Created /etc/rc.local"
    fi
    
    # Check if UNISOC hardware setup is already in rc.local
    if grep -q "setup-unisoc-hardware" /etc/rc.local 2>/dev/null; then
        echo "✓ UNISOC hardware setup already in rc.local"
    else
        # Add UNISOC hardware setup before the 'exit 0' line
        sed -i '/^exit 0/i \
# UNISOC Hardware Configuration\
/usr/local/bin/setup-unisoc-hardware >> /var/log/unisoc-hardware.log 2>&1 &\
' /etc/rc.local
        echo "✓ Added UNISOC hardware setup to rc.local"
    fi
    
    # Create init.d directory if it doesn't exist
    mkdir -p /etc/init.d
    
    # Create init.d script for manual control
    cat << 'EOF' > /etc/init.d/unisoc-hardware
#!/bin/sh
### BEGIN INIT INFO
# Provides:          unisoc-hardware
# Required-Start:    $local_fs
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: UNISOC Hardware Device Configuration
### END INIT INFO

case "$1" in
    start)
        echo "Starting UNISOC hardware configuration..."
        /usr/local/bin/setup-unisoc-hardware >> /var/log/unisoc-hardware.log 2>&1 &
        echo "✓ UNISOC hardware configuration started"
        ;;
    stop)
        echo "UNISOC hardware configuration has no stop action"
        ;;
    restart|reload|force-reload)
        echo "Restarting UNISOC hardware configuration..."
        /usr/local/bin/setup-unisoc-hardware >> /var/log/unisoc-hardware.log 2>&1 &
        echo "✓ UNISOC hardware configuration restarted"
        ;;
    status)
        echo "UNISOC hardware configuration is a one-shot service"
        if [ -f /var/log/unisoc-hardware.log ]; then
            echo "Last 20 lines of log:"
            tail -n 20 /var/log/unisoc-hardware.log
        else
            echo "No log file found"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|force-reload|status}"
        exit 1
        ;;
esac

exit 0
EOF
    
    chmod +x /etc/init.d/unisoc-hardware
    echo "✓ Created /etc/init.d/unisoc-hardware"
    
    # Enable the init script if update-rc.d is available
    if command -v update-rc.d >/dev/null 2>&1; then
        if update-rc.d unisoc-hardware defaults 2>/dev/null; then
            echo "✓ Service enabled via update-rc.d"
        else
            echo "⚠ Failed to enable via update-rc.d (not critical)"
        fi
    else
        echo "ℹ update-rc.d not available, skipping auto-enable"
    fi
    
    # Run the hardware setup now
    echo "Running UNISOC hardware configuration now..."
    if /usr/local/bin/setup-unisoc-hardware >> /var/log/unisoc-hardware.log 2>&1; then
        echo "✓ Hardware configuration completed successfully"
    else
        echo "⚠ Hardware configuration had warnings (check log)"
    fi
    
    # Display the log contents
    echo ""
    echo "=== UNISOC Hardware Configuration Log ==="
    if [ -f /var/log/unisoc-hardware.log ]; then
        cat /var/log/unisoc-hardware.log
    else
        echo "Log file not found"
    fi
    echo "=== End of UNISOC Hardware Configuration Log ==="
    echo ""
    
    echo "Service installed successfully!"
    echo ""
    echo "Usage:"
    echo "  To view logs: cat /var/log/unisoc-hardware.log"
    echo "  To restart: /etc/init.d/unisoc-hardware restart"
    echo "  To check status: /etc/init.d/unisoc-hardware status"
    echo "  To run manually: /usr/local/bin/setup-unisoc-hardware"
}

# Install based on detected init system
case "$INIT_SYSTEM" in
    systemd)
        install_systemd_service
        ;;
    sysvinit|unknown)
        install_rclocal_service
        ;;
esac

echo ""
echo "=== Service installation complete ==="
