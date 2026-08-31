#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_info()   { echo -e "${YELLOW}[!]${NC} $1"; }
print_error()  { echo -e "${RED}[✗]${NC} $1"; }

clear
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}   VLESS + Cloudflare + SSL Auto Setup  ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# ─── User Input ───────────────────────────────────────────────
read -rp "Domain (e.g., vpn2.kanij.site): " DOMAIN
while [[ -z "$DOMAIN" ]]; do
    print_error "Domain cannot be empty!"
    read -rp "Domain (e.g., vpn2.kanij.site): " DOMAIN
done

read -rp "Cloudflare Proxy IP (default: 104.16.119.28): " CF_IP
CF_IP=${CF_IP:-104.16.119.28}

read -rp "WS Path (default: /ray): " WS_PATH
WS_PATH=${WS_PATH:-/ray}

read -rp "Xray Port (default: 10000): " XRAY_PORT
XRAY_PORT=${XRAY_PORT:-10000}

read -rp "Email for SSL certificate: " SSL_EMAIL
while [[ -z "$SSL_EMAIL" ]]; do
    print_error "Email cannot be empty!"
    read -rp "Email for SSL certificate: " SSL_EMAIL
done

UUID=$(cat /proc/sys/kernel/random/uuid)

echo ""
print_info "Domain:      $DOMAIN"
print_info "CF IP:       $CF_IP"
print_info "Path:        $WS_PATH"
print_info "Xray Port:   $XRAY_PORT"
print_info "SSL Email:   $SSL_EMAIL"
print_info "UUID:        $UUID"
echo ""

read -rp "Confirm setup? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && { print_error "Cancelled!"; exit 1; }

echo ""

# ─── Step 1: System Update ────────────────────────────────────
print_info "Updating system..."
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install -y curl wget git jq ufw > /dev/null 2>&1
print_status "System updated"

# ─── Step 2: Install Xray ─────────────────────────────────────
print_info "Installing Xray..."
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install > /dev/null 2>&1
print_status "Xray installed"

# ─── Step 3: Xray Config ──────────────────────────────────────
print_info "Configuring Xray..."
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $XRAY_PORT,
    "protocol": "vless",
    "settings": {
      "clients": [
        {"id": "$UUID", "flow": ""}
      ],
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
EOF

systemctl enable xray > /dev/null 2>&1
systemctl restart xray
sleep 2

if systemctl is-active --quiet xray; then
    print_status "Xray running on port $XRAY_PORT"
else
    print_error "Xray failed to start!"
    exit 1
fi

# ─── Step 4: Install Nginx ────────────────────────────────────
print_info "Installing Nginx..."
apt install -y nginx > /dev/null 2>&1
systemctl enable nginx > /dev/null 2>&1
rm -f /etc/nginx/sites-enabled/*
print_status "Nginx installed"

# ─── Step 5: Nginx HTTP (for certbot) ────────────────────────
print_info "Setting up temporary HTTP config..."
cat > /etc/nginx/sites-enabled/vless <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location $WS_PATH {
        proxy_pass http://127.0.0.1:$XRAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF

nginx -t > /dev/null 2>&1
systemctl restart nginx
print_status "Nginx HTTP ready"

# ─── Step 6: SSL Certificate (Let's Encrypt) ──────────────────
print_info "Getting SSL certificate from Let's Encrypt..."
print_info "NOTE: Make sure $DOMAIN points to this server IP in Cloudflare DNS (temporarily set to DNS Only / Grey Cloud)"
echo ""
read -rp "Is DNS set to Grey Cloud (DNS Only) in Cloudflare? (y/n): " DNS_READY

if [[ "$DNS_READY" == "y" ]]; then
    apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
    
    certbot --nginx -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect
    
    if [[ $? -eq 0 ]]; then
        print_status "SSL certificate obtained!"
        SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    else
        print_error "SSL failed! Using HTTP only..."
        SSL_CERT=""
        SSL_KEY=""
    fi
else
    print_info "Skipping SSL for now. You can add it later."
    SSL_CERT=""
    SSL_KEY=""
fi

# ─── Step 7: Nginx SSL Config ─────────────────────────────────
print_info "Configuring Nginx..."

if [[ -n "$SSL_CERT" ]]; then
    cat > /etc/nginx/sites-enabled/vless <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location $WS_PATH {
        proxy_pass http://127.0.0.1:$XRAY_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF
    CLIENT_PORT=443
    CLIENT_TLS="tls"
    print_status "Nginx SSL (443) configured"
else
    CLIENT_PORT=80
    CLIENT_TLS="none"
    print_status "Nginx HTTP (80) configured"
fi

nginx -t > /dev/null 2>&1
systemctl restart nginx

# ─── Step 8: Firewall ─────────────────────────────────────────
print_info "Configuring firewall..."
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
print_status "Firewall configured"

# ─── Step 9: Save Config ──────────────────────────────────────
cat > /etc/vless-config.conf <<EOF
DOMAIN=$DOMAIN
CF_IP=$CF_IP
WS_PATH=$WS_PATH
XRAY_PORT=$XRAY_PORT
CLIENT_PORT=$CLIENT_PORT
CLIENT_TLS=$CLIENT_TLS
EOF

# ─── Step 10: Generate Link ───────────────────────────────────
ENCODED_PATH=$(echo -n "$WS_PATH" | sed 's|/|%2F|g')

if [[ "$CLIENT_TLS" == "tls" ]]; then
    VLESS_LINK="vless://$UUID@$CF_IP:443?path=$ENCODED_PATH&host=$DOMAIN&type=ws&security=tls&sni=$DOMAIN&encryption=none#$DOMAIN"
else
    VLESS_LINK="vless://$UUID@$CF_IP:80?path=$ENCODED_PATH&host=$DOMAIN&type=ws&encryption=none#$DOMAIN"
fi

# ─── Done ─────────────────────────────────────────────────────
clear
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}        Setup Complete! ✓               ${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Server Info:${NC}"
echo "  Domain:    $DOMAIN"
echo "  Port:      $CLIENT_PORT"
echo "  TLS:       $CLIENT_TLS"
echo "  Path:      $WS_PATH"
echo "  UUID:      $UUID"
echo ""
echo -e "${YELLOW}VLESS Link:${NC}"
echo -e "${GREEN}$VLESS_LINK${NC}"
echo ""

if [[ "$CLIENT_TLS" == "tls" ]]; then
    echo -e "${YELLOW}Cloudflare (SSL করা হয়েছে):${NC}"
    echo "  1. DNS → $DOMAIN → Orange Cloud (Proxied) করো"
    echo "  2. SSL/TLS → Full করো"
    echo ""
    echo -e "${GREEN}Client Settings:${NC}"
    echo "  Address: $CF_IP"
    echo "  Port: 443"
    echo "  TLS: ON"
    echo "  SNI: $DOMAIN"
else
    echo -e "${YELLOW}Cloudflare:${NC}"
    echo "  DNS → $DOMAIN → Orange Cloud (Proxied) করো"
    echo "  SSL/TLS → Flexible করো"
fi

echo ""
echo -e "${YELLOW}Add more users:${NC}"
echo "  bash /root/vless-setup/add-vless-user.sh"
echo ""
