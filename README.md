# INA3221 External Power Monitor for Jetson Orin Nano

Add a second INA3221 power monitor to your Jetson Orin Nano for battery/charger power monitoring or custom power rail monitoring.

## 📋 Overview

The Jetson Orin Nano has a built-in INA3221 (address 0x40) monitoring system power. This project adds a second INA3221 (address 0x41) to monitor three additional power rails - perfect for battery/charger monitoring or custom applications.

**Use Case**: Monitor battery power state - battery input, DC input to Jetson, and charge port on the three channels.

### What You Get

- ✅ **6 total power monitoring channels** (3 built-in + 3 external)
- ✅ **Simple installation** - one script to set up
- ✅ **Persistent** - survives reboots
- ✅ **Easy to remove** - no system file modifications
- ✅ **Well documented** - comprehensive guides for all aspects

## 🛠 Hardware Requirements

- Jetson Orin Nano Developer Kit
- External INA3221 power monitor module
- I2C connections to I2C-1 bus (GPIO 27/28)
- Address configuration: **A0=HIGH, A1=LOW** (address 0x41)
- Shunt resistors (500mΩ recommended for < 1A loads)

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/NeaveEng/ina3221-external.git
cd ina3221-external

# Install
sudo ./setup_ina3221.sh

# Reboot to test persistence
sudo reboot

# Read sensors
sudo ./read_ina3221_sensors.sh
```

**That's it!** Your external INA3221 is now monitoring your custom power rails.

## 📁 Documentation

This project includes comprehensive documentation split by topic:

### 📖 Guides

- **[USAGE.md](USAGE.md)** - How to read sensors and integrate with your applications
- **[CALIBRATION.md](CALIBRATION.md)** - Shunt resistor calibration for accurate measurements
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solutions to common issues
- **[PERSISTENCE_GUIDE.md](PERSISTENCE_GUIDE.md)** - How persistence works and testing
- **[HOW_IT_WORKS.md](HOW_IT_WORKS.md)** - Technical deep-dive on I2C device creation
- **[TECHNICAL.md](TECHNICAL.md)** - Hardware specs, kernel details, and advanced topics

### 🔧 Scripts

| Script | Purpose |
|--------|---------|
| `setup_ina3221.sh` | Main installation - creates systemd service |
| `read_ina3221_sensors.sh` | Read all INA3221 sensors with formatted output |
| `calibrate_ina3221.sh` | Calibrate shunt resistors for accurate readings |
| `test_persistence.sh` | Test that device persists across reboots |

## 📊 Channel Configuration

### Built-in INA3221 (0x40)
| Channel | Monitors |
|---------|----------|
| 0 | VDD_IN - Main input voltage |
| 1 | VDD_CPU_GPU_CV - CPU/GPU power |
| 2 | VDD_SOC - SoC power |

### External INA3221 (0x41)
| Channel | Your Use Case |
|---------|---------------|
| 0 | Custom (e.g., DC input to Jetson) |
| 1 | Custom (e.g., Charge port) |
| 2 | Custom (e.g., Battery input) |

## 📖 Common Tasks

### Read Sensors
```bash
sudo ./read_ina3221_sensors.sh
```

### Change Shunt Resistor Values
See **[CALIBRATION.md](CALIBRATION.md)** for detailed instructions.

```bash
# Quick method for 100mΩ resistors:
nano calibrate_ina3221.sh  # Change SHUNT_VALUE=100000
sudo ./calibrate_ina3221.sh
```

### Check Service Status
```bash
sudo systemctl status ina3221-external.service
```

### Uninstall
```bash
sudo systemctl disable --now ina3221-external.service
sudo rm /etc/systemd/system/ina3221-external.service
sudo systemctl daemon-reload
echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device
```

## 🔍 How It Works

This project uses a **systemd service** to create the I2C device at boot (not device tree overlays, which don't work reliably on Jetson).

The service:
1. Creates I2C device at address 0x41
2. Kernel driver (`ina3221`) automatically binds
3. hwmon interface appears at `/sys/class/hwmon/hwmonX/`
4. Shunt resistors are calibrated to 500mΩ (configurable)

For technical details, see **[HOW_IT_WORKS.md](HOW_IT_WORKS.md)** and **[TECHNICAL.md](TECHNICAL.md)**.

## ⚡ Sample Output

```
=== INA3221 Power Monitor Reading ===

--- Built-in INA3221 (Address: 0x40) ---
  Channel 0 (VDD_IN):
    Voltage: 5104 mV
    Current: 912 mA
    Power: 4654 mW

--- External INA3221 (Address: 0x41) ---
  Channel 0 (CUSTOM_RAIL_1):
    Voltage: 11776 mV
    Current: 160 mA
    Power: 1884 mW
  Channel 1 (CUSTOM_RAIL_2):
    Voltage: 11968 mV
    Current: -178 mA      # Negative = supplying power
    Power: -2130 mW
  Channel 2 (CUSTOM_RAIL_3):
    Voltage: 11864 mV
    Current: 17 mA
    Power: 201 mW
```

## 🐛 Troubleshooting

Having issues? See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for solutions to:
- Device not detected
- Service fails to start  
- Incorrect readings
- Permission errors
- And more...

Quick diagnostic:
```bash
# Check I2C bus
sudo i2cdetect -y 1

# Check service logs
sudo journalctl -u ina3221-external.service -n 50

# Check device exists
ls /sys/bus/i2c/devices/1-0041/
```

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Support for other INA32xx variants
- Python library for easy integration
- Automated testing scripts
- Additional use case examples

## ⚠️ Important Notes

1. **Shunt Resistor Power Rating**: Ensure your shunt resistors can handle the power dissipation (P = I² × R)
2. **Voltage Limits**: INA3221 measures 0-26V bus voltage, ±163.8mV shunt voltage
3. **I2C Address**: Verify A0=HIGH, A1=LOW for address 0x41
4. **No Boot File Changes**: This method doesn't modify DTB or boot configuration (safe!)

## 📄 License

MIT License - See [LICENSE](LICENSE) file.

Free for commercial and personal use.

## 🤖 AI Development

This project was developed with AI assistance. All code has been:
- Validated against official documentation
- Tested on real Jetson Orin Nano hardware
- Verified for safety and reliability

Key references:
- [NVIDIA Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/)
- [INA3221 Datasheet](https://www.ti.com/lit/ds/symlink/ina3221.pdf)
- [Linux hwmon Documentation](https://www.kernel.org/doc/html/latest/hwmon/)

---

**Need help?** Check the documentation guides above or open an issue on GitHub.
