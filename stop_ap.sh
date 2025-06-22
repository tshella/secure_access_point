#!/bin/bash
set -e

# === CONFIG ===
IFACE="wlo1"
CON_NAME="hostap"
DNSMASQ_PID_FILE="/tmp/tshella_dnsmasq.pid"
PYTHON_PID_FILE="/tmp/tshella_python_server.pid"
DNSMASQ_LOG="/tmp/tshella_dnsmasq.log"

echo "🛑 Stopping Access Point..."

# Save Docker bridge status
DOCKER_WAS_ACTIVE=$(systemctl is-active docker.service 2>/dev/null || echo "inactive")
DOCKER_BRIDGES=$(sudo nmcli -t -f NAME,DEVICE,TYPE con show | grep ':bridge$' | cut -d: -f1,2)

# Deactivate and remove NetworkManager AP
echo "🔌 Shutting down access point connection..."
sudo nmcli con down "$CON_NAME" 2>/dev/null || true
sudo nmcli con delete "$CON_NAME" 2>/dev/null || true

# Stop dnsmasq if running
if [ -f "$DNSMASQ_PID_FILE" ]; then
    PID=$(cat "$DNSMASQ_PID_FILE")
    echo "❌ Stopping dnsmasq (PID $PID)..."
    sudo kill "$PID" 2>/dev/null || true
    sudo rm -f "$DNSMASQ_PID_FILE"
else
    sudo killall dnsmasq 2>/dev/null || true
fi

# Stop Python web server
if [ -f "$PYTHON_PID_FILE" ]; then
    PID=$(cat "$PYTHON_PID_FILE")
    echo "❌ Stopping web server (PID $PID)..."
    sudo kill "$PID" 2>/dev/null || true
    sudo rm -f "$PYTHON_PID_FILE"
else
    sudo pkill -f "python3 -m http.server" 2>/dev/null || true
fi

# Remove captive portal redirection
echo "🔥 Removing captive portal rules..."
sudo iptables -t nat -F 2>/dev/null || true

# Restart systemd-resolved if we stopped it
if [ -n "$SYSTEMD_RESOLVED_STOPPED" ]; then
    echo "🔒 Restarting systemd-resolved..."
    sudo systemctl start systemd-resolved 2>/dev/null || true
fi

# Reset firewall rules
echo "🔥 Resetting firewall rules..."
if command -v ufw &> /dev/null; then
    sudo ufw delete allow in on "$IFACE" to any port 67,68 proto udp 2>/dev/null || true
    sudo ufw delete allow in on "$IFACE" to any port 53 proto udp 2>/dev/null || true
    sudo ufw delete allow in on "$IFACE" to any port 80,443 proto tcp 2>/dev/null || true
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --remove-service=dhcp --zone=public --permanent 2>/dev/null || true
    sudo firewall-cmd --remove-service=http --zone=public --permanent 2>/dev/null || true
    sudo firewall-cmd --remove-service=https --zone=public --permanent 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
fi

# Reset interface
echo "♻️ Resetting Wi-Fi interface '$IFACE'..."
sudo ip link set "$IFACE" down 2>/dev/null || true
sudo iw dev "$IFACE" set type managed 2>/dev/null || true
sleep 1
sudo ip link set "$IFACE" up 2>/dev/null || true
sleep 1
sudo nmcli device set "$IFACE" managed yes 2>/dev/null || true
sudo nmcli radio wifi on 2>/dev/null || true
sudo nmcli device wifi rescan 2>/dev/null || true

# Remove any lingering IP addresses
if ip addr show "$IFACE" | grep -q "192.168.50.1"; then
    echo "🧹 Cleaning leftover IP addresses..."
    sudo ip addr flush dev "$IFACE" 2>/dev/null || true
fi

# Remove routes
if ip route | grep -q "192.168.50.0/24"; then
    echo "🧹 Cleaning leftover routes..."
    sudo ip route del 192.168.50.0/24 dev "$IFACE" 2>/dev/null || true
fi

# === NETWORK RESTORATION ===
echo "🔄 Restarting NetworkManager to restore networking..."
sudo systemctl restart NetworkManager
echo "⏳ Waiting for NetworkManager to stabilize..."
sleep 5

# === DOCKER BRIDGE RESTORATION ===
if [ "$DOCKER_WAS_ACTIVE" = "active" ]; then
    echo "🐳 Restarting Docker services..."
    sudo systemctl start docker.service docker.socket 2>/dev/null || true
    
    # Wait for Docker networks to initialize
    echo "⏳ Waiting for Docker networks to initialize..."
    sleep 5
    
    # Reconnect all Docker-related connections
    if [ -n "$DOCKER_BRIDGES" ]; then
        echo "🌉 Reconnecting Docker bridges..."
        while IFS=: read -r CON_NAME BRIDGE_DEV; do
            echo "  - Attempting to reconnect $CON_NAME ($BRIDGE_DEV)"
            
            # Ensure bridge exists
            if ! ip link show "$BRIDGE_DEV" &>/dev/null; then
                echo "    ⚠️ Bridge $BRIDGE_DEV missing, recreating..."
                sudo nmcli con add type bridge ifname "$BRIDGE_DEV" con-name "$CON_NAME" 2>/dev/null || true
            fi
            
            # Activate connection
            if ! sudo nmcli con up "$CON_NAME" 2>/dev/null; then
                echo "    ⚠️ Failed to activate, deleting and recreating..."
                sudo nmcli con del "$CON_NAME" 2>/dev/null || true
                sudo nmcli con add type bridge ifname "$BRIDGE_DEV" con-name "$CON_NAME" 2>/dev/null || true
                sudo nmcli con up "$CON_NAME" 2>/dev/null || true
            fi
        done <<< "$DOCKER_BRIDGES"
    fi
fi

# Final cleanup
echo "🧹 Removing temporary configurations..."
sudo rm -f /tmp/tshella_* 2>/dev/null || true

echo "✅ Wi-Fi and services reset. Docker bridges restored."
echo "📡 Current Network Status:"
sudo nmcli device status