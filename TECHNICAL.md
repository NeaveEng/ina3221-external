# Technical Reference

## 📚 System Architecture

### Device Tree and I2C Device Creation

This project uses a **systemd service** to create the I2C device at boot time, rather than device tree overlays. This approach was chosen because device tree overlays don't load reliably on Jetson's bootloader.

For a detailed explanation of how Linux I2C device creation works, see [`HOW_IT_WORKS.md`](HOW_IT_WORKS.md).

### Why Not Device Tree Overlays?

Device tree overlays are the "proper" way to add hardware devices in Linux, but on Jetson Orin Nano:
- The bootloader doesn't reliably support dynamic overlay loading
- The `overlays=` parameter in `extlinux.conf` doesn't work consistently
- Merging overlays into the main DTB is risky and can brick the system

The systemd service method is:
- ✅ Reliable and tested
- ✅ Easy to debug
- ✅ Easy to remove/rollback
- ✅ Doesn't modify boot files

## 🔧 Hardware Configuration

### INA3221 I2C Address Configuration

The INA3221 address is set by two pins:

| A0 | A1 | Address |
|----|-----|---------|
| GND | GND | 0x40 (Built-in sensor) |
| VCC | GND | 0x41 (External sensor) |
| GND | VCC | 0x42 |
| VCC | VCC | 0x43 |

For this project:
- **Built-in INA3221**: A0=GND, A1=GND → 0x40
- **External INA3221**: A0=VCC, A1=GND → 0x41

### I2C Bus Information

- **Bus Number**: 1 (in userspace: `/dev/i2c-1`)
- **Device Tree Path**: `/i2c@c240000`
- **Alias**: `gen2_i2c`
- **Pins**: GPIO27 (SDA), GPIO28 (SCL)

### Jetson Orin Nano I2C Buses

The Jetson Orin Nano has multiple I2C buses:

```bash
# List all I2C buses
ls -l /dev/i2c-*

# Common buses:
# i2c-0: Power management
# i2c-1: General purpose (gen2_i2c) - Used for INA3221
# i2c-2: Display port
# ...
```

##  Hardware Monitoring (hwmon) Subsystem

### How hwmon Works

1. **I2C Device Creation**: Device created at `/sys/bus/i2c/devices/i2c-1/new_device`
2. **Driver Binding**: `ina3221` kernel driver automatically binds to the device
3. **hwmon Registration**: Driver registers with hwmon subsystem
4. **Sysfs Interface**: hwmon creates interface at `/sys/class/hwmon/hwmonX/`

### hwmon Interface Files

Each INA3221 hwmon device provides:

| File | Description | Units |
|------|-------------|-------|
| `in1_input` | Channel 0 voltage | mV |
| `in2_input` | Channel 1 voltage | mV |
| `in3_input` | Channel 2 voltage | mV |
| `curr1_input` | Channel 0 current | mA |
| `curr2_input` | Channel 1 current | mA |
| `curr3_input` | Channel 2 current | mA |
| `shunt1_resistor` | Channel 0 shunt value | µΩ |
| `shunt2_resistor` | Channel 1 shunt value | µΩ |
| `shunt3_resistor` | Channel 2 shunt value | µΩ |
| `name` | Device name | - |

### Finding hwmon Devices

```bash
# List all hwmon devices
ls /sys/class/hwmon/

# Find INA3221 devices
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ]; then
        name=$(cat $hwmon/name)
        if [ "$name" = "ina3221" ]; then
            echo "$hwmon: $name"
            # Check which I2C address
            device=$(readlink -f $hwmon/device)
            echo "  Device: $device"
        fi
    fi
done
```

## ⚙️ Systemd Service Details

### Service File Location

```
/etc/systemd/system/ina3221-external.service
```

### Service Configuration

```ini
[Unit]
Description=Create external INA3221 I2C device
After=multi-user.target
Requires=sys-bus-i2c-devices-i2c\x2d1.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device'
ExecStartPost=/bin/sleep 2
ExecStartPost=/bin/bash -c 'for hwmon in /sys/class/hwmon/hwmon*/device; do if [[ "$(readlink -f $hwmon)" == *"1-0041"* ]]; then HWMON=$(dirname $hwmon); echo 500000 > $HWMON/shunt1_resistor 2>/dev/null || true; echo 500000 > $HWMON/shunt2_resistor 2>/dev/null || true; echo 500000 > $HWMON/shunt3_resistor 2>/dev/null || true; fi; done'
ExecStop=/bin/bash -c 'echo 0x41 > /sys/bus/i2c/devices/i2c-1/delete_device 2>/dev/null || true'

[Install]
WantedBy=multi-user.target
```

