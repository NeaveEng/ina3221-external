# Usage Guide

## 📊 Reading Power Monitoring Data

### Using the Provided Script (Recommended)

The simplest way to read all sensors:

```bash
# Read all INA3221 sensors
sudo ./read_ina3221_sensors.sh
```

**Sample Output:**
```
=== INA3221 Power Monitor Reading ===

--- Built-in INA3221 (Address: 0x40) ---
  Channel 0 (VDD_IN):
    Voltage: 5080 mV
    Current: 816 mA
    Power: 4145 mW

--- External INA3221 (Address: 0x41) ---
  Channel 0:
    Voltage: 11848 mV
    Current: 119 mA
    Power: 1409 mW
  Channel 1:
    Voltage: 12016 mV
    Current: -195 mA
    Power: -2343 mW  # Negative = supplying power
```

## 🔍 Direct hwmon Access

For programmatic access or custom monitoring:

```bash
# Direct sensor readings (replace hwmonX with actual hwmon number)
cat /sys/class/hwmon/hwmonX/curr1_input  # Channel 0 current (mA)
cat /sys/class/hwmon/hwmonX/in1_input    # Channel 0 voltage (mV)

# Find the correct hwmon device for external INA3221
ls -l /sys/bus/i2c/devices/1-0041/hwmon/
```

### Finding Your hwmon Device

```bash
# Find your external INA3221 hwmon path
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ] && [ "$(cat $hwmon/name)" = "ina3221" ]; then
        device_link=$(readlink -f $hwmon/device 2>/dev/null)
        if [[ "$device_link" == *"1-0041"* ]]; then
            echo "External INA3221 found at: $hwmon"
            HWMON_PATH=$hwmon
        fi
    fi
done

# Read from the external sensor
sudo cat $HWMON_PATH/in1_input   # Channel 0 voltage (mV)
sudo cat $HWMON_PATH/in2_input   # Channel 1 voltage (mV)
sudo cat $HWMON_PATH/in3_input   # Channel 2 voltage (mV)
sudo cat $HWMON_PATH/curr1_input # Channel 0 current (mA)
sudo cat $HWMON_PATH/curr2_input # Channel 1 current (mA)
sudo cat $HWMON_PATH/curr3_input # Channel 2 current (mA)
```

### Direct I2C Device Access

```bash
# Navigate to the external sensor
cd /sys/bus/i2c/devices/i2c-1/1-0041/hwmon/hwmon*/

# Read sensor values
sudo cat in*_input curr*_input
```

## 📈 Continuous Monitoring

Create a simple monitoring script:

```bash
#!/bin/bash
# monitor_power.sh - Simple power monitoring loop

while true; do
    clear
    echo "=== Power Monitor $(date) ==="
    sudo ./read_ina3221_sensors.sh
    sleep 5
done
```

Make it executable and run:
```bash
chmod +x monitor_power.sh
./monitor_power.sh
```

## 🔌 Integration with Other Systems

### JSON Export Example

```bash
#!/bin/bash
# export_readings.sh - Export sensor data as JSON

HWMON="/sys/class/hwmon/hwmon4"  # Adjust to your hwmon number
echo "{"
echo "  \"timestamp\": \"$(date -Iseconds)\","
echo "  \"external_ina3221\": {"
echo "    \"channel0\": {"
echo "      \"voltage_mv\": $(cat $HWMON/in1_input),"
echo "      \"current_ma\": $(cat $HWMON/curr1_input),"
echo "      \"power_mw\": $(($(cat $HWMON/in1_input) * $(cat $HWMON/curr1_input) / 1000))"
echo "    },"
echo "    \"channel1\": {"
echo "      \"voltage_mv\": $(cat $HWMON/in2_input),"
echo "      \"current_ma\": $(cat $HWMON/curr2_input),"
echo "      \"power_mw\": $(($(cat $HWMON/in2_input) * $(cat $HWMON/curr2_input) / 1000))"
echo "    },"
echo "    \"channel2\": {"
echo "      \"voltage_mv\": $(cat $HWMON/in3_input),"
echo "      \"current_ma\": $(cat $HWMON/curr3_input),"
echo "      \"power_mw\": $(($(cat $HWMON/in3_input) * $(cat $HWMON/curr3_input) / 1000))"
echo "    }"
echo "  }"
echo "}"
```

### Python Integration Example

```python
#!/usr/bin/env python3
import glob
import time

def find_external_ina3221():
    """Find the hwmon device for external INA3221 at address 0x41"""
    for hwmon_path in glob.glob('/sys/class/hwmon/hwmon*'):
        try:
            with open(f'{hwmon_path}/name', 'r') as f:
                if f.read().strip() == 'ina3221':
                    device = hwmon_path + '/device'
                    real_path = os.path.realpath(device)
                    if '1-0041' in real_path:
                        return hwmon_path
        except:
            continue
    return None

def read_channel(hwmon_path, channel):
    """Read voltage and current for a specific channel (0-2)"""
    ch = channel + 1  # hwmon channels are 1-indexed
    voltage = int(open(f'{hwmon_path}/in{ch}_input').read().strip())
    current = int(open(f'{hwmon_path}/curr{ch}_input').read().strip())
    power = (voltage * current) / 1000
    return {'voltage_mv': voltage, 'current_ma': current, 'power_mw': power}

# Example usage
hwmon = find_external_ina3221()
if hwmon:
    while True:
        ch0 = read_channel(hwmon, 0)
        print(f"Channel 0: {ch0['voltage_mv']}mV, {ch0['current_ma']}mA, {ch0['power_mw']}mW")
        time.sleep(1)
else:
    print("External INA3221 not found")
```

## 📊 Channel Configuration

### Built-in INA3221 (Address 0x40) - System Power Rails
| Channel | Label | Function |
|---------|--------|----------|
| 0 | VDD_IN | Main input voltage |
| 1 | VDD_CPU_GPU_CV | CPU/GPU/CV power |
| 2 | VDD_SOC | SoC power |

### External INA3221 (Address 0x41) - Custom Power Rails
| Channel | Function |
|---------|----------|
| 0 | Custom power rail monitoring |
| 1 | Custom power rail monitoring |
| 2 | Custom power rail monitoring |

## 🔧 Service Management

### Check Service Status

```bash
# Check if service is running
sudo systemctl status ina3221-external.service

# View service logs  
sudo journalctl -u ina3221-external.service

# View recent logs
sudo journalctl -u ina3221-external.service -n 50
```

### Manual Control

```bash
# Stop the service
sudo systemctl stop ina3221-external.service

# Start the service
sudo systemctl start ina3221-external.service

# Restart the service
sudo systemctl restart ina3221-external.service

# Disable automatic startup
sudo systemctl disable ina3221-external.service

# Enable automatic startup
sudo systemctl enable ina3221-external.service
```

## 🔍 Hwmon Interface Location

Once properly loaded, your sensors will appear as:
- **Original INA3221** (0x40): `/sys/class/hwmon/hwmon3/` (typically)
- **External INA3221** (0x41): `/sys/class/hwmon/hwmon4/` (typically)

**Note**: The exact hwmon numbers may vary. Use the provided script to automatically detect them.

### I2C Device Paths
- **Original INA3221**: `/sys/bus/i2c/devices/i2c-1/1-0040/`
- **External INA3221**: `/sys/bus/i2c/devices/i2c-1/1-0041/`
