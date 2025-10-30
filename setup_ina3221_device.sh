#!/bin/bash

# INA3221 External Device Setup and Labeling Script
# Called by systemd service to configure the device after creation

HWMON_DEVICE="/sys/class/hwmon/hwmon6"
CONFIG_FILE="/etc/ina3221/ina3221_labels.conf"
LOCAL_CONFIG_FILE="/home/dev/device-tree/ina3221_labels.conf"

echo "Setting up INA3221 external device..."

# Wait for device to be ready
sleep 2

# Set shunt resistors (500mΩ = 500000 µΩ)
if [ -d "$HWMON_DEVICE" ]; then
    echo "Calibrating shunt resistors..."
    echo 500000 > "$HWMON_DEVICE/shunt1_resistor" 2>/dev/null || true
    echo 500000 > "$HWMON_DEVICE/shunt2_resistor" 2>/dev/null || true  
    echo 500000 > "$HWMON_DEVICE/shunt3_resistor" 2>/dev/null || true
    echo "✅ Shunt resistors set to 500mΩ"
else
    echo "❌ hwmon6 device not found"
    exit 1
fi

# Copy label configuration to system location
echo "Setting up channel labels..."
mkdir -p /etc/ina3221
if [ -f "$LOCAL_CONFIG_FILE" ]; then
    cp "$LOCAL_CONFIG_FILE" "$CONFIG_FILE" 2>/dev/null || true
    echo "✅ Channel labels configuration installed"
else
    echo "⚠️  Label configuration file not found, using defaults"
fi

# Create convenience symlinks for labeled access
mkdir -p /etc/ina3221/channels
ln -sf "$HWMON_DEVICE/in1_input" /etc/ina3221/channels/channel0_voltage 2>/dev/null || true
ln -sf "$HWMON_DEVICE/curr1_input" /etc/ina3221/channels/channel0_current 2>/dev/null || true
ln -sf "$HWMON_DEVICE/in2_input" /etc/ina3221/channels/channel1_voltage 2>/dev/null || true
ln -sf "$HWMON_DEVICE/curr2_input" /etc/ina3221/channels/channel1_current 2>/dev/null || true
ln -sf "$HWMON_DEVICE/in3_input" /etc/ina3221/channels/channel2_voltage 2>/dev/null || true
ln -sf "$HWMON_DEVICE/curr3_input" /etc/ina3221/channels/channel2_current 2>/dev/null || true

echo "✅ INA3221 external device setup complete"

# Show current readings with labels
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo ""
    echo "Current readings:"
    echo "  $CHANNEL_0_LABEL: $(cat $HWMON_DEVICE/curr1_input 2>/dev/null || echo 'N/A') mA"
    echo "  $CHANNEL_1_LABEL: $(cat $HWMON_DEVICE/curr2_input 2>/dev/null || echo 'N/A') mA"
    echo "  $CHANNEL_2_LABEL: $(cat $HWMON_DEVICE/curr3_input 2>/dev/null || echo 'N/A') mA"
fi