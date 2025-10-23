#!/bin/sh
# OpenRC Service Installation Script for UNISOC Hardware

echo "=== Installing UNISOC Hardware Service ==="

# Create OpenRC service
cat << 'EOF' > /etc/init.d/unisoc-hardware
#!/sbin/openrc-run

description="UNISOC Hardware Device Configuration"

depend() {
    need localmount
    after modules
}

start() {
    ebegin "Configuring UNISOC hardware devices"
    /usr/local/bin/setup-unisoc-hardware >> /var/log/unisoc-hardware.log 2>&1
    eend $?
}

stop() {
    ebegin "Stopping UNISOC hardware service"
    eend 0
}
EOF

# Make service executable
chmod +x /etc/init.d/unisoc-hardware

# Enable service at boot (default runlevel)
if rc-update add unisoc-hardware default; then
    echo "✓ UNISOC hardware service enabled successfully"
else
    echo "⚠ Failed to enable UNISOC hardware service"
fi

# Start the service now
if rc-service unisoc-hardware start; then
    echo "✓ UNISOC hardware service started successfully"
else
    echo "⚠ Service may have already been started or encountered issues"
fi

echo "=== Service installation complete ==="
