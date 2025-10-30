#!/bin/bash

# Script to set up systemd service for INA3221 external persistence
# Usage: sudo ./setup_persistence.sh

set -e

SERVICE_NAME="ina3221-external"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "=== Setting up INA3221 External Persistence ==="
echo

# Create systemd service
echo "Creating systemd service with calibration..."
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Create external INA3221 I2C device
After=multi-user.target
Before=graphical.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device'
ExecStartPost=/bin/sleep 2
ExecStartPost=/bin/bash -c 'echo 500000 > /sys/class/hwmon/hwmon6/shunt1_resistor'
ExecStartPost=/bin/bash -c 'echo 500000 > /sys/class/hwmon/hwmon6/shunt2_resistor'
ExecStartPost=/bin/bash -c 'echo 500000 > /sys/class/hwmon/hwmon6/shunt3_resistor'
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
# Ignore failures if device already exists
SuccessExitStatus=0 1

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file created: $SERVICE_FILE"

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service
echo "Enabling service for auto-start..."
systemctl enable "$SERVICE_NAME.service"

# Start the service now
echo "Starting service..."
systemctl start "$SERVICE_NAME.service"

# Check status
echo
echo "Service status:"
systemctl status "$SERVICE_NAME.service" --no-pager -l

# Verify device creation
echo
if [ -d "/sys/bus/i2c/devices/i2c-1/1-0041" ]; then
    echo "✅ SUCCESS: External INA3221 device created!"
    echo "   Device path: /sys/bus/i2c/devices/i2c-1/1-0041/"
    
    # Check hwmon
    echo
    echo "Checking hwmon devices:"
    for i in /sys/class/hwmon/hwmon*/name; do 
        if [ "$(cat $i 2>/dev/null)" = "ina3221" ]; then
            device_link=$(readlink -f $(dirname $i)/device 2>/dev/null)
            if [[ "$device_link" == *"1-0041"* ]]; then
                hwmon_path=$(dirname $i)
                echo "✅ External INA3221 hwmon: $hwmon_path"
                echo "   Shunt resistor calibration:"
                echo "     Channel 1: $(cat $hwmon_path/shunt1_resistor 2>/dev/null || echo 'N/A') µΩ"
                echo "     Channel 2: $(cat $hwmon_path/shunt2_resistor 2>/dev/null || echo 'N/A') µΩ"
                echo "     Channel 3: $(cat $hwmon_path/shunt3_resistor 2>/dev/null || echo 'N/A') µΩ"
            fi
        fi
    done
else
    echo "❌ Device creation failed. Check service logs:"
    echo "   journalctl -u $SERVICE_NAME.service"
fi

echo
echo "=== Persistence Setup Complete ==="
echo
echo "The external INA3221 will now be:"
echo "  1. Created automatically on every boot at I2C address 0x41"
echo "  2. Calibrated with 500mΩ (0.5Ω) shunt resistors"
echo "  3. Available as hwmon6 for power monitoring"
echo
echo "To test persistence:"
echo "1. Reboot: sudo reboot"
echo "2. After reboot, check: sudo ./read_ina3221_sensors.sh"
echo
echo "To remove persistence:"
echo "  sudo systemctl disable $SERVICE_NAME.service"
echo "  sudo rm $SERVICE_FILE"