# hwmon Device Persistence Guide

## Current Status

Your system is already configured for persistence through device tree overlay:
- ✅ Boot configuration: `overlays=ina3221-external` in extlinux.conf
- ✅ Overlay file: `/boot/ina3221-external.dtbo` exists

## Why hwmon Creation Might Not Persist

### Problem 1: Manual Device Creation
If you manually created the device with:
```bash
echo ina3221 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device
```

This creates a **runtime-only** device that disappears on reboot.

### Problem 2: Overlay Not Loading
The overlay might not be loading properly at boot time.

## Solutions for Persistence

### Method 1: Device Tree Overlay (Recommended - Already Set Up)

**This should work automatically after reboot!** Your configuration is already correct.

To test:
```bash
# Reboot and check if device appears automatically
sudo reboot

# After reboot, check without manual creation:
ls /sys/bus/i2c/devices/i2c-1/1-0041/
sudo ./read_ina3221_sensors.sh
```

### Method 2: systemd Service (Fallback)

If the overlay doesn't work, create a systemd service:

```bash
# Create the service file
sudo tee /etc/systemd/system/ina3221-external.service << 'EOF'
[Unit]
Description=Create external INA3221 I2C device
After=multi-user.target
Before=graphical.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device'
ExecStartPost=/bin/sleep 2
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl enable ina3221-external.service

# Test the service
sudo systemctl start ina3221-external.service
sudo systemctl status ina3221-external.service
```

### Method 3: udev Rule (Alternative)

Create a udev rule for automatic device creation:

```bash
# Create udev rule
sudo tee /etc/udev/rules.d/99-ina3221-external.rules << 'EOF'
# Automatically create external INA3221 device
SUBSYSTEM=="i2c", KERNEL=="i2c-1", ACTION=="add", \
  RUN+="/bin/bash -c 'sleep 2 && echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device'"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Method 4: rc.local (Simple but Legacy)

Add to `/etc/rc.local` (if it exists):

```bash
# Edit rc.local
sudo nano /etc/rc.local

# Add before 'exit 0':
echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device 2>/dev/null || true
```

## Troubleshooting Overlay Loading

### Check if overlay is loading:
```bash
# Check kernel command line
cat /proc/cmdline | grep overlay

# Check kernel messages for overlay loading
sudo dmesg | grep -i overlay

# Check for device tree errors
sudo dmesg | grep -i "device tree"
```

### Force overlay loading test:
```bash
# Manual overlay loading (for testing)
sudo dtoverlay /boot/ina3221-external.dtbo

# Check if device appears
ls /sys/bus/i2c/devices/i2c-1/1-0041/
```

## Verification After Reboot

After implementing any method, verify persistence:

```bash
# 1. Reboot
sudo reboot

# 2. After reboot, check immediately (no manual creation)
ls /sys/bus/i2c/devices/i2c-1/1-0041/

# 3. Check hwmon devices
for i in /sys/class/hwmon/hwmon*/name; do echo "$i: $(cat $i)"; done | grep ina3221

# 4. Use the reading script
sudo ./read_ina3221_sensors.sh
```

## Recommended Approach

1. **First try**: Reboot and see if the overlay works (it should!)
2. **If overlay fails**: Use systemd service method
3. **For debugging**: Check kernel messages for overlay loading issues

The device tree overlay method (Method 1) is the cleanest and most integrated approach, and you already have it configured correctly.