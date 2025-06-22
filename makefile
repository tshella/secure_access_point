.PHONY: up down restart status clean

up:
	@echo "🚀 Starting Access Point..."
	@./setup_secure_ap.sh

down:
	@echo "🛑 Stopping Access Point..."
	@./stop_ap.sh

restart: down up

status:
	@echo "📡 Network Status:"
	@nmcli device status

clean:
	@echo "🧽 Cleaning temporary config files..."
	@rm -f /tmp/tshella_*.pid /tmp/tshella_*.conf ports.json
