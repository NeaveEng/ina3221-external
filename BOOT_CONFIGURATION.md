# INA3221 Overlay Boot Configuration Guide

## Prerequisites

1. Overlay file copied to boot directory:
   ```bash
   sudo cp /home/dev/device-tree/ina3221-second-v2.dtbo /boot/
   ```

## Method 1: Automatic Script (Recommended)

Use the provided script to safely add the overlay:

```bash
sudo ./add_ina3221_overlay.sh
```

This script will:
- Create a backup of your current extlinux.conf
- Add the overlay to your boot configuration
- Preserve your existing JetsonIO settings

## Method 2: Manual extlinux.conf Modification

1. **Backup your current configuration:**
   ```bash
   sudo cp /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.backup
   ```

2. **Edit the configuration:**
   ```bash
   sudo nano /boot/extlinux/extlinux.conf
   ```

3. **Find the JetsonIO APPEND line and add the overlay:**
   
   **Before:**
   ```
   APPEND ${cbootargs} root=PARTUUID=... overlays=other-overlays
   ```
   
   **After:**
   ```
   APPEND ${cbootargs} root=PARTUUID=... overlays=other-overlays,ina3221-second-v2
   ```
   
   **If no overlays exist yet:**
   ```
   APPEND ${cbootargs} root=PARTUUID=... overlays=ina3221-second-v2
   ```

4. **Save and reboot:**
   ```bash
   sudo reboot
   ```

## Method 3: Using Device Tree Overlays Directory

Some Jetson configurations support a dedicated overlays directory:

1. **Create overlays directory (if it doesn't exist):**
   ```bash
   sudo mkdir -p /boot/dtb/overlays
   ```

2. **Copy overlay to overlays directory:**
   ```bash
   sudo cp /home/dev/device-tree/ina3221-second-v2.dtbo /boot/dtb/overlays/
   ```

3. **Add to extlinux.conf:**
   ```
   APPEND ${cbootargs} ... dtoverlay=ina3221-second-v2
   ```

## Current Configuration Analysis

Your current extlinux.conf shows:
- You're using JetsonIO custom configuration
- Current FDT: `/boot/kernel_tegra234-p3767-0004-p3509-a02-user-custom.dtb`
- Default boot: `JetsonIO` label

## Verification After Boot

After rebooting, verify the overlay is loaded:

```bash
# Check if the second INA3221 is detected
sudo i2cdetect -y 1

# Should show devices at 0x40 and 0x41

# Check kernel log for overlay loading
dmesg | grep -i ina3221

# Check hwmon devices
ls /sys/class/hwmon/hwmon*/name | xargs grep ina3221
```

## Troubleshooting

### Overlay Not Loading
1. Check kernel log: `dmesg | grep overlay`
2. Verify overlay file exists: `ls -la /boot/ina3221-second-v2.dtbo`
3. Check extlinux.conf syntax: `cat /boot/extlinux/extlinux.conf`

### Boot Issues
1. Restore backup: `sudo cp /boot/extlinux/extlinux.conf.backup /boot/extlinux/extlinux.conf`
2. Reboot and check logs

### I2C Address Conflict
1. Verify hardware addressing (A0/A1 pins on INA3221)
2. Use i2cdetect to check for conflicts before connecting hardware

## Advanced: Runtime Loading/Unloading

For testing without reboot (if kernel supports it):

```bash
# Load overlay at runtime (may not work on all kernels)
sudo dtoverlay ina3221-second-v2

# Unload overlay
sudo dtoverlay -r ina3221-second-v2
```

Note: Runtime overlay support varies by kernel version and configuration.

## Rollback Instructions

To remove the overlay:

1. **Using the backup:**
   ```bash
   sudo cp /boot/extlinux/extlinux.conf.ina3221-backup /boot/extlinux/extlinux.conf
   sudo reboot
   ```

2. **Manual removal:**
   Edit `/boot/extlinux/extlinux.conf` and remove `ina3221-second-v2` from the overlays list.

## Integration with Jetson-IO

The overlay will work alongside your existing JetsonIO configuration. Your current custom header config and CSI camera setup will remain intact.