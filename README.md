# INA3221 External Power Monitor Setup for Jetson Orin Nano

This repository contains device tree overlays and configuration files to add a second INA3221 power monitor to the Jetson Orin Nano development board. This is used to monitor the power state where the device is running off battery or on charge. The battery should be connected to the input of the ina3221 board, DC input to the Jetson on channel 0, charge port on channel 1, and channel 2 is free for external use.

## 📋 Overview

The Jetson Orin Nano comes with a built-in INA3221 power monitor (at I2C address 0x40) that monitors three power rails:
- **Channel 0**: VDD_IN (Main or module input voltage)
- **Channel 1**: VDD_CPU_GPU_CV (CPU/GPU/CV power)
- **Channel 2**: VDD_SOC (SoC power)

This project adds a second INA3221 (at I2C address 0x41) to monitor three additional custom power rails, giving you a total of 6 power monitoring channels.

## 🛠 Hardware Requirements

- Jetson Orin Nano Developer Kit
- External INA3221 power monitor IC
- Proper I2C connections to the existing I2C bus (gen2_i2c)
- Address configuration: A0=HIGH, A1=LOW (sets address to 0x41)
- Shunt resistors for each channel (5mΩ recommended)
- INA3221 connected to I2C-1 via gpio 27/28

## 📁 Repository Contents

```
ina3221-external/
├── README.md                           # This comprehensive guide
├── BOOT_CONFIGURATION.md              # Detailed boot setup guide  
├── PERSISTENCE_GUIDE.md               # hwmon persistence troubleshooting
├── LICENSE                            # MIT License
├── .gitignore                         # Git ignore rules
├── ina3221-external.dts               # External INA3221 overlay source
├── ina3221_labels.conf                # Channel label configuration
├── setup_persistence.sh               # Systemd service setup (recommended)
├── setup_ina3221_device.sh           # Device setup and calibration script
├── calibrate_ina3221.sh               # Manual calibration utility
├── read_ina3221_sensors.sh            # Sensor reading script with labels
├── test_persistence.sh                # Persistence testing utility
├── add_ina3221_overlay.sh             # Boot configuration script (legacy)
└── remove_ina3221_overlay.sh          # Overlay removal script (legacy)
```

**Key Files:**
- **`setup_persistence.sh`**: Main installation script (creates systemd service)
- **`ina3221_labels.conf`**: Edit this to customize channel names
- **`read_ina3221_sensors.sh`**: Primary tool for reading sensor data
- **`calibrate_ina3221.sh`**: Calibration utility for custom shunt resistors

## 🚀 Quick Start

**TL;DR**: For most users, just run the automated setup:

```bash
# Clone and setup
git clone https://github.com/NeaveEng/ina3221-external.git
cd ina3221-external

# Customize labels (optional)
nano ina3221_labels.conf

# Install with persistence
sudo ./setup_persistence.sh

# Reboot and test
sudo reboot
sudo ./read_ina3221_sensors.sh
```

Your external INA3221 will now show up as:
- **Channel 0 (VDD_MOTOR)**: Custom power rail monitoring
- **Channel 1 (VDD_SENSORS)**: Custom power rail monitoring  
- **Channel 2 (VDD_EXTERNAL)**: Custom power rail monitoring

## 🚀 Detailed Installation

### Step 1: Hardware Setup
1. Connect your second INA3221 to the same I2C bus as the original
2. Configure address pins: A0=HIGH, A1=LOW (address = 0x41)
3. Connect shunt resistors to the power rails you want to monitor
4. **Measure your shunt resistor values** for accurate calibration

### Step 2: Software Installation

#### Method A: Automated Setup with Persistence (Recommended)

The modern approach uses a systemd service for reliable device creation and configuration:

```bash
# Clone this repository
git clone https://github.com/NeaveEng/ina3221-external.git
cd ina3221-external

# Customize channel labels (optional)
nano ina3221_labels.conf

# Run the persistence setup script
sudo ./setup_persistence.sh

# Reboot to test automatic persistence
sudo reboot

# After reboot, verify everything is working
sudo ./read_ina3221_sensors.sh
```

#### Method B: Device Tree Overlay (Alternative)

**Note**: Device tree overlays don't load reliably on Jetson bootloaders. Use Method A for production systems.