### Service Execution Flow

1. **Wait for I2C bus** (`Requires=sys-bus-i2c-devices-i2c\x2d1.device`)
2. **Create device** (`echo ina3221 0x41 > new_device`)
3. **Wait 2 seconds** for driver binding
4. **Find hwmon device** (searches for 1-0041)
5. **Calibrate shunt resistors** (500000 µΩ = 500mΩ)

## 🔍 Kernel Driver Details

### INA3221 Driver

- **Module**: `ina3221.ko`
- **Location**: Built into kernel or `/lib/modules/$(uname -r)/kernel/drivers/hwmon/`
- **Source**: `drivers/hwmon/ina3221.c` in Linux kernel

### Driver Capabilities

- Monitors up to 3 channels
- Voltage and current measurement
- Configurable shunt resistors
- Critical/warning thresholds
- hwmon sysfs interface

### Loading/Checking Driver

```bash
# Check if driver is loaded
lsmod | grep ina3221

# Load driver manually if needed
sudo modprobe ina3221

# Check driver info
modinfo ina3221
```

## 📊 INA3221 Specifications

### Electrical Characteristics

- **Bus Voltage Range**: 0V to +26V
- **Shunt Voltage Range**: ±163.8mV
- **Resolution**:
  - Bus voltage: 8mV
  - Shunt voltage: 40µV
- **Accuracy**: ±0.2% (typical)

### Measurement Ranges

Maximum measurable current depends on shunt resistor:

| Shunt | Max Current | Resolution |
|-------|-------------|------------|
| 5mΩ | 32.76A | ~8mA |
| 10mΩ | 16.38A | ~4mA |
| 100mΩ | 1.638A | ~400µA |
| 500mΩ | 327.6mA | ~80µA |

Formula: `I_max = 163.8mV / R_shunt`

### Power Dissipation

Shunt resistor power: `P = I² × R`

Examples:
- 1A through 100mΩ = 0.1W
- 5A through 10mΩ = 0.25W
- 10A through 5mΩ = 0.5W

**Important**: Ensure shunt resistor is rated for the power!

## 🔧 Advanced Configuration

### Multiple External INA3221 Devices

You can add more INA3221 devices at different addresses:

```bash
# Add device at 0x42 (A0=GND, A1=VCC)
echo ina3221 0x42 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device

# Add device at 0x43 (A0=VCC, A1=VCC)
echo ina3221 0x43 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device
```

### Per-Channel Configuration

Each channel can have different shunt resistor values:

```bash
HWMON=$(ls -d /sys/bus/i2c/devices/1-0041/hwmon/hwmon* | head -n1)

# Different shunt values per channel
echo 10000 | sudo tee $HWMON/shunt1_resistor   # 10mΩ for high current
echo 100000 | sudo tee $HWMON/shunt2_resistor  # 100mΩ for medium current
echo 500000 | sudo tee $HWMON/shunt3_resistor  # 500mΩ for low current
```

## 🐧 Kernel Compatibility

### Tested Configurations

- **JetPack**: 5.x and 6.x
- **Kernel**: 5.10+
- **Platform**: Jetson Orin Nano Developer Kit

### Required Kernel Features

- I2C subsystem
- hwmon subsystem
- INA3221 driver (CONFIG_SENSORS_INA3221)

Check if enabled:
```bash
# Check kernel config
zcat /proc/config.gz | grep INA3221
# Should show: CONFIG_SENSORS_INA3221=m or =y
```

## 📖 References

### Official Documentation

- [NVIDIA Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/archives/r35.4.1/DeveloperGuide/index.html)
- [Texas Instruments INA3221 Datasheet](https://www.ti.com/lit/ds/symlink/ina3221.pdf)
- [Linux Device Tree Documentation](https://www.kernel.org/doc/Documentation/devicetree/)
- [Linux hwmon Subsystem Documentation](https://www.kernel.org/doc/html/latest/hwmon/index.html)
- [Linux I2C Subsystem Documentation](https://www.kernel.org/doc/html/latest/i2c/index.html)

### Useful Commands Reference

```bash
# I2C tools
sudo i2cdetect -y 1              # Scan I2C bus
sudo i2cget -y 1 0x41 0x00       # Read register
sudo i2cdump -y 1 0x41           # Dump all registers

# hwmon
cat /sys/class/hwmon/hwmon*/name # List all hwmon devices
sensors                          # Read all sensors (lm-sensors package)

# Systemd
systemctl daemon-reload          # Reload unit files
systemctl list-units | grep i2c  # List I2C-related units
journalctl -k | grep ina3221     # Kernel messages about INA3221
```
