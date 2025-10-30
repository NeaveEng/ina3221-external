#!/bin/bash

# INA3221 External Sensor Calibration Script
# This script sets the correct shunt resistor values for accurate current readings

HWMON_PATH="/sys/class/hwmon/hwmon6"

echo "Calibrating INA3221 External Sensor..."

# Check if the device exists
if [ ! -d "$HWMON_PATH" ]; then
    echo "Error: External INA3221 not found at $HWMON_PATH"
    echo "Please ensure the device is properly connected and the overlay is loaded."
    exit 1
fi

# Set shunt resistor values (in micro-ohms)
# Common values:
# - 10000 µΩ (10 mΩ) - High current, low precision
# - 100000 µΩ (100 mΩ) - Medium current, good precision  
# - 500000 µΩ (500 mΩ) - Low current, high precision

SHUNT_VALUE=500000  # 500 mΩ (0.5Ω) - measured hardware value

echo "Setting shunt resistor values to ${SHUNT_VALUE} µΩ ($(($SHUNT_VALUE/1000)) mΩ)..."

# Set all three channels
sudo bash -c "echo $SHUNT_VALUE > $HWMON_PATH/shunt1_resistor"
sudo bash -c "echo $SHUNT_VALUE > $HWMON_PATH/shunt2_resistor"
sudo bash -c "echo $SHUNT_VALUE > $HWMON_PATH/shunt3_resistor"

echo "Calibration complete!"
echo ""
echo "Current readings:"
sudo bash -c "
echo 'Channel 1: $(cat $HWMON_PATH/curr1_input) mA @ $(cat $HWMON_PATH/in1_input) mV'
echo 'Channel 2: $(cat $HWMON_PATH/curr2_input) mA @ $(cat $HWMON_PATH/in2_input) mV'
echo 'Channel 3: $(cat $HWMON_PATH/curr3_input) mA @ $(cat $HWMON_PATH/in3_input) mV'
"

echo ""
echo "Note: These settings are not persistent across reboots."
echo "Update your device tree overlay for permanent calibration."