```bash
# Compile the overlay from source
dtc -I dts -O dtb -@ ina3221-external.dts -o ina3221-external.dtbo

# Copy the compiled overlay to boot directory
sudo cp ina3221-external.dtbo /boot/

# Run the installation script
sudo ./add_ina3221_overlay.sh

# Reboot to apply changes
sudo reboot
```

### Step 3: Calibration

Your external INA3221 will be automatically calibrated for 500mΩ (0.5Ω) shunt resistors. If you have different values:

```bash
# Check your current readings
sudo ./read_ina3221_sensors.sh

# If readings seem too high/low, run calibration
# (Edit the script first to match your measured shunt values)
nano calibrate_ina3221.sh
sudo ./calibrate_ina3221.sh
```

### Step 4: Verify Installation
```bash
# Check I2C devices (should show both sensors)
ls /sys/bus/i2c/devices/i2c-1/
# You should see: 1-0040 (original) and 1-0041 (second)

# Check hwmon devices
for i in /sys/class/hwmon/hwmon*/name; do echo "$i: $(cat $i)"; done | grep ina3221

# Use the provided script to read both sensors
sudo ./read_ina3221_sensors.sh
```

### Step 4: Manual Device Creation (if needed)
If the overlay doesn't automatically create the second device, you can manually instantiate it:
```bash
# Manually create the external INA3221 device
echo ina3221 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device

# Verify it appeared
ls /sys/bus/i2c/devices/i2c-1/1-0041/
```

## � Usage

### Reading Power Monitoring Data

The simplest way to read all sensors:

```bash
# Read all INA3221 sensors with labels
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
  Channel 0 (VDD_MOTOR):
    Voltage: 11848 mV
    Current: 119 mA
    Power: 1409 mW
  Channel 1 (VDD_SENSORS):
    Voltage: 12016 mV
    Current: -195 mA
    Power: -2343 mW  # Negative = supplying power
```

### Direct hwmon Access

For programmatic access or custom monitoring:

```bash
# Direct sensor readings
cat /sys/class/hwmon/hwmon6/curr1_input  # Channel 0 current (mA)
cat /sys/class/hwmon/hwmon6/in1_input    # Channel 0 voltage (mV)

# Using convenience symlinks
cat /etc/ina3221/channels/channel0_current
cat /etc/ina3221/channels/channel1_voltage

# Get channel labels from config
source /etc/ina3221/ina3221_labels.conf
echo "Monitoring: $CHANNEL_0_LABEL"
```

### Continuous Monitoring

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

### Integration with Other Systems

```bash
# Export readings to JSON (example)
#!/bin/bash
# export_readings.sh

HWMON="/sys/class/hwmon/hwmon6"
echo "{"
echo "  \"timestamp\": \"$(date -Iseconds)\","
echo "  \"external_ina3221\": {"
echo "    \"channel0\": {"
echo "      \"voltage_mv\": $(cat $HWMON/in1_input),"
echo "      \"current_ma\": $(cat $HWMON/curr1_input)"
echo "    }"
echo "  }"
echo "}"
```

## �📊 Channel Configuration & Labeling

### Built-in INA3221 (Address 0x40) - System Power Rails
| Channel | Label | Function |
|---------|--------|----------|
| 0 | VDD_IN | Main input voltage |
| 1 | VDD_CPU_GPU_CV | CPU/GPU/CV power |
| 2 | VDD_SOC | SoC power |

### External INA3221 (Address 0x41) - Custom Power Rails
| Channel | Default Label | Customizable | Configuration |
|---------|--------|----------|---------|
| 0 | VDD_MOTOR | ✅ | Edit `ina3221_labels.conf` |
| 1 | VDD_SENSORS | ✅ | Edit `ina3221_labels.conf` |
| 2 | VDD_EXTERNAL | ✅ | Edit `ina3221_labels.conf` |

### Customizing Channel Labels

Edit the `ina3221_labels.conf` file to customize your channel names:

```bash
# Edit channel labels
nano ina3221_labels.conf

# Example configuration:
CHANNEL_0_LABEL="VDD_MOTOR_12V"
CHANNEL_1_LABEL="VDD_SENSOR_5V" 
CHANNEL_2_LABEL="VDD_LIGHTING"

# Apply changes (restart service)
sudo systemctl restart ina3221-external.service

# Verify new labels
sudo ./read_ina3221_sensors.sh
```

