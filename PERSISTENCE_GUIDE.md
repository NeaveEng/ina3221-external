# hwmon Device Persistence Guide

## Current Setup

The system uses a systemd service to create and configure the external INA3221 device at boot:
- ✅ Service: `ina3221-external.service` creates device at I2C address 0x41
- ✅ Label support: Creates label files in `/etc/ina3221-external/labels/`
- ✅ Sensor symlinks: Creates convenient access in `/etc/ina3221-external/sensors/`
- ✅ Auto-calibration: Sets 500mΩ shunt resistors automatically

## How It Works

The systemd service method is used because:
- **Reliable**: Device tree overlays don't load consistently on Jetson bootloaders
- **Labels**: Creates label files that sysfs method normally doesn't provide
- **Simple**: No complex device tree compilation or boot configuration needed
- **Persistent**: Automatically creates device at every boot

## Installation

```bash
sudo ./setup_with_labels.sh
```

This creates:
1. Systemd service at `/etc/systemd/system/ina3221-external.service`
2. Label configuration at `/etc/ina3221-external/ina3221_labels.conf`
3. Label files in `/etc/ina3221-external/labels/`
4. Sensor symlinks in `/etc/ina3221-external/sensors/`

## Verification After Reboot

After installation, verify persistence by rebooting:

```bash
# 1. Reboot
sudo reboot

# 2. After reboot, check device exists (no manual creation needed)
ls /sys/bus/i2c/devices/1-0041/

# 3. Check label files
ls -la /etc/ina3221-external/labels/
cat /etc/ina3221-external/labels/in1_label

# 4. Check sensor symlinks
ls -la /etc/ina3221-external/sensors/

# 5. Read sensor values
sudo cat /etc/ina3221-external/sensors/VDD_IN_CH0_current

# 6. Use the reading script
sudo ./read_ina3221_sensors.sh
```

## Troubleshooting

### Check if service is running:
```bash
# Check service status
systemctl status ina3221-external.service

# View service logs
journalctl -u ina3221-external.service -n 50

# Check if device was created
ls -la /sys/bus/i2c/devices/1-0041/
```

### Common Issues

**Issue: Device not created after reboot**
- Service may not be enabled
- Solution: `sudo systemctl enable ina3221-external.service`

**Issue: Labels not found**
- Service may have failed
- Solution: Check `journalctl -u ina3221-external.service`
- Restart: `sudo systemctl restart ina3221-external.service`

**Issue: Permission denied reading sensors**
- Need sudo to read hwmon files
- Solution: Use `sudo` or add user to appropriate group

## Customizing Labels

To change the channel labels:

```bash
# 1. Edit the label configuration
sudo nano /etc/ina3221-external/ina3221_labels.conf

# 2. Change the label names:
CHANNEL_0_LABEL="YOUR_CUSTOM_NAME_CH0"
CHANNEL_1_LABEL="YOUR_CUSTOM_NAME_CH1"
CHANNEL_2_LABEL="YOUR_CUSTOM_NAME_CH2"

# 3. Restart the service
sudo systemctl restart ina3221-external.service

# 4. Verify new labels
cat /etc/ina3221-external/labels/in1_label
ls -la /etc/ina3221-external/sensors/
```

## Uninstalling

To remove the external INA3221 setup:

```bash
# Stop and disable service
sudo systemctl stop ina3221-external.service
sudo systemctl disable ina3221-external.service

# Remove service file
sudo rm /etc/systemd/system/ina3221-external.service

# Remove configuration and labels
sudo rm -rf /etc/ina3221-external/

# Reload systemd
sudo systemctl daemon-reload

# Remove device (until next reboot)
echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device
```