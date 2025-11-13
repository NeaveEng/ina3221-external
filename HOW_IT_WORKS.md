# How Linux I2C Device Creation Works

This document explains how the INA3221 external device is created and managed in Linux.

## The Key Command

The entire device creation happens with this single command:

```bash
echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device
```

This single line does all the magic. Let me break it down:

## 1. sysfs Interface (`/sys/`)

- Linux exposes hardware control through the `/sys/` filesystem
- `/sys/bus/i2c/` contains all I2C bus information
- You can interact with hardware by reading/writing to these files
- Think of it as a "control panel" for hardware in file form

## 2. The Command Parts

```bash
echo "ina3221 0x41" > /sys/bus/i2c/devices/i2c-1/new_device
       ^       ^                              ^          ^
       |       |                              |          |
    Driver  Address                      Bus Number   Special File
```

Breaking it down:
- **`ina3221`** - The Linux kernel driver name to use
- **`0x41`** - The I2C address where the hardware is located (hexadecimal)
- **`i2c-1`** - Which I2C bus (there can be multiple I2C buses)
- **`new_device`** - A special file that tells Linux "create a new device"

## 3. What Happens Behind the Scenes

When you write to `new_device`, the Linux kernel:

1. **Parses the input**: "Oh, they want an `ina3221` driver at address `0x41`"
2. **Loads the driver**: The kernel finds and loads the `ina3221.ko` driver module (if not already loaded)
3. **Probes the device**: The driver talks to address `0x41` on I2C bus 1 to verify hardware exists
4. **Creates device files**: If successful, creates:
   - `/sys/bus/i2c/devices/1-0041/` - Device directory (1-0041 = bus 1, address 0x41)
   - `/sys/class/hwmon/hwmonX/` - Hardware monitoring interface
   - Various files for reading voltage, current, power, etc.

## 4. Why This Works

The INA3221 chip is physically connected to:
- **I2C bus 1** (the `gen2_i2c` bus on Jetson Orin Nano)
- **Address 0x41** (configured by pulling A0 HIGH, A1 LOW on the hardware)

The Linux kernel already has the `ina3221` driver built-in (or as a module), so when you tell it "there's an ina3221 at this address," it knows exactly how to communicate with it using the I2C protocol.

## 5. The Complete Flow

```
Your Command
     ↓
echo "ina3221 0x41" > /sys/bus/i2c/devices/i2c-1/new_device
     ↓
Linux Kernel receives the request
     ↓
Kernel loads ina3221 driver (if not already loaded)
     ↓
Driver sends I2C commands to address 0x41 to detect chip
     ↓
Chip responds: "Yes, I'm here and I'm an INA3221!"
     ↓
Kernel creates device files:
  - /sys/bus/i2c/devices/1-0041/
  - /sys/class/hwmon/hwmon4/ (or hwmon5, hwmon6, etc.)
     ↓
You can now read:
  - /sys/class/hwmon/hwmon4/in1_input (voltage in mV)
  - /sys/class/hwmon/hwmon4/curr1_input (current in mA)
  - /sys/class/hwmon/hwmon4/shunt1_resistor (shunt resistor value)
  - etc.
```

## 6. Why Use a Systemd Service?

The device creation via sysfs is **not persistent** - it disappears on reboot because:
- The `/sys/` filesystem is virtual (exists only in RAM)
- It's recreated fresh on every boot
- Only devices in the device tree or auto-detected appear automatically

So we use a systemd service to run this command automatically at every boot:

```ini
[Unit]
Description=Create external INA3221 I2C device with labels
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

This ensures the device is recreated every time the system boots.

## 7. Alternative: Device Tree

Normally, hardware devices are defined in the **device tree** - a hardware description compiled into the kernel. That's why the built-in INA3221 (at address 0x40) appears automatically without any manual commands - it's defined in the device tree.

**Device Tree Pros:**
- ✅ Permanent - device appears automatically at boot
- ✅ Can include device properties (labels, calibration values)
- ✅ Proper kernel integration

**Device Tree Cons on Jetson:**
- ❌ Overlays don't load reliably on Jetson bootloaders
- ❌ Requires compilation and boot configuration
- ❌ More complex to set up

**sysfs Method Pros:**
- ✅ Works reliably on Jetson
- ✅ Simple to understand and implement
- ✅ Easy to test and debug
- ✅ Can be done without rebooting

**sysfs Method Cons:**
- ❌ Requires systemd service for persistence
- ❌ Doesn't create kernel label files (we create them separately)

## 8. Quick Demonstration

You can see this in action right now:

```bash
# Before creating device - list all I2C devices
ls /sys/bus/i2c/devices/
# Output: 1-0040  (only the built-in INA3221 at address 0x40)

# Create the device manually
echo ina3221 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/new_device

# After creating device
ls /sys/bus/i2c/devices/
# Output: 1-0040  1-0041  (now both exist!)

# Check what driver it's using
cat /sys/bus/i2c/devices/1-0041/name
# Output: ina3221

# Read some values
cat /sys/class/hwmon/hwmon4/in1_input    # Voltage in millivolts
cat /sys/class/hwmon/hwmon4/curr1_input  # Current in milliamps

# Delete the device when done testing
echo 0x41 | sudo tee /sys/bus/i2c/devices/i2c-1/delete_device

# It's gone again
ls /sys/bus/i2c/devices/
# Output: 1-0040  (back to just the built-in one)
```

## 9. Understanding I2C Addresses

I2C addresses are how devices are identified on the bus:

- **0x40** - Built-in INA3221 (hardwired in device tree)
- **0x41** - External INA3221 (our added device)

The INA3221 chip can be configured to different addresses using its A0 and A1 pins:

| A0  | A1  | Address |
|-----|-----|---------|
| GND | GND | 0x40    |
| VCC | GND | 0x41    | ← Our configuration
| GND | VCC | 0x42    |
| VCC | VCC | 0x43    |

This is why we can have multiple INA3221 chips on the same I2C bus - each has a unique address.

## 10. Why hwmon Numbers Change

You might notice the hwmon number (hwmon4, hwmon5, etc.) can change between boots. This is because:

- The kernel assigns hwmon numbers sequentially as devices are detected
- The order can vary based on driver loading timing
- This is why our scripts **search** for the correct hwmon device instead of hardcoding the number

Our setup script finds the correct device like this:

```bash
for hwmon in /sys/class/hwmon/hwmon*/device; do
    target=$(readlink -f "$hwmon")
    if [[ "$target" == *"1-0041"* ]]; then
        HWMON_DEVICE=$(dirname "$hwmon")
        break
    fi
done
```

This searches all hwmon devices and finds the one linked to `1-0041` (our external INA3221).

## Summary

**The Linux way:**
1. Hardware is accessed through the `/sys/` filesystem
2. You can dynamically create devices by writing to special files
3. The kernel loads the appropriate driver and creates interfaces
4. This is powerful, flexible, and requires no reboot!

This is the beauty of the Linux sysfs system - hardware management through file operations. It's elegant, scriptable, and very Unix-like: "everything is a file."
