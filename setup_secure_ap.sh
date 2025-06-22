#!/bin/bash
set -e

# === CONFIG ===
IFACE="wlo1"
CON_NAME="hostap"
SSID="TshellaTechnologies"
PASSPHRASE="tshellaIT#Oct24"
IP_ADDR="192.168.50.1/24"
DNSMASQ_PID_FILE="/tmp/tshella_dnsmasq.pid"
DNSMASQ_CONF="/tmp/tshella_dnsmasq.conf"
PYTHON_PID_FILE="/tmp/tshella_python_server.pid"
WEB_DIR="$(pwd)"
DHCP_RANGE="192.168.50.100,192.168.50.200,12h"

# === SECURITY ENHANCEMENTS ===
detect_security_mode() {
    if iw list | grep -q "SAE"; then
        echo "🔒 Hardware supports WPA3, using enhanced security"
        SECURITY_MODE="wpa3"
    else
        echo "⚠️ Hardware doesn't support WPA3, using WPA2-AES"
        SECURITY_MODE="wpa2"
    fi
}

configure_security() {
    case $SECURITY_MODE in
        wpa3)
            sudo nmcli con modify "$CON_NAME" wifi-sec.key-mgmt sae
            sudo nmcli con modify "$CON_NAME" wifi-sec.pmf required
            ;;
        wpa2)
            sudo nmcli con modify "$CON_NAME" wifi-sec.key-mgmt wpa-psk
            sudo nmcli con modify "$CON_NAME" wifi-sec.proto rsn
            sudo nmcli con modify "$CON_NAME" wifi-sec.group ccmp
            sudo nmcli con modify "$CON_NAME" wifi-sec.pairwise ccmp
            sudo nmcli con modify "$CON_NAME" wifi-sec.pmf optional
            ;;
    esac
}

# === FULL RESET ===
echo "🔄 Resetting Wi-Fi interface '$IFACE'..."

# Stop interfering services
sudo systemctl stop docker.service docker.socket 2>/dev/null || true

# Stop systemd-resolved if it's using port 53
if ss -tuln | grep -q ':53 '; then
    echo "🔒 Stopping systemd-resolved to free port 53..."
    sudo systemctl stop systemd-resolved
    SYSTEMD_RESOLVED_STOPPED=1
fi

# Get interface state
IFACE_STATE=$(nmcli -t -f DEVICE,STATE device | grep "^$IFACE:" | cut -d: -f2 || echo "unknown")

# Disconnect only if connected
if [[ "$IFACE_STATE" == "connected" ]]; then
    echo "🔌 Disconnecting '$IFACE' from current network..."
    sudo nmcli device disconnect "$IFACE" 2>/dev/null || true
    sleep 1
fi

# Reset interface management
echo "⚙️ Setting '$IFACE' to managed mode..."
sudo nmcli device set "$IFACE" managed yes 2>/dev/null || true

# Reset network interface
echo "🔁 Cycling '$IFACE' interface..."
sudo ip link set "$IFACE" down
sleep 2
sudo ip link set "$IFACE" up
sleep 2

# Clean old connections
echo "🧹 Cleaning up previous configurations..."
nmcli con delete "$CON_NAME" 2>/dev/null || true
sudo killall dnsmasq 2>/dev/null || true
pkill -f "python3 -m http.server" 2>/dev/null || true
rm -f "$DNSMASQ_PID_FILE" "$PYTHON_PID_FILE"

# === CREATE ACCESS POINT ===
echo "🔧 Creating Access Point '$SSID'..."

# Create hotspot profile
sudo nmcli con add type wifi ifname "$IFACE" con-name "$CON_NAME" autoconnect no ssid "$SSID"
sudo nmcli con modify "$CON_NAME" 802-11-wireless.mode ap
sudo nmcli con modify "$CON_NAME" 802-11-wireless.band bg
sudo nmcli con modify "$CON_NAME" ipv4.addresses "$IP_ADDR"
sudo nmcli con modify "$CON_NAME" ipv4.method manual

# Configure security
detect_security_mode
configure_security

sudo nmcli con modify "$CON_NAME" wifi-sec.psk "$PASSPHRASE"

# === ACTIVATE ACCESS POINT WITH RETRY ===
echo "📶 Activating access point..."
MAX_RETRIES=3
ACTIVATED=false

for ((i=1; i<=$MAX_RETRIES; i++)); do
    echo "  Attempt $i of $MAX_RETRIES..."
    if sudo nmcli con up "$CON_NAME"; then
        ACTIVATED=true
        break
    fi
    
    # Reset interface before retry
    echo "  Resetting interface..."
    sudo ip link set "$IFACE" down
    sleep 1
    sudo ip link set "$IFACE" up
    sleep 1
done

if ! $ACTIVATED; then
    if [ "$SECURITY_MODE" == "wpa3" ]; then
        echo "⚠️ Falling back to WPA2 due to activation issues"
        SECURITY_MODE="wpa2"
        configure_security
        sudo nmcli con up "$CON_NAME" || {
            echo "❌ Critical error: Failed to activate access point"
            exit 1
        }
    else
        echo "❌ Critical error: Failed to activate access point"
        exit 1
    fi
fi

# Verify IP assignment
echo "🔍 Verifying IP assignment..."
if ! ip addr show "$IFACE" | grep -q "192.168.50.1"; then
    echo "❌ IP not assigned! Manually setting..."
    sudo ip addr add 192.168.50.1/24 dev "$IFACE"
fi

# === DNSMASQ FOR DHCP AND REDIRECT ===
echo "📡 Starting dnsmasq..."

# Create DHCP configuration
cat <<EOF | sudo tee "$DNSMASQ_CONF" >/dev/null
interface=$IFACE
bind-interfaces
except-interface=lo
listen-address=192.168.50.1
dhcp-range=$DHCP_RANGE
dhcp-option=option:router,192.168.50.1
dhcp-option=option:dns-server,192.168.50.1
dhcp-leasefile=/tmp/tshella_dnsmasq.leases
address=/#/192.168.50.1
no-resolv
server=8.8.8.8
server=8.8.4.4
EOF

# Start dnsmasq with lease file
sudo dnsmasq --conf-file="$DNSMASQ_CONF" --pid-file="$DNSMASQ_PID_FILE" --leasefile-ro

# Verify dnsmasq
sleep 2
if ! pgrep -f "dnsmasq.*$DNSMASQ_CONF" >/dev/null; then
    echo "❌ dnsmasq failed to start! Check port conflicts"
    exit 1
fi

# === WEB SERVER ===
echo "🌐 Starting web server at http://192.168.50.1:8000..."
cd "$WEB_DIR"
nohup python3 -m http.server 8000 --bind 192.168.50.1 &>/dev/null &
echo $! > "$PYTHON_PID_FILE"

# Generate ports list
echo "📋 Generating ports list..."
./generate_ports.sh

echo "✅ Access Point '$SSID' is live!"
echo "🔐 Security Mode: $SECURITY_MODE"
echo "🌐 Web Portal: http://192.168.50.1:8000"
echo "🔌 DHCP Range: $DHCP_RANGE"