## ⚡ Shunt Resistor Calibration

The system automatically calibrates for **500mΩ (0.5Ω)** shunt resistors. If you have different values:

### Automatic Calibration
```bash
# Run the calibration script
sudo ./calibrate_ina3221.sh

# For custom values, edit the script first:
nano calibrate_ina3221.sh
# Change: SHUNT_VALUE=500000  # to your value in micro-ohms
```

### Manual Calibration
```bash
# Set shunt resistor values (in micro-ohms):
# Examples: 10mΩ = 10000, 100mΩ = 100000, 500mΩ = 500000

sudo bash -c 'echo 100000 > /sys/class/hwmon/hwmon6/shunt1_resistor'  # 100mΩ
sudo bash -c 'echo 100000 > /sys/class/hwmon/hwmon6/shunt2_resistor'
sudo bash -c 'echo 100000 > /sys/class/hwmon/hwmon6/shunt3_resistor'

# Verify readings
sudo ./read_ina3221_sensors.sh
```

### Persistent Calibration

To make custom calibration persistent, edit the setup script:

```bash
# Edit the device setup script
nano setup_ina3221_device.sh

# Change these lines to your shunt resistor value:
echo 500000 > "$HWMON_DEVICE/shunt1_resistor"  # Change 500000 to your value
echo 500000 > "$HWMON_DEVICE/shunt2_resistor" 
echo 500000 > "$HWMON_DEVICE/shunt3_resistor"

# Restart service to apply
sudo systemctl restart ina3221-external.service
```

## 🔧 System Integration & Persistence

### Automatic Startup

The systemd service ensures your external INA3221 is available on every boot:

```bash
# Check service status
sudo systemctl status ina3221-external.service

# View service logs  
sudo journalctl -u ina3221-external.service

# Manual restart if needed
sudo systemctl restart ina3221-external.service

# Disable automatic startup (if needed)
sudo systemctl disable ina3221-external.service
```

### Convenience Access

The system creates convenient access points:

```bash
# Direct channel access via symlinks
ls -la /etc/ina3221/channels/

# Read specific channels:
cat /etc/ina3221/channels/channel0_current  # Channel 0 current
cat /etc/ina3221/channels/channel1_voltage  # Channel 1 voltage

# Configuration file location
cat /etc/ina3221/ina3221_labels.conf

# Direct hwmon access
ls -la /sys/class/hwmon/hwmon6/
```

## 🔧 Legacy Customization (Device Tree Method)

If using the device tree overlay method, customize by editing the source:

### Changing Channel Labels in Device Tree
```dts
# Edit ina3221-external.dts
channel@0 {
    reg = <0>;
    label = "YOUR_CUSTOM_LABEL";
    shunt-resistor-micro-ohms = <500000>;
};
```

### Changing Shunt Resistor Values in Device Tree
Modify the `shunt-resistor-micro-ohms` property to match your hardware:
- 500000 = 500mΩ (recommended)
- 100000 = 100mΩ  
- 10000 = 10mΩ

### Recompiling After Changes
```bash
dtc -I dts -O dtb -@ ina3221-external.dts -o ina3221-external.dtbo
sudo cp ina3221-external.dtbo /boot/
sudo reboot
```

## 📖 Detailed Documentation

### Boot Configuration
See [BOOT_CONFIGURATION.md](BOOT_CONFIGURATION.md) for detailed instructions on:
- Manual extlinux.conf modification
- Troubleshooting boot issues
- Rollback procedures
- Runtime overlay loading

### Device Tree Analysis
If you need to analyze the original device tree, you can decompile it:
```bash
# Decompile the main Orin Nano device tree for analysis
dtc -I dtb -O dts /boot/kernel_tegra234-p3767-0004-p3509-a02.dtb -o orin_nano_main.dts

# Search for INA3221 configuration
grep -A 20 -B 5 "ina3221@40" orin_nano_main.dts
```

The original device tree was decompiled from:
```
/boot/kernel_tegra234-p3767-0004-p3509-a02.dtb
```

The INA3221 configuration is located at I2C bus `/i2c@c240000` (gen2_i2c).

## 🔍 Accessing Sensor Data

