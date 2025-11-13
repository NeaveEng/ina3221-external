#!/bin/bash

# Script to set up INA3221 external device via systemd service
# Usage: sudo ./setup_ina3221.sh

set -e

SERVICE_NAME="ina3221-external"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "=== Setting up INA3221 External Device ==="
echo

# Create systemd service
echo "Creating systemd service..."
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Create external INA3221 I2C device
After=multi-user.target
Before=graphical.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo ina3221 0x41 > /sys/bus/i2c/devices/i2c-1/new_device'
ExecStartPost=/bin/sleep 2
ExecStartPost=/bin/bash -c 'for hwmon in /sys/class/hwmon/hwmon*/device; do if [[ "$(readlink -f $hwmon)" == *"1-0041"* ]]; then HWMON=$(dirname $hwmon); echo 500000 > $HWMON/shunt1_resistor 2>/dev/null || true; echo 500000 > $HWMON/shunt2_resistor 2>/dev/null || true; echo 500000 > $HWMON/shunt3_resistor 2>/dev/null || true; fi; done'
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
SuccessExitStatus=0 1

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file created: $SERVICE_FILE"

# Reload systemd
echo
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
systemctl status "$SERVICE_NAME.service" --no-pager -l || true

# Verify device creation
echo
echo "=== Verification ==="
if [ -d "/sys/bus/i2c/devices/1-0041" ]; then
    echo "✅ External INA3221 device created at: /sys/bus/i2c/devices/1-0041/"
    
    # Find hwmon device
    for hwmon in /sys/class/hwmon/hwmon*/device; do
        if [[ "$(readlink -f $hwmon)" == *"1-0041"* ]]; then
            HWMON_DEVICE=$(dirname $hwmon)
            echo "✅ hwmon device: $HWMON_DEVICE"
            echo
            echo "Shunt resistor calibration:"
            echo "  Channel 1: $(cat $HWMON_DEVICE/shunt1_resistor 2>/dev/null || echo 'N/A') µΩ"
            echo "  Channel 2: $(cat $HWMON_DEVICE/shunt2_resistor 2>/dev/null || echo 'N/A') µΩ"
            echo "  Channel 3: $(cat $HWMON_DEVICE/shunt3_resistor 2>/dev/null || echo 'N/A') µΩ"
            break
        fi
    done
else
    echo "❌ Device creation failed. Check service logs:"
    echo "   journalctl -u $SERVICE_NAME.service"
fi

echo
echo "=== Setup Complete ==="
echo
echo "The external INA3221 will be created automatically on every boot."
echo
echo "To read sensors: sudo ./read_ina3221_sensors.sh"
echo "To check status: systemctl status $SERVICE_NAME.service"
echo
echo "To uninstall:"
echo "  sudo systemctl disable --now $SERVICE_NAME.service"
echo "  sudo rm $SERVICE_FILE"
echo "  sudo systemctl daemon-reload"
