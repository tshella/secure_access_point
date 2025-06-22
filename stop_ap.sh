#!/bin/bash
set -e

# === CONFIG ===
IFACE="wlo1"
CON_NAME="hostap"
DNSMASQ_PID_FILE="/tmp/tshella_dnsmasq.pid"
PYTHON_PID_FILE="/tmp/tshella_python_server.pid"

echo "🛑 Stopping Access Point..."

# Save Docker bridge status
DOCKER_WAS_ACTIVE=$(systemctl is-active docker.service 2>/dev/null || echo "inactive")
DOCKER_BRIDGES=$(nmcli -t -f NAME,DEVICE,TYPE con show | grep ':bridge$' | cut -d: -f1,2)

# Deactivate and remove NetworkManager AP
echo "🔌 Shutting down access point connection..."
nmcli con down "$CON_NAME" 2>/dev/null || true
nmcli con delete "$CON_NAME" 2>/dev/null || true

# Stop dnsmasq if running
if [ -f "$DNSMASQ_PID_FILE" ]; then
    PID=$(cat "$DNSMASQ_PID_FILE")
    echo "❌ Stopping dnsmasq (PID $PID)..."
    sudo kill "$PID" 2>/dev/null || true
    rm -f "$DNSMASQ_PID_FILE"
else
    sudo killall dnsmasq 2>/dev/null || true
fi

# Stop Python web server
if [ -f "$PYTHON_PID_FILE" ]; then
    PID=$(cat "$PYTHON_PID_FILE")
    echo "❌ Stopping web server (PID $PID)..."
    kill "$PID" 2>/dev/null || true
    rm -f "$PYTHON_PID_FILE"
else
    pkill -f "python3 -m http.server" 2>/dev/null || true
fi

# Restart systemd-resolved if we stopped it
if [ -n "$SYSTEMD_RESOLVED_STOPPED" ]; then
    echo "🔒 Restarting systemd-resolved..."
    sudo systemctl start systemd-resolved
fi

# Reset interface
echo "♻️ Resetting Wi-Fi interface '$IFACE'..."
sudo ip link set "$IFACE" down
sleep 1
sudo ip link set "$IFACE" up
sleep 1
nmcli device set "$IFACE" managed yes
nmcli radio wifi on
nmcli device wifi rescan 2>/dev/null || true

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
                sudo nmcli con add type bridge ifname "$BRIDGE_DEV" con-name "$CON_NAME" &>/dev/null || true
            fi
            
            # Activate connection
            if ! nmcli con up "$CON_NAME" 2>/dev/null; then
                echo "    ⚠️ Failed to activate, deleting and recreating..."
                nmcli con del "$CON_NAME" 2>/dev/null || true
                sudo nmcli con add type bridge ifname "$BRIDGE_DEV" con-name "$CON_NAME" &>/dev/null || true
                nmcli con up "$CON_NAME" 2>/dev/null || true
            fi
            
            # Verify connection
            CON_STATE=$(nmcli -t -f NAME,STATE con show "$CON_NAME" 2>/dev/null | cut -d: -f2)
            if [[ "$CON_STATE" == "activated" ]]; then
                echo "    ✅ $CON_NAME reconnected successfully"
            else
                echo "    ⚠️ $CON_NAME still disconnected"
            fi
        done <<< "$DOCKER_BRIDGES"
    fi
fi

# Final cleanup
echo "🧹 Removing temporary configurations..."
rm -f /tmp/tshella_* 2>/dev/null || true

echo "✅ Wi-Fi and services reset. Docker bridges restored."
echo "📡 Current Network Status:"
nmcli device status