Secure Access Point Setup with Captive Portal
Overview

This project transforms your Linux laptop into a secure Wi-Fi access point with a captive portal that displays active services. It's ideal for:

    Security researchers demonstrating vulnerabilities

    IT professionals creating isolated testing environments

    Developers testing mobile applications

    Educators running workshops with device connectivity

    Field technicians providing on-site diagnostics

Key Features

    Enterprise-grade Security: WPA3 encryption with automatic fallback to WPA2

    Captive Portal: Auto-redirects to service directory

    Service Discovery: Shows all open ports on the host machine

    Docker Integration: Preserves and restores container networks

    Easy Management: Simple start/stop commands

Requirements

    Linux laptop with wireless card supporting AP mode

    Root/sudo access

    Python 3

    NetworkManager

    dnsmasq

Installation Guide
Ubuntu/Debian
bash

# Install dependencies
sudo apt update
sudo apt install -y network-manager dnsmasq python3 python3-pip

# Clone repository
git clone https://github.com/yourusername/secure-access-point.git
cd secure-access-point

# Make scripts executable
chmod +x setup_secure_ap.sh stop_ap.sh generate_ports.sh

Fedora/CentOS
bash

# Install dependencies
sudo dnf install -y NetworkManager dnsmasq python3 python3-pip

# Clone repository
git clone https://github.com/yourusername/secure-access-point.git
cd secure-access-point

# Make scripts executable
chmod +x setup_secure_ap.sh stop_ap.sh generate_ports.sh

Configuration

Edit setup_secure_ap.sh with your preferred settings:
bash

# === CONFIG ===
IFACE="wlo1"                  # Your wireless interface
SSID="TshellaTechnologies"     # Network name
PASSPHRASE="StrongPassword123" # Min 8 characters
IP_ADDR="192.168.50.1/24"     # Access Point IP
WEB_DIR="$(pwd)"              # Web portal directory

Usage
Start Access Point
bash

sudo ./setup_secure_ap.sh

The portal will be available at: http://192.168.50.1:8000
Stop Access Point
bash

sudo ./stop_ap.sh

Check Status
bash

make status  # Shows active connections and bridge status

Practical Applications
1. Security Demonstrations

    Create a "honeypot" network to demonstrate attack vectors

    Show live port scanning results to educate users

2. Development & Testing

    Test mobile apps on isolated networks

    Simulate captive portal behavior for hotel/airport WiFi

    Debug network services in controlled environments

3. Field Diagnostics

    Provide technicians with device status portal

    Display QR codes for service documentation

    Offer temporary access to equipment manuals

4. Education & Workshops

    Run programming workshops without internet dependency

    Create lab environments with custom web resources

    Distribute materials via local web server

5. IoT Prototyping

    Connect IoT devices to a controlled network

    Monitor device communication patterns

    Test firmware updates locally

Customization Options

    Branded Portal: Edit index.html to match your organization's branding

    Service Information: Modify generate_ports.sh to display custom service info

    Advanced DNS: Edit DNSMasq config in setup_secure_ap.sh for:

        Domain blackholing

        Custom DNS records

        Ad blocking

    Authentication: Add password protection to the Python web server

    Port Forwarding: Extend scripts to expose container services

Troubleshooting
Common Issues & Solutions
Issue	Solution
"Weak Security" warning	Ensure your password is 12+ characters with special characters
dnsmasq port 53 conflict	Run sudo systemctl stop systemd-resolved before starting
Docker bridges not restoring	Run sudo systemctl restart docker after stopping AP
Can't connect to AP	Check wireless card supports AP mode with iw list
"Activation failed" errors	Try WPA2-only mode by setting SECURITY_MODE="wpa2"
Diagnostic Commands
bash

# Check wireless capabilities
iw list | grep "Supported interface modes" -A 10

# View NetworkManager logs
journalctl -u NetworkManager -b

# Check dnsmasq operation
sudo systemctl status dnsmasq

# Verify port status
ss -tuln

Security Considerations

    Always use strong passwords (12+ characters, mixed types)

    Change default IP range if on corporate networks

    Regularly update dependencies: sudo apt upgrade

    Disable when not in use

    Review DNSMasq configuration for unintended forwards

License

This project is licensed under the MIT License - see the LICENSE file for details.
Contribution

Contributions are welcome! Please submit PRs for:

    Improved platform compatibility

    Additional security features

    Enhanced portal functionality

    Better Docker/container integration

