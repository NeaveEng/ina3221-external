#!/bin/bash

# Script to read both INA3221 sensors on Jetson Orin Nano

echo "=== INA3221 Power Monitor Reading ==="
echo

# Function to read INA3221 data
read_ina3221() {
    local hwmon_path=$1
    local sensor_name=$2
    local address=$3
    
    echo "--- $sensor_name (Address: $address) ---"
    
    if [ ! -d "$hwmon_path" ]; then
        echo "Error: $hwmon_path not found"
        return 1
    fi
    
    # Check if it's really an INA3221
    if [ "$(cat $hwmon_path/name 2>/dev/null)" != "ina3221" ]; then
        echo "Error: Not an INA3221 device"
        return 1
    fi
    
    # Read channel data
    for ch in 1 2 3; do
        local voltage=$(cat $hwmon_path/in${ch}_input 2>/dev/null || echo "N/A")
        local current=$(cat $hwmon_path/curr${ch}_input 2>/dev/null || echo "N/A")
        
        # Try to get label if available
        local label_file="$hwmon_path/in${ch}_label"
        local label=""
        if [ -f "$label_file" ]; then
            label=" ($(cat $label_file 2>/dev/null || echo 'Unknown'))"
        fi
        
        echo "  Channel $((ch-1))$label:"
        if [ "$voltage" != "N/A" ]; then
            echo "    Voltage: ${voltage} mV"
        else
            echo "    Voltage: N/A"
        fi
        
        if [ "$current" != "N/A" ]; then
            echo "    Current: ${current} mA"
        else
            echo "    Current: N/A"
        fi
        
        # Calculate power if both values are available
        if [ "$voltage" != "N/A" ] && [ "$current" != "N/A" ] && [ "$voltage" -ne 0 ] && [ "$current" -ne 0 ]; then
            local power=$((voltage * current / 1000))
            echo "    Power: ${power} mW"
        fi
        echo
    done
}

# Find INA3221 devices
echo "Scanning for INA3221 devices..."
echo

# Check original INA3221 (usually hwmon3)
original_found=false
second_found=false

for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ] && [ "$(cat $hwmon/name)" = "ina3221" ]; then
        # Try to determine which one this is by checking the device path
        device_link=$(readlink -f $hwmon/device 2>/dev/null)
        
        if [[ "$device_link" == *"1-0040"* ]]; then
            read_ina3221 "$hwmon" "Original INA3221" "0x40"
            original_found=true
        elif [[ "$device_link" == *"1-0041"* ]]; then
            read_ina3221 "$hwmon" "Second INA3221" "0x41"
            second_found=true
        else
            # Fallback: just read it as unknown
            addr=$(basename "$device_link" | cut -d'-' -f2)
            read_ina3221 "$hwmon" "INA3221" "0x$addr"
        fi
    fi
done

echo "=== Summary ==="
echo "Original INA3221 (0x40): $([ "$original_found" = true ] && echo "Found" || echo "Not found")"
echo "Second INA3221 (0x41): $([ "$second_found" = true ] && echo "Found" || echo "Not found")"

if [ "$second_found" = false ]; then
    echo
    echo "To manually create the second INA3221 device:"
    echo "sudo echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device"
fi