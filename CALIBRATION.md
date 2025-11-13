# Shunt Resistor Calibration Guide

## ⚡ Overview

The INA3221 uses shunt resistors to measure current. The system automatically calibrates for **500mΩ (0.5Ω)** shunt resistors by default. If you have different values, you need to recalibrate.

## 📐 Shunt Resistor Values

Common shunt resistor values and their micro-ohm equivalents:

| Resistance | Micro-ohms | Use Case |
|------------|------------|----------|
| 5mΩ | 5000 | Very high current (>10A) |
| 10mΩ | 10000 | High current (5-10A) |
| 100mΩ | 100000 | Medium current (1-5A) |
| 500mΩ | 500000 | Low current (<1A) - **Default** |
| 1Ω | 1000000 | Very low current (<500mA) |

**Important**: Ensure your shunt resistor can handle the expected current and power dissipation.

## 🔧 Calibration Methods

### Method 1: Automatic Calibration (Recommended)

Use the provided calibration script:

```bash
# For default 500mΩ shunt resistors
sudo ./calibrate_ina3221.sh

# For custom values, edit the script first:
nano calibrate_ina3221.sh
# Change: SHUNT_VALUE=500000  # to your value in micro-ohms

sudo ./calibrate_ina3221.sh
```

### Method 2: Manual Calibration

Set shunt resistor values directly:

```bash
# Find your hwmon device first
HWMON=$(ls -d /sys/bus/i2c/devices/1-0041/hwmon/hwmon* 2>/dev/null | head -n1)

# Set values (in micro-ohms):
sudo bash -c "echo 100000 > $HWMON/shunt1_resistor"  # Channel 0: 100mΩ
sudo bash -c "echo 100000 > $HWMON/shunt2_resistor"  # Channel 1: 100mΩ
sudo bash -c "echo 100000 > $HWMON/shunt3_resistor"  # Channel 2: 100mΩ

# Verify the values were set
cat $HWMON/shunt1_resistor
cat $HWMON/shunt2_resistor
cat $HWMON/shunt3_resistor

# Test readings
sudo ./read_ina3221_sensors.sh
```

### Method 3: Persistent Calibration

To make custom calibration persistent across reboots, edit the setup script:

```bash
# Edit the setup script
nano setup_ina3221.sh

# Find the calibration section and change these lines:
# From:
echo 500000 > $HWMON/shunt1_resistor
echo 500000 > $HWMON/shunt2_resistor
echo 500000 > $HWMON/shunt3_resistor

# To (example for 100mΩ):
echo 100000 > $HWMON/shunt1_resistor
echo 100000 > $HWMON/shunt2_resistor
echo 100000 > $HWMON/shunt3_resistor

# Re-run setup to apply changes
sudo ./setup_ina3221.sh
```

## 🧮 Calculating Shunt Resistor Value

If you need to measure your shunt resistor value:

### Using a Multimeter
1. Disconnect the shunt resistor from the circuit
2. Use a 4-wire (Kelvin) measurement if possible
3. Set multimeter to lowest resistance range
4. Measure multiple times and average

### From Datasheet
Check your INA3221 breakout board documentation for the shunt resistor value.

### From Current Measurements
If you know the actual current:
1. Read the voltage across the shunt: `cat /sys/class/hwmon/hwmonX/in1_input`
2. Measure actual current with a known-good ammeter
3. Calculate: R = V / I (in ohms)
4. Convert to micro-ohms: multiply by 1,000,000

## 🔍 Verification

After calibration, verify accuracy:

```bash
# Method 1: Compare with known load
# - Connect a known load (e.g., resistor with measured voltage)
# - Calculate expected current
# - Compare with INA3221 reading

# Method 2: Use external ammeter
# - Connect ammeter in series
# - Compare readings

# Method 3: Check power calculation
# Power should equal: (Voltage × Current) / 1000
sudo ./read_ina3221_sensors.sh
```

## ⚠️ Important Considerations

### Power Dissipation
The shunt resistor dissipates power: P = I² × R

Example: 5A through 100mΩ = 5² × 0.1 = 2.5W

Ensure your shunt resistor is rated for the power dissipation!

### Measurement Range
The INA3221 has these limits:
- **Shunt voltage**: ±163.8mV max
- **Bus voltage**: 0-26V
- **Maximum current** depends on shunt resistor

Calculate max current: I_max = 163.8mV / R_shunt

Examples:
- 5mΩ → 32.76A max
- 100mΩ → 1.638A max
- 500mΩ → 327.6mA max

### Accuracy
- Use precision shunt resistors (1% or better tolerance)
- Temperature coefficient affects accuracy
- Kelvin (4-wire) connection recommended for low values

## 🔧 Per-Channel Calibration

You can use different shunt values for each channel:

```bash
HWMON=$(ls -d /sys/bus/i2c/devices/1-0041/hwmon/hwmon* 2>/dev/null | head -n1)

# Different values for each channel
sudo bash -c "echo 10000 > $HWMON/shunt1_resistor"   # Ch0: 10mΩ (high current)
sudo bash -c "echo 100000 > $HWMON/shunt2_resistor"  # Ch1: 100mΩ (medium current)
sudo bash -c "echo 500000 > $HWMON/shunt3_resistor"  # Ch2: 500mΩ (low current)
```

## 📊 Reading Calibrated Values

```bash
HWMON=$(ls -d /sys/bus/i2c/devices/1-0041/hwmon/hwmon* 2>/dev/null | head -n1)

# Check current calibration
echo "Channel 0: $(cat $HWMON/shunt1_resistor) µΩ"
echo "Channel 1: $(cat $HWMON/shunt2_resistor) µΩ"
echo "Channel 2: $(cat $HWMON/shunt3_resistor) µΩ"

# Calculate max measurable current for each channel
echo "Max current Ch0: $(echo "scale=2; 163800 / $(cat $HWMON/shunt1_resistor)" | bc) mA"
echo "Max current Ch1: $(echo "scale=2; 163800 / $(cat $HWMON/shunt2_resistor)" | bc) mA"
echo "Max current Ch2: $(echo "scale=2; 163800 / $(cat $HWMON/shunt3_resistor)" | bc) mA"
```

## 🐛 Troubleshooting

### Readings Seem Incorrect

1. **Verify shunt resistor value**:
   ```bash
   cat $HWMON/shunt1_resistor
   ```

2. **Check actual shunt resistor** with multimeter

3. **Recalibrate** with correct value

4. **Verify connections** (ensure good contact)

### Current Reads as Zero

- Shunt resistor value too high for the current
- No current flowing through the circuit
- Shunt resistor not properly connected

### Current Maxes Out

- Shunt voltage exceeds ±163.8mV
- Need smaller shunt resistor value
- Current exceeds measurement range

### Negative Current Readings

This is normal! Negative current indicates:
- Current flowing in opposite direction
- Typical for battery charging/discharging monitoring
- Channel 1 in your setup likely shows negative when charging