### Hwmon Interface Location
Once properly loaded, your sensors will appear as:
- **Original INA3221** (0x40): `/sys/class/hwmon/hwmon3/` (typically)
- **External INA3221** (0x41): `/sys/class/hwmon/hwmon6/` (typically)

**Note**: The exact hwmon numbers may vary. Use the provided script to automatically detect them.

### I2C Device Paths
- **Original INA3221**: `/sys/bus/i2c/devices/i2c-1/1-0040/`
- **External INA3221**: `/sys/bus/i2c/devices/i2c-1/1-0041/`

### Reading Sensor Data

#### Method 1: Using the Provided Script (Recommended)
```bash
sudo ./read_ina3221_sensors.sh
```

#### Method 2: Direct hwmon Access
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

#### Method 3: Direct I2C Device Access
```bash
# Navigate to the external sensor
cd /sys/bus/i2c/devices/i2c-1/1-0041/hwmon/hwmon*/

# Read sensor values
sudo cat in*_input curr*_input
```

### How the Sensor Gets Added to hwmon

The INA3221 sensor integration follows this process:

1. **Device Tree Overlay Loading**: At boot, the kernel loads the `ina3221-second-v2.dtbo` overlay
2. **I2C Device Creation**: The overlay instructs the kernel to create an I2C device at address 0x41
3. **Driver Binding**: The `ina3221` kernel driver automatically binds to the new device
4. **hwmon Registration**: The driver registers the device with the hwmon subsystem
5. **Sysfs Interface**: The hwmon subsystem creates sysfs interfaces under `/sys/class/hwmon/hwmonX/`

#### Manual Device Creation Process
If the overlay doesn't work automatically, you can manually trigger this process:

```bash
# Step 1: Create the I2C device
echo ina3221 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device

# Step 2: Verify driver binding (automatic)
ls /sys/bus/i2c/devices/i2c-1/1-0041/

# Step 3: Find the hwmon interface (automatic)
find /sys/bus/i2c/devices/i2c-1/1-0041/ -name hwmon
```

The kernel automatically handles driver binding and hwmon registration once the I2C device is created.

## 🔍 Troubleshooting
```bash
# Check kernel messages
dmesg | grep -i overlay
dmesg | grep -i ina3221

# Verify overlay file exists
ls -la /boot/ina3221-external.dtbo

# Check boot configuration
cat /boot/extlinux/extlinux.conf | grep overlays
```

### I2C Device Not Detected
```bash
# Check I2C bus
sudo i2cdetect -y 1

# Verify hardware connections
# Ensure A0=HIGH, A1=LOW on INA3221
# Check power supply to the IC
```

### Permission Issues
```bash
# Ensure you're running commands with sudo
sudo i2cdetect -y 1
sudo ls /sys/class/hwmon/
```

## 🔄 Removal/Rollback

### Method 1: Automatic Removal Script (Recommended)
```bash
# Use the provided removal script
sudo ./remove_ina3221_overlay.sh

# Reboot to apply changes
sudo reboot
```

### Method 2: Manual Rollback
```bash
# Restore original boot configuration using the backup
sudo cp /boot/extlinux/extlinux.conf.ina3221-backup /boot/extlinux/extlinux.conf

# Remove overlay file from boot directory
sudo rm /boot/ina3221-external.dtbo

# Reboot to apply changes
sudo reboot
```
```bash
### Method 3: Manual Boot Configuration Edit
```bash
# Edit the boot configuration manually
sudo nano /boot/extlinux/extlinux.conf

# Remove "overlays=ina3221-external" from the APPEND line
# Save and exit

# Remove overlay file
sudo rm /boot/ina3221-external.dtbo

# Reboot
sudo reboot
```

### Method 4: Runtime Removal (Temporary)
```

### Method 3: Runtime Removal (Temporary)
```bash
# Remove the I2C device at runtime (until next reboot)
echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device

# Verify it's gone
ls /sys/bus/i2c/devices/i2c-1/1-0041  # Should show "No such file or directory"
```

### Verification After Removal
```bash
# Check that external sensor is no longer present
ls /sys/bus/i2c/devices/i2c-1/1-0041  # Should fail

# Check hwmon devices (should only show original INA3221)
for i in /sys/class/hwmon/hwmon*/name; do echo "$i: $(cat $i)"; done | grep ina3221

# Check I2C scan (should only show 0x40)
sudo i2cdetect -y 1
```

