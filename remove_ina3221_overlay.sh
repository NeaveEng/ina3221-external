#!/bin/bash

# Script to remove INA3221 external overlay
# Usage: sudo ./remove_ina3221_overlay.sh

set -e

OVERLAY_NAME="ina3221-external"
OVERLAY_PATH="/boot/${OVERLAY_NAME}.dtbo"
EXTLINUX_CONF="/boot/extlinux/extlinux.conf"
BACKUP_CONF="/boot/extlinux/extlinux.conf.ina3221-backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}=== INA3221 External Overlay Removal ===${NC}"
echo

# Check if overlay is currently installed
if ! grep -q "overlays=${OVERLAY_NAME}" "$EXTLINUX_CONF" 2>/dev/null; then
    echo -e "${YELLOW}Overlay doesn't appear to be installed in boot configuration.${NC}"
    echo "Checking for overlay file..."
fi

# Check if overlay file exists
if [ ! -f "$OVERLAY_PATH" ]; then
    echo -e "${YELLOW}Overlay file $OVERLAY_PATH not found.${NC}"
else
    echo "Found overlay file: $OVERLAY_PATH"
fi

# Check if backup exists
if [ ! -f "$BACKUP_CONF" ]; then
    echo -e "${YELLOW}Warning: Backup configuration not found at $BACKUP_CONF${NC}"
    echo "Will attempt manual removal from boot configuration..."
    
    # Manual removal
    if grep -q "overlays=${OVERLAY_NAME}" "$EXTLINUX_CONF" 2>/dev/null; then
        echo "Creating backup before manual removal..."
        cp "$EXTLINUX_CONF" "${EXTLINUX_CONF}.pre-removal-backup"
        
        echo "Removing overlay from boot configuration..."
        sed -i "s/ overlays=${OVERLAY_NAME}//g" "$EXTLINUX_CONF"
        sed -i "s/overlays=${OVERLAY_NAME} //g" "$EXTLINUX_CONF"
        sed -i "s/overlays=${OVERLAY_NAME}//g" "$EXTLINUX_CONF"
    fi
else
    echo "Restoring original boot configuration from backup..."
    cp "$BACKUP_CONF" "$EXTLINUX_CONF"
fi

# Remove overlay file
if [ -f "$OVERLAY_PATH" ]; then
    echo "Removing overlay file: $OVERLAY_PATH"
    rm "$OVERLAY_PATH"
fi

# Runtime removal of I2C device if present
if [ -d "/sys/bus/i2c/devices/i2c-1/1-0041" ]; then
    echo "Removing runtime I2C device..."
    echo 0x41 > /sys/bus/i2c/devices/i2c-1/delete_device 2>/dev/null || true
fi

echo
echo -e "${GREEN}=== Removal Complete! ===${NC}"
echo
echo "Summary of actions taken:"
echo "✓ Restored boot configuration"
echo "✓ Removed overlay file from /boot/"
echo "✓ Removed runtime I2C device (if present)"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Reboot the system: sudo reboot"
echo "2. After reboot, verify removal:"
echo "   - Check I2C devices: sudo i2cdetect -y 1"
echo "   - Check hwmon: ls /sys/class/hwmon/hwmon*/name | xargs grep ina3221"
echo
echo "To restore the overlay later, run:"
echo "sudo ./add_ina3221_overlay.sh"