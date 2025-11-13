# Troubleshooting Guide

## 🔍 Common Issues and Solutions

### Device Not Detected After Boot

**Symptoms:**
- `/sys/bus/i2c/devices/1-0041/` doesn't exist
- `read_ina3221_sensors.sh` shows "External INA3221 (0x41): Not found"

**Solutions:**

1. **Check service status:**
   ```bash
   sudo systemctl status ina3221-external.service
   ```

2. **Check service logs:**
   ```bash
   sudo journalctl -u ina3221-external.service -n 50
   ```

3. **Manually test device creation:**
   ```bash
   echo ina3221 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device
   ls /sys/bus/i2c/devices/1-0041/
   ```

4. **Check I2C bus:**
   ```bash
   sudo i2cdetect -y 1
   # Should show device at address 0x41
   ```

### Service Fails to Start

**Check for errors:**
```bash
# View detailed error messages
sudo journalctl -u ina3221-external.service -n 100 --no-pager

# Check if device already exists
ls /sys/bus/i2c/devices/1-0041/

# If it exists, the service may have already run
# Try stopping and restarting:
echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device
sudo systemctl restart ina3221-external.service
```

### I2C Device Not Detected on Bus

**Symptoms:**
- `i2cdetect -y 1` doesn't show device at 0x41
- Kernel logs show I2C errors

**Hardware Checks:**

1. **Verify address configuration:**
   - A0 pin: HIGH
   - A1 pin: LOW
   - This sets address to 0x41

2. **Check power:**
   ```bash
   # Measure 3.3V or 5V on INA3221 VCC pin
   # Check GND connection
   ```

3. **Verify I2C connections:**
   - SDA connected to GPIO27 (I2C-1 SDA)
   - SCL connected to GPIO28 (I2C-1 SCL)
   - Pull-up resistors present (usually on board)

4. **Test I2C bus:**
   ```bash
   # Install i2c-tools if not present
   sudo apt-get install i2c-tools
   
   # Scan bus
   sudo i2cdetect -y 1
   
   # Check for conflicts at 0x40 (built-in sensor)
   ```

### Permission Errors

**Symptoms:**
- "Permission denied" when reading sensors
- Commands work with `sudo` but not without

**Solutions:**

1. **Use sudo for sensor reads:**
   ```bash
   sudo ./read_ina3221_sensors.sh
   ```

2. **Add user to i2c group (permanent fix):**
   ```bash
   sudo usermod -a -G i2c $USER
   # Log out and back in for changes to take effect
   ```

3. **Check file permissions:**
   ```bash
   ls -l /sys/class/hwmon/hwmon*/curr1_input
   ```

### Incorrect Current/Voltage Readings

**Possible Causes:**

1. **Wrong shunt resistor calibration:**
   ```bash
   # Check current calibration
   HWMON=$(ls -d /sys/bus/i2c/devices/1-0041/hwmon/hwmon* 2>/dev/null | head -n1)
   cat $HWMON/shunt1_resistor
   
   # Should match your actual shunt resistor value
   # Default is 500000 (500mΩ)
   ```

2. **Recalibrate:**
   ```bash
   sudo ./calibrate_ina3221.sh
   # Or edit the script to set correct value
   ```

3. **Verify with multimeter:**
   - Measure voltage directly
   - Compare with INA3221 reading
   - Difference should be minimal

### Hwmon Device Number Changes

**Symptoms:**
- `hwmon6` becomes `hwmon4` after reboot
- Paths break in custom scripts

**Solutions:**

1. **Use dynamic detection (recommended):**
   ```bash
   # Find device dynamically
   HWMON=$(ls -d /sys/bus/i2c/devices/1-0041/hwmon/hwmon* 2>/dev/null | head -n1)
   cat $HWMON/curr1_input
   ```

2. **Use I2C device path directly:**
   ```bash
   # This path is stable
   cat /sys/bus/i2c/devices/1-0041/hwmon/hwmon*/curr1_input
   ```

3. **Use the provided script:**
   ```bash
   # Automatically finds correct hwmon device
   sudo ./read_ina3221_sensors.sh
   ```

### Device Disappears After Reboot

**Symptoms:**
- Works after manual creation
- Doesn't persist across reboots

**Check systemd service:**

```bash
# Is service enabled?
sudo systemctl is-enabled ina3221-external.service

# If not, enable it:
sudo systemctl enable ina3221-external.service

# Check if it runs at boot:
sudo systemctl status ina3221-external.service
```

### Reading All Zeros

**Possible Causes:**

1. **No current flowing:**
   - Normal if circuit is off
   - Check your load/power source

2. **Shunt resistor issues:**
   - Not connected
   - Broken trace on PCB
   - Wrong calibration

3. **Driver not loaded:**
   ```bash
   lsmod | grep ina3221
   # Should show: ina3221
   
   # If not loaded:
   sudo modprobe ina3221
   ```

### Kernel Error Messages

**Check kernel logs:**
```bash
# Recent INA3221-related messages
dmesg | grep -i ina3221

# I2C-related errors
dmesg | grep -i i2c

# Recent kernel messages
dmesg | tail -50
```

**Common error messages:**

- **"i2c i2c-1: Failed to register i2c client"**
  - Device already exists
  - Remove and recreate: `echo 0x41 > /sys/bus/i2c/devices/i2c-1/delete_device`

- **"ina3221: probe failed"**
  - Hardware issue
  - Address conflict
  - Check I2C connections

- **"Remote I/O error"**
  - Device not responding
  - Check hardware connections
  - Verify power supply

## 🔧 Advanced Debugging

### Manual Device Creation Test

```bash
# Remove device if it exists
echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device 2>/dev/null

# Wait a moment
sleep 1

# Create device manually
echo ina3221 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device

# Check if created
ls -l /sys/bus/i2c/devices/1-0041/

# Check hwmon interface
find /sys/bus/i2c/devices/1-0041/ -name hwmon

# Test reading
cat /sys/bus/i2c/devices/1-0041/hwmon/hwmon*/curr1_input
```

### I2C Bus Scanning

```bash
# Scan I2C bus 1
sudo i2cdetect -y 1

# Expected output should show:
# - 0x40: Built-in INA3221
# - 0x41: External INA3221

# If 0x41 shows "UU", it's in use (good!)
# If 0x41 shows "41", it's detected but driver not bound
# If 0x41 shows "--", device not detected (hardware issue)
```

### Check Driver Binding

```bash
# Check if driver is bound
ls -l /sys/bus/i2c/devices/1-0041/driver

# Should link to: ../../../bus/i2c/drivers/ina3221

# If not bound, try manual binding:
echo 1-0041 | sudo tee /sys/bus/i2c/drivers/ina3221/bind
```

### Service Debugging

```bash
# Stop service
sudo systemctl stop ina3221-external.service

# Run service commands manually
echo ina3221 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device
sleep 2

# Find hwmon and calibrate
HWMON=$(ls -d /sys/bus/i2c/devices/1-0041/hwmon/hwmon* 2>/dev/null | head -n1)
echo 500000 | sudo tee $HWMON/shunt1_resistor
echo 500000 | sudo tee $HWMON/shunt2_resistor
echo 500000 | sudo tee $HWMON/shunt3_resistor

# Test reading
cat $HWMON/curr1_input
```

## 🔄 Complete Reset

If all else fails, perform a complete reset:

```bash
# Stop and disable service
sudo systemctl stop ina3221-external.service
sudo systemctl disable ina3221-external.service

# Remove device
echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device 2>/dev/null

# Remove service file
sudo rm /etc/systemd/system/ina3221-external.service

# Reload systemd
sudo systemctl daemon-reload

# Reinstall
sudo ./setup_ina3221.sh

# Reboot
sudo reboot
```

## 📞 Getting Help

If you're still having issues:

1. **Collect diagnostic information:**
   ```bash
   # Create a diagnostic report
   {
       echo "=== System Info ==="
       uname -a
       cat /etc/nv_tegra_release
       
       echo -e "\n=== I2C Devices ==="
       sudo i2cdetect -y 1
       
       echo -e "\n=== I2C Device 1-0041 ==="
       ls -la /sys/bus/i2c/devices/1-0041/ 2>&1
       
       echo -e "\n=== Service Status ==="
       sudo systemctl status ina3221-external.service
       
       echo -e "\n=== Service Logs ==="
       sudo journalctl -u ina3221-external.service -n 50
       
       echo -e "\n=== Kernel Messages ==="
       dmesg | grep -i ina3221 | tail -20
       
       echo -e "\n=== Hwmon Devices ==="
       ls -la /sys/class/hwmon/
       
   } > ina3221_diagnostic.txt
   
   cat ina3221_diagnostic.txt
   ```

2. **Check hardware:**
   - Verify connections with multimeter
   - Check solder joints
   - Test with known-good INA3221 board

3. **Review documentation:**
   - See `HOW_IT_WORKS.md` for technical details
   - Check `USAGE.md` for correct usage
   - Review `CALIBRATION.md` for calibration issues
