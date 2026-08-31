#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
source /etc/vless-config.conf
apt install -y jq > /dev/null 2>&1
read -p "Username: " USERNAME
UUID=$(cat /proc/sys/kernel/random/uuid)
jq ".inbounds[0].settings.clients += [{\"id\": \"$UUID\", \"flow\": \"\"}]" \
    /usr/local/etc/xray/config.json > /tmp/config.json
mv /tmp/config.json /usr/local/etc/xray/config.json
systemctl restart xray
ENCODED_PATH=$(echo -n "$WS_PATH" | sed 's|/|%2F|g')
LINK="vless://$UUID@$CF_IP:80?path=$ENCODED_PATH&host=$DOMAIN&type=ws&encryption=none#$USERNAME"
echo ""
echo -e "${GREEN}User Created!${NC}"
echo ""
echo -e "${YELLOW}VLESS Link:${NC}"
echo -e "${GREEN}$LINK${NC}"
echo ""