### Method 5: Complete Cleanup
```bash
# Remove all traces of the overlay setup
sudo rm -f /boot/ina3221-external.dtbo
sudo rm -f /boot/extlinux/extlinux.conf.ina3221-backup
sudo cp /boot/extlinux/extlinux.conf.ina3221-backup /boot/extlinux/extlinux.conf 2>/dev/null || true

# Remove local project files (if desired)
rm -rf ~/ina3221-external/

# Reboot
sudo reboot
```

## 📚 Technical Details

### Device Tree Overlay Structure
- **Target**: `/i2c@c240000` (gen2_i2c bus)
- **Address**: 0x41
- **Compatible**: `ti,ina3221`
- **Channels**: 3 (numbered 0-2)
- **Shunt Resistors**: 5mΩ each (configurable)

### I2C Bus Information
- **Bus Number**: 1 (in userspace)
- **Device Path**: `/i2c@c240000`
- **Alias**: `gen2_i2c`
- **Original INA3221**: Address 0x40
- **New INA3221**: Address 0x41

### Kernel Support
This overlay works with:
- JetPack 5.x and 6.x
- Linux Kernel 5.10+
- Device tree overlay support enabled

## 🤝 Contributing

To improve this setup:

1. Test with different shunt resistor values
2. Add support for other INA32xx variants
3. Create additional overlays for different I2C addresses
4. Improve error handling in scripts

## ⚠️ Important Notes

1. **Backup First**: Always backup your original device tree and boot configuration
2. **Hardware Verification**: Double-check I2C address configuration before powering on
3. **Shunt Resistor Sizing**: Ensure shunt resistors can handle your expected current
4. **Voltage Levels**: Verify that monitored voltages are within INA3221 specifications (±163.8V max)

## 📝 Version History

- **v2**: Uses target phandle for better compatibility (current version)
- **v1**: Used target-path method (removed for simplicity)

## 🔄 Regenerating Files

If you need to recreate the analysis files that were removed:

### Decompile Main Device Tree
```bash
# Decompile the main device tree for analysis
dtc -I dtb -O dts /boot/kernel_tegra234-p3767-0004-p3509-a02.dtb -o orin_nano_main.dts

# Find the original INA3221 configuration
grep -A 20 -B 5 "ina3221@40" orin_nano_main.dts
```

### Recompile Overlay (if modified)
```bash
# If you modify the overlay source
dtc -I dts -O dtb -@ ina3221-external.dts -o ina3221-external.dtbo

# Copy to boot directory
sudo cp ina3221-external.dtbo /boot/
```

## 🤖 AI Development Disclaimer

This project was developed with assistance from AI language models to accelerate development and improve code quality. The AI assistance included:

- **Code Generation**: Device tree overlay structures, shell scripts, and systemd service configurations
- **Documentation**: Technical explanations, usage guides, and troubleshooting sections  
- **Analysis**: Device tree decompilation interpretation and hardware configuration guidance
- **Testing Strategies**: Verification approaches and debugging methodologies

### Key References and Validation

All AI-generated content was validated against:
- [NVIDIA Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/archives/r35.4.1/DeveloperGuide/index.html)
- [Texas Instruments INA3221 Datasheet](https://www.ti.com/lit/ds/symlink/ina3221.pdf)
- [Linux Device Tree Documentation](https://www.kernel.org/doc/Documentation/devicetree/)
- [Linux hwmon Subsystem Documentation](https://www.kernel.org/doc/html/latest/hwmon/index.html)

The implementation was thoroughly tested on NVIDIA Jetson Orin Nano hardware to ensure functionality and reliability. Users should always validate configurations in their specific environment and refer to official documentation for authoritative guidance.

## 📧 Support

For issues:
1. Check the troubleshooting section above
2. Review kernel logs: `dmesg | grep -i ina3221`
3. Verify hardware connections
4. Check JetPack version compatibility

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

The MIT License allows for:
- ✅ Commercial use
- ✅ Modification and distribution
- ✅ Private use
- ✅ Sublicensing

---

**Note**: This overlay integrates seamlessly with existing JetsonIO configurations and will not interfere with GPIO pin assignments or camera configurations.