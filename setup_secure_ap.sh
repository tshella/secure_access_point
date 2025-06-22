#!/bin/bash
set -e

# === CONFIG ===
IFACE="wlo1"
CON_NAME="hostap"
SSID="TshellaTechnologies"
PASSPHRASE="tshellaIT#Oct24"
IP_ADDR="192.168.50.1"
SUBNET="192.168.50.0/24"
DNSMASQ_PID_FILE="/tmp/tshella_dnsmasq.pid"
DNSMASQ_CONF="/tmp/tshella_dnsmasq.conf"
DNSMASQ_LOG="/tmp/tshella_dnsmasq.log"
PYTHON_PID_FILE="/tmp/tshella_python_server.pid"
WEB_DIR="$(pwd)"
DHCP_RANGE="192.168.50.100,192.168.50.200,12h"
LEASE_TIME="12h"
PORTAL_PORT="8000"

# === SECURITY ENHANCEMENTS ===
detect_security_mode() {
    echo "⚠️ Using WPA2-AES for maximum compatibility"
    SECURITY_MODE="wpa2"
}

configure_security() {
    case $SECURITY_MODE in
        wpa2)
            sudo nmcli con modify "$CON_NAME" wifi-sec.key-mgmt wpa-psk
            sudo nmcli con modify "$CON_NAME" wifi-sec.proto rsn
            sudo nmcli con modify "$CON_NAME" wifi-sec.group ccmp
            sudo nmcli con modify "$CON_NAME" wifi-sec.pairwise ccmp
            sudo nmcli con modify "$CON_NAME" wifi-sec.pmf optional
            sudo nmcli con modify "$CON_NAME" 802-11-wireless-security.auth-alg open
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
sudo iw dev "$IFACE" set type managed
sleep 2
sudo ip link set "$IFACE" up
sleep 2

# Clean old connections
echo "🧹 Cleaning up previous configurations..."
sudo nmcli con delete "$CON_NAME" 2>/dev/null || true
sudo killall dnsmasq 2>/dev/null || true
sudo pkill -f "python3 -m http.server" 2>/dev/null || true
sudo rm -f "$DNSMASQ_PID_FILE" "$PYTHON_PID_FILE" "$DNSMASQ_LOG" /tmp/tshella_dnsmasq.leases

# === CREATE ACCESS POINT ===
echo "🔧 Creating Access Point '$SSID'..."

# Create hotspot profile
sudo nmcli con add type wifi ifname "$IFACE" con-name "$CON_NAME" autoconnect no ssid "$SSID"
sudo nmcli con modify "$CON_NAME" 802-11-wireless.mode ap
sudo nmcli con modify "$CON_NAME" 802-11-wireless.band bg
sudo nmcli con modify "$CON_NAME" ipv4.addresses "$IP_ADDR/24"
sudo nmcli con modify "$CON_NAME" ipv4.method manual
sudo nmcli con modify "$CON_NAME" ipv4.gateway "$IP_ADDR"
sudo nmcli con modify "$CON_NAME" ipv4.dns "$IP_ADDR"

# Configure security
detect_security_mode
configure_security

sudo nmcli con modify "$CON_NAME" wifi-sec.psk "$PASSPHRASE"

# === ACTIVATE ACCESS POINT ===
echo "📶 Activating access point..."
if ! sudo nmcli con up "$CON_NAME"; then
    echo "⚠️ Activation failed, retrying with interface reset..."
    sudo ip link set "$IFACE" down
    sleep 1
    sudo ip link set "$IFACE" up
    sleep 1
    sudo nmcli con up "$CON_NAME" || {
        echo "❌ Critical error: Failed to activate access point"
        exit 1
    }
fi

# Verify IP assignment
echo "🔍 Verifying IP assignment..."
if ! ip addr show "$IFACE" | grep -q "$IP_ADDR"; then
    echo "❌ IP not assigned! Manually setting..."
    sudo ip addr add "$IP_ADDR/24" dev "$IFACE"
    sudo ip route add "$SUBNET" dev "$IFACE" proto kernel scope link src "$IP_ADDR"
fi

