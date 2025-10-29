#!/bin/bash

# Script to test hwmon persistence after clean reboot
# Usage: ./test_persistence.sh

echo "=== INA3221 External Persistence Test ==="
echo

# Check if we're testing after a clean reboot or manual creation
MANUAL_DEVICE_EXISTS=false
if [ -d "/sys/bus/i2c/devices/i2c-1/1-0041" ]; then
    echo "📍 External INA3221 device (1-0041) is currently present"
    
    # Check if this was manually created or from overlay
    if sudo dmesg | grep -q "manually created"; then
        MANUAL_DEVICE_EXISTS=true
        echo "⚠️  Device appears to be manually created"
    else
        echo "✅ Device appears to be created by overlay/boot process"
    fi
    echo
fi

echo "🔍 Checking overlay configuration..."

# Check boot configuration
if grep -q "overlays=ina3221-external" /boot/extlinux/extlinux.conf 2>/dev/null; then
    echo "✅ Boot configuration: overlays=ina3221-external found"
else
    echo "❌ Boot configuration: overlays=ina3221-external NOT found"
    echo "   Run: sudo ./add_ina3221_overlay.sh"
fi

# Check overlay file
if [ -f "/boot/ina3221-external.dtbo" ]; then
    echo "✅ Overlay file: /boot/ina3221-external.dtbo exists"
else
    echo "❌ Overlay file: /boot/ina3221-external.dtbo missing"
    echo "   Compile and copy overlay file to /boot/"
fi

echo

# Check kernel command line
echo "🔍 Checking kernel command line..."
if cat /proc/cmdline | grep -q "overlays=ina3221-external"; then
    echo "✅ Kernel was booted with ina3221-external overlay"
else
    echo "❌ Kernel was NOT booted with ina3221-external overlay"
    echo "   This indicates the overlay didn't load at boot"
fi

echo

# Recommend action
if [ "$MANUAL_DEVICE_EXISTS" = true ]; then
    echo "🧪 PERSISTENCE TEST REQUIRED:"
    echo "   The device currently exists but may be manually created."
    echo "   To test true persistence:"
    echo
    echo "   1. Remove manual device:"
    echo "      echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device"
    echo
    echo "   2. Reboot:"
    echo "      sudo reboot"
    echo
    echo "   3. After reboot, run this script again to verify automatic creation"
elif [ -d "/sys/bus/i2c/devices/i2c-1/1-0041" ]; then
    echo "🎉 SUCCESS: External INA3221 appears to be persistent!"
    echo "   The device exists and seems to be created automatically at boot."
    echo
    echo "   Verify with: sudo ./read_ina3221_sensors.sh"
else
    echo "❌ PERSISTENCE ISSUE: External INA3221 device not found"
    echo "   The overlay configuration looks correct but device wasn't created."
    echo
    echo "   Troubleshooting steps:"
    echo "   1. Check kernel messages: sudo dmesg | grep -i overlay"
    echo "   2. Try manual overlay loading: sudo dtoverlay /boot/ina3221-external.dtbo"
    echo "   3. See PERSISTENCE_GUIDE.md for alternative methods"
fi

echo
echo "=== Test Complete ==="