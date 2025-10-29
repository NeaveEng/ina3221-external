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
├── README.md                    # This file
├── BOOT_CONFIGURATION.md       # Detailed boot setup guide  
├── PERSISTENCE_GUIDE.md        # hwmon persistence troubleshooting
├── ina3221-external.dts        # External INA3221 overlay source
├── add_ina3221_overlay.sh      # Boot configuration script
├── remove_ina3221_overlay.sh   # Overlay removal script
└── read_ina3221_sensors.sh     # Sensor reading script
```

**Note**: The compiled overlay (`.dtbo`) is generated as needed and copied to `/boot/` for system use.

## 🚀 Quick Start

### Step 1: Hardware Setup
1. Connect your second INA3221 to the same I2C bus as the original
2. Configure address pins: A0=HIGH, A1=LOW (address = 0x41)
3. Connect shunt resistors to the power rails you want to monitor

### Step 2: Install the Overlay
```bash
# Navigate to the project directory
cd ina3221-external/

# Compile the overlay from source
dtc -I dts -O dtb -@ ina3221-external.dts -o ina3221-external.dtbo

# Copy the compiled overlay to boot directory
sudo cp ina3221-external.dtbo /boot/

# Run the installation script
sudo ./add_ina3221_overlay.sh

# Clean up (optional - remove local compiled file)
rm ina3221-external.dtbo

# Reboot to apply changes
sudo reboot
```

### Step 3: Verify Installation
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

## 📊 Channel Configuration

### Original INA3221 (Address 0x40)
| Channel | Label | Function |
|---------|--------|----------|
| 0 | VDD_IN | Main input voltage |
| 1 | VDD_CPU_GPU_CV | CPU/GPU/CV power |
| 2 | VDD_SOC | SoC power |

### External INA3221 (Address 0x41)
| Channel | Label | Function | Customizable |
|---------|--------|----------|--------------|
| 0 | VDD_CUSTOM_CH0 | User-defined power rail | ✅ |
| 1 | VDD_CUSTOM_CH1 | User-defined power rail | ✅ |
| 2 | VDD_CUSTOM_CH2 | User-defined power rail | ✅ |

## 🔧 hwmon Persistence

The overlay should automatically create the hwmon device on every boot. If you're having persistence issues:

### Quick Check
```bash
# Reboot and verify automatic creation (no manual commands needed)
sudo reboot

# After reboot, check if external sensor appears automatically
sudo ./read_ina3221_sensors.sh
```

### Troubleshooting
If the device doesn't persist after reboot, see [PERSISTENCE_GUIDE.md](PERSISTENCE_GUIDE.md) for:
- systemd service creation
- udev rule setup  
- Overlay loading troubleshooting
- Alternative persistence methods

## 🔧 Customization

### Changing Channel Labels
Edit `ina3221-external.dts` and modify the label properties:

```dts
channel@0 {
    reg = <0>;
    label = "YOUR_CUSTOM_LABEL";
    shunt-resistor-micro-ohms = <5000>;
};
```

### Changing Shunt Resistor Values
Modify the `shunt-resistor-micro-ohms` property to match your hardware:
- 5000 = 5mΩ (default)
- 1000 = 1mΩ
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