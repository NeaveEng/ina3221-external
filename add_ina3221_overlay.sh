#!/bin/bash

# Script to add INA3221 overlay to boot configuration
# Usage: sudo ./add_ina3221_overlay.sh

set -e

OVERLAY_NAME="ina3221-external"
OVERLAY_PATH="/boot/${OVERLAY_NAME}.dtbo"
EXTLINUX_CONF="/boot/extlinux/extlinux.conf"
BACKUP_CONF="/boot/extlinux/extlinux.conf.ina3221-backup"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check if overlay file exists
if [ ! -f "$OVERLAY_PATH" ]; then
    echo "Error: Overlay file $OVERLAY_PATH not found!"
    echo "Please copy the overlay file first:"
    echo "sudo cp /home/dev/device-tree/${OVERLAY_NAME}.dtbo /boot/"
    exit 1
fi

# Create backup
echo "Creating backup of extlinux.conf..."
cp "$EXTLINUX_CONF" "$BACKUP_CONF"

# Check if already added
if grep -q "overlays=${OVERLAY_NAME}" "$EXTLINUX_CONF"; then
    echo "Overlay already present in extlinux.conf"
    exit 0
fi

echo "Adding INA3221 overlay to boot configuration..."

# Add overlay to the JetsonIO APPEND line
sed -i "/LABEL JetsonIO/,/APPEND/ {
    /APPEND/ s/$/ overlays=${OVERLAY_NAME}/
}" "$EXTLINUX_CONF"

echo "Successfully added overlay to boot configuration!"
echo "Backup saved as: $BACKUP_CONF"
echo ""
echo "To apply changes, reboot the system:"
echo "sudo reboot"
echo ""
echo "To remove the overlay later, restore the backup:"
echo "sudo cp $BACKUP_CONF $EXTLINUX_CONF"