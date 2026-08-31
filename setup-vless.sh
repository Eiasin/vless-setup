#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_info() { echo -e "${YELLOW}[!]${NC} $1"; }
clear
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}     VLESS + Cloudflare Auto Setup      ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
read -p "Domain (e.g., vpn2.kanij.site): " DOMAIN
read -p "Cloudflare IP (default: 104.16.119.28): " CF_IP
CF_IP=${CF_IP:-104.16.119.28}
read -p "WS Path (default: /ray): " WS_PATH
WS_PATH=${WS_PATH:-/ray}
read -p "Xray Port (default: 10000): " XRAY_PORT
XRAY_PORT=${XRAY_PORT:-10000}
UUID=$(cat /proc/sys/kernel/random/uuid)
echo ""
print_info "Domain: $DOMAIN"
print_info "CF IP: $CF_IP"
print_info "Path: $WS_PATH"
print_info "Port: $XRAY_PORT"
print_info "UUID: $UUID"
echo ""
read -p "Confirm? (y/n): " CONFIRM
[ "$CONFIRM" != "y" ] && exit 1
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
print_status "System updated"
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install > /dev/null 2>&1
print_status "Xray installed"
cat > /usr/local/etc/xray/config.json <<XRAY
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $XRAY_PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$UUID", "flow": ""}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "$WS_PATH",
        "headers": { "Host": "$DOMAIN" }
      }
    }
  }],
  "outbounds": [{"protocol": "freedom", "settings": {}}]
}
XRAY
systemctl restart xray
systemctl enable xray > /dev/null 2>&1
sleep 2
print_status "Xray started"
apt install -y nginx > /dev/null 2>&1
rm -f /etc/nginx/sites-enabled/*
cat > /etc/nginx/sites-enabled/vless <<NGINX
server {
    listen 80;
    server_name $DOMAIN;
    location $WS_PATH {
        proxy_pass http://127.0.0.1:$XRAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_buffering off;
    }
}
NGINX
nginx -t > /dev/null 2>&1
systemctl restart nginx
systemctl enable nginx > /dev/null 2>&1
print_status "Nginx started"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
print_status "Firewall configured"
cat > /etc/vless-config.conf <<CONF
DOMAIN=$DOMAIN
CF_IP=$CF_IP
WS_PATH=$WS_PATH
XRAY_PORT=$XRAY_PORT
CONF
ENCODED_PATH=$(echo -n "$WS_PATH" | sed 's|/|%2F|g')
VLESS_LINK="vless://$UUID@$CF_IP:80?path=$ENCODED_PATH&host=$DOMAIN&type=ws&encryption=none#$DOMAIN"
clear
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}        Setup Complete!                 ${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}VLESS Link:${NC}"
echo -e "${GREEN}$VLESS_LINK${NC}"
echo ""
echo -e "${YELLOW}Cloudflare:${NC}"
echo "  DNS → A Record → $DOMAIN → Proxied (Orange)"
echo ""
echo -e "${YELLOW}Add more users:${NC}"
echo "  bash /root/vless-setup/add-vless-user.sh"
