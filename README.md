# Secure Access Point with Captive Portal

## ✨ Overview

This project transforms your **Linux laptop** into a secure **Wi-Fi Access Point** with a built-in **captive portal** that dynamically lists all open services. Ideal for:

* 🔐 **Security researchers** demonstrating vulnerabilities
* 📈 **IT professionals** building isolated testing zones
* 📄 **Developers** testing mobile apps locally
* 🎓 **Educators** running offline workshops
* 🏠 **Field technicians** for on-site diagnostics

---

## 🔹 Key Features

* **Enterprise-Grade Security**: WPA3-SAE with fallback to WPA2-PSK (AES)
* **Captive Portal**: Redirects all clients to local web interface
* **Port Scanner**: Lists all open ports and active services
* **Docker-Aware**: Preserves and restores bridge interfaces
* **One-Line Management**: `make up`, `make down`, `make status`

---

## 📄 Requirements

* Linux laptop with Wi-Fi card supporting AP mode
* `sudo` access
* `NetworkManager`, `dnsmasq`, `python3`

---

## 🚀 Installation Guide

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y network-manager dnsmasq python3 python3-pip

git clone https://github.com/yourusername/secure-access-point.git
cd secure-access-point
chmod +x setup_secure_ap.sh stop_ap.sh generate_ports.sh
```

### Fedora / CentOS

```bash
sudo dnf install -y NetworkManager dnsmasq python3 python3-pip

git clone https://github.com/yourusername/secure-access-point.git
cd secure-access-point
chmod +x setup_secure_ap.sh stop_ap.sh generate_ports.sh
```

---

## 🔧 Configuration

Edit `setup_secure_ap.sh`:

```bash
IFACE="wlo1"                     # Wi-Fi interface name
SSID="TshellaTechnologies"      # Hotspot SSID
PASSPHRASE="StrongPassword123"  # WPA2/WPA3 passphrase
IP_ADDR="192.168.50.1/24"       # Static IP
WEB_DIR="$(pwd)"                # Web files directory
```

---

## 🌐 Usage

### Start Access Point

```bash
sudo ./setup_secure_ap.sh
```

Then browse to: [http://192.168.50.1:8000](http://192.168.50.1:8000)

### Stop Access Point

```bash
sudo ./stop_ap.sh
```

### Check Status

```bash
make status
```

---

## 🔹 Practical Applications

### 1. Security Demos

* Create honeypot APs
* Show live vulnerability scanning

### 2. Dev/Test Environments

* Simulate captive portals (e.g. airports, hotels)
* Offline testing of mobile/web apps

### 3. Field Diagnostics

* Host manuals/firmware for technicians
* Provide diagnostics without internet

### 4. Education & Workshops

* Distribute resources offline
* Teach IoT/programming/networking

### 5. IoT Prototyping

* Safely test devices before WAN exposure
* Analyze device traffic in isolation

---

## 🔹 Customization Options

| Feature             | How to Customize                                    |
| ------------------- | --------------------------------------------------- |
| **Branding**        | Edit `index.html` for logo, colors, content         |
| **Ports**           | Modify `generate_ports.sh` to filter or enrich data |
| **DNS**             | Edit `dnsmasq` config block in `setup_secure_ap.sh` |
| **Auth**            | Add HTTP Basic Auth to Python web server            |
| **Port Forwarding** | Expose containers/services via `iptables`           |

---

## ⚠️ Troubleshooting

| Issue                | Solution                                            |
| -------------------- | --------------------------------------------------- |
| "Weak Security"      | Use strong password (12+ characters with symbols)   |
| Port 53 conflict     | `sudo systemctl stop systemd-resolved` before start |
| Docker bridges lost  | Run `sudo systemctl restart docker` after stop      |
| AP fails to activate | Use WPA2 fallback by forcing `SECURITY_MODE=wpa2`   |
| Can't detect card    | Check `iw list` for AP support                      |

### Diagnostic Commands

```bash
# View supported AP modes
iw list | grep -A10 "Supported interface modes"

# System logs for NetworkManager
journalctl -u NetworkManager -b

# View open ports
ss -tuln

# Check dnsmasq status
sudo systemctl status dnsmasq
```

---

## 🔒 Security Best Practices

* Use WPA3 or strong WPA2 passwords
* Regularly rotate credentials
* Use unique subnets (avoid 192.168.0.0/24 on corp LANs)
* Disable AP when idle
* Review DNS configurations regularly

---

## 📅 License

MIT License. See [LICENSE](LICENSE) file.

---

## 📚 Contributing

Pull Requests welcome for:

* Cross-platform compatibility
* Additional features (SSL, Auth)
* Performance improvements
* Docker or Flatpak packaging

> Designed by Manaka Anthony Raphasha with ❤️ for mobility, privacy, and rapid deployments.