# Allow DHCP through firewall
echo "🔥 Configuring firewall for DHCP and captive portal..."
sudo iptables -F
sudo iptables -t nat -F
if command -v ufw &> /dev/null; then
    sudo ufw allow in on "$IFACE" to any port 67,68 proto udp 2>/dev/null || true
    sudo ufw allow in on "$IFACE" to any port 53 proto udp 2>/dev/null || true
    sudo ufw allow in on "$IFACE" to any port 80,443 proto tcp 2>/dev/null || true
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --add-service=dhcp --zone=public --permanent 2>/dev/null || true
    sudo firewall-cmd --add-service=http --zone=public --permanent 2>/dev/null || true
    sudo firewall-cmd --add-service=https --zone=public --permanent 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
fi

# === ENHANCED DHCP SERVER CONFIGURATION ===
echo "📡 Configuring robust DHCP server..."

# Create DHCP configuration
cat <<EOF | sudo tee "$DNSMASQ_CONF" >/dev/null
# Interface configuration
interface=$IFACE
bind-interfaces
except-interface=lo

# DHCP configuration
dhcp-range=$DHCP_RANGE
dhcp-option=option:router,$IP_ADDR
dhcp-option=option:dns-server,$IP_ADDR
dhcp-lease-max=50
dhcp-authoritative
dhcp-leasefile=/tmp/tshella_dnsmasq.leases

# Logging
log-dhcp
log-queries
log-facility=$DNSMASQ_LOG

# Captive portal DNS redirection
address=/#/$IP_ADDR
address=/captive.apple.com/$IP_ADDR
address=/connectivity-check.ubuntu.com/$IP_ADDR
address=/clients3.google.com/$IP_ADDR
address=/msftconnecttest.com/$IP_ADDR

# Performance optimizations
dhcp-rapid-commit
no-ping

# DNS configuration
no-resolv
server=8.8.8.8
server=8.8.4.4
cache-size=1000
EOF

# Start dnsmasq with enhanced settings
echo "🚀 Starting dnsmasq DHCP server..."
sudo dnsmasq --conf-file="$DNSMASQ_CONF" --pid-file="$DNSMASQ_PID_FILE" --leasefile-ro

# Verify dnsmasq
sleep 2
if ! pgrep -f "dnsmasq.*$DNSMASQ_CONF" >/dev/null; then
    echo "❌ dnsmasq failed to start! Attempting alternative port..."
    sudo dnsmasq --port=5353 --conf-file="$DNSMASQ_CONF" --pid-file="$DNSMASQ_PID_FILE" --leasefile-ro
fi

# === CAPTIVE PORTAL REDIRECTION ===
echo "🎯 Setting up captive portal redirection..."
sudo iptables -t nat -A PREROUTING -i $IFACE -p tcp --dport 80 -j DNAT --to-destination $IP_ADDR:$PORTAL_PORT
sudo iptables -t nat -A PREROUTING -i $IFACE -p tcp --dport 443 -j DNAT --to-destination $IP_ADDR:$PORTAL_PORT
sudo iptables -t nat -A POSTROUTING -j MASQUERADE

# === WEB SERVER ===
echo "🌐 Starting web server at http://${IP_ADDR}:${PORTAL_PORT}..."
cd "$WEB_DIR"
nohup python3 -m http.server $PORTAL_PORT --bind "$IP_ADDR" &>/dev/null &
echo $! > "$PYTHON_PID_FILE"

# Generate ports list
echo "📋 Generating ports list..."
./generate_ports.sh

# DHCP verification
echo "🔍 Running DHCP server diagnostics..."
echo "1. Checking DHCP process:"
pgrep -a dnsmasq || echo "No dnsmasq process found"

echo "2. Checking DHCP port listeners:"
sudo netstat -ulnp | grep ':67\|:68' || echo "No DHCP ports listening"

echo "3. Checking firewall rules:"
if command -v ufw &> /dev/null; then
    sudo ufw status verbose | grep "$IFACE"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --list-all
else
    sudo iptables -L -v -n
fi

echo "4. Interface status:"
ip addr show "$IFACE"

echo "5. DHCP lease file:"
sudo ls -l /tmp/tshella_dnsmasq.leases 2>/dev/null || echo "No lease file found"

echo "✅ Access Point '$SSID' is live!"
echo "🔐 Security Mode: $SECURITY_MODE"
echo "🌐 Web Portal: http://${IP_ADDR}:${PORTAL_PORT}"
echo "🔌 DHCP Range: $DHCP_RANGE"
echo "🎯 Captive portal enabled for Apple/Android/Windows devices"