#!/bin/bash

# Load custom channel labels if available
CONFIG_FILE="/etc/ina3221-external/ina3221_labels.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Default labels if no config file exists
    CHANNEL_0_LABEL="CUSTOM_RAIL_1"
    CHANNEL_1_LABEL="CUSTOM_RAIL_2"
    CHANNEL_2_LABEL="CUSTOM_RAIL_3"
fi

# Script to read both INA3221 sensors on Jetson Orin Nano

echo "=== INA3221 Power Monitor Reading ==="
echo

# Function to read INA3221 with custom labels for external device
read_external_ina3221() {
    local hwmon_path="$1"
    local device_name="$2"
    local address="$3"
    
    echo "--- $device_name (Address: $address) ---"
    
    # Channel 1
    local voltage1=$(cat "$hwmon_path/in1_input" 2>/dev/null || echo "N/A")
    local current1=$(cat "$hwmon_path/curr1_input" 2>/dev/null || echo "N/A")
    echo "  Channel 0 ($CHANNEL_0_LABEL):"
    echo "    Voltage: ${voltage1} mV"
    echo "    Current: ${current1} mA"
    if [ "$voltage1" != "N/A" ] && [ "$current1" != "N/A" ]; then
        echo "    Power: $((voltage1 * current1 / 1000)) mW"
    fi
    echo
    
    # Channel 2
    local voltage2=$(cat "$hwmon_path/in2_input" 2>/dev/null || echo "N/A")
    local current2=$(cat "$hwmon_path/curr2_input" 2>/dev/null || echo "N/A")
    echo "  Channel 1 ($CHANNEL_1_LABEL):"
    echo "    Voltage: ${voltage2} mV"
    echo "    Current: ${current2} mA"
    if [ "$voltage2" != "N/A" ] && [ "$current2" != "N/A" ]; then
        echo "    Power: $((voltage2 * current2 / 1000)) mW"
    fi
    echo
    
    # Channel 3
    local voltage3=$(cat "$hwmon_path/in3_input" 2>/dev/null || echo "N/A")
    local current3=$(cat "$hwmon_path/curr3_input" 2>/dev/null || echo "N/A")
    echo "  Channel 2 ($CHANNEL_2_LABEL):"
    echo "    Voltage: ${voltage3} mV"
    echo "    Current: ${current3} mA"
    if [ "$voltage3" != "N/A" ] && [ "$current3" != "N/A" ]; then
        echo "    Power: $((voltage3 * current3 / 1000)) mW"
    fi
    echo
}

# Function to read built-in INA3221 sensors with system labels
read_builtin_ina3221() {
    local hwmon_path="$1"
    local device_name="$2"
    local address="$3"
    
    echo "--- $device_name (Address: $address) ---"
    
    # Read channels 1-3 (INA3221 has 3 channels)
    for ch in 1 2 3; do
        local voltage=$(cat "$hwmon_path/in${ch}_input" 2>/dev/null || echo "N/A")
        local current=$(cat "$hwmon_path/curr${ch}_input" 2>/dev/null || echo "N/A")
        
        # Try to get label if available
        local label=""
        if [ -f "$hwmon_path/in${ch}_label" ]; then
            label=" ($(cat "$hwmon_path/in${ch}_label" 2>/dev/null))"
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
            read_builtin_ina3221 "$hwmon" "Built-in INA3221" "0x40"
            original_found=true
        elif [[ "$device_link" == *"1-0041"* ]]; then
            read_external_ina3221 "$hwmon" "External INA3221" "0x41"
            second_found=true
        else
            # Fallback: just read it as unknown
            addr=$(basename "$device_link" | cut -d'-' -f2)
            read_builtin_ina3221 "$hwmon" "INA3221" "0x$addr"
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