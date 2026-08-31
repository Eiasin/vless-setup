#!/bin/bash

CONFIG="/usr/local/etc/xray/config.json"
USERS_FILE="/etc/xray-users.txt"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

source /etc/vless-config.conf 2>/dev/null
CF_IP=${CF_IP:-104.16.119.28}
DOMAIN=${DOMAIN:-vpn2.kanij.site}
WS_PATH=${WS_PATH:-/ray}

show_menu() {
    clear
    echo -e "${YELLOW}════════════════════════════════════${NC}"
    echo -e "${YELLOW}   VLESS Link Generator${NC}"
    echo -e "${YELLOW}════════════════════════════════════${NC}"
    echo "1. Create New User"
    echo "2. List All Users"
    echo "3. Generate Link for User"
    echo "4. Delete User"
    echo "5. Exit"
    echo ""
    read -p "Choose (1-5): " choice
}

create_user() {
    read -p "Enter username: " USERNAME
    UUID=$(cat /proc/sys/kernel/random/uuid)

    # Save to config
    apt install -y jq > /dev/null 2>&1
    jq ".inbounds[0].settings.clients += [{\"id\": \"$UUID\", \"flow\": \"\"}]" \
        $CONFIG > /tmp/config.json
    mv /tmp/config.json $CONFIG
    systemctl restart xray > /dev/null 2>&1

    # Save name + UUID to users file
    echo "$USERNAME:$UUID" >> $USERS_FILE

    ENCODED_PATH=$(echo -n "$WS_PATH" | sed 's|/|%2F|g')
    LINK="vless://$UUID@$CF_IP:80?path=$ENCODED_PATH&host=$DOMAIN&type=ws&encryption=none#$USERNAME"

    echo ""
    echo -e "${GREEN}✓ User Created!${NC}"
    echo ""
    echo -e "${YELLOW}Username:${NC} $USERNAME"
    echo -e "${YELLOW}UUID:${NC} $UUID"
    echo ""
    echo -e "${YELLOW}VLESS Link:${NC}"
    echo -e "${GREEN}$LINK${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

list_users() {
    echo ""
    echo -e "${YELLOW}All Users:${NC}"
    echo "────────────────────────────────────────────"
    if [ ! -f "$USERS_FILE" ] || [ ! -s "$USERS_FILE" ]; then
        echo "No users found"
    else
        nl -w3 "$USERS_FILE" | while IFS= read -r line; do
            NUM=$(echo "$line" | awk '{print $1}')
            NAME=$(echo "$line" | awk '{print $2}' | cut -d: -f1)
            UUID=$(echo "$line" | awk '{print $2}' | cut -d: -f2)
            echo "  $NUM. Name: $NAME"
            echo "     UUID: $UUID"
            echo ""
        done
    fi
    echo "────────────────────────────────────────────"
    read -p "Press Enter to continue..."
}

generate_link() {
    if [ ! -f "$USERS_FILE" ] || [ ! -s "$USERS_FILE" ]; then
        echo "No users found!"
        read -p "Press Enter to continue..."
        return
    fi

    echo ""
    echo -e "${YELLOW}Select User:${NC}"
    nl "$USERS_FILE" | while IFS= read -r line; do
        NUM=$(echo "$line" | awk '{print $1}')
        NAME=$(echo "$line" | awk '{print $2}' | cut -d: -f1)
        echo "  $NUM. $NAME"
    done
    echo ""
    read -p "Enter number: " NUM

    LINE=$(sed -n "${NUM}p" $USERS_FILE)
    USERNAME=$(echo "$LINE" | cut -d: -f1)
    UUID=$(echo "$LINE" | cut -d: -f2)

    ENCODED_PATH=$(echo -n "$WS_PATH" | sed 's|/|%2F|g')
    LINK="vless://$UUID@$CF_IP:80?path=$ENCODED_PATH&host=$DOMAIN&type=ws&encryption=none#$USERNAME"

    echo ""
    echo -e "${GREEN}VLESS Link for $USERNAME:${NC}"
    echo -e "${GREEN}$LINK${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

delete_user() {
    if [ ! -f "$USERS_FILE" ] || [ ! -s "$USERS_FILE" ]; then
        echo "No users found!"
        read -p "Press Enter to continue..."
        return
    fi

    echo ""
    echo -e "${YELLOW}Select User to Delete:${NC}"
    nl "$USERS_FILE" | while IFS= read -r line; do
        NUM=$(echo "$line" | awk '{print $1}')
        NAME=$(echo "$line" | awk '{print $2}' | cut -d: -f1)
        echo "  $NUM. $NAME"
    done
    echo ""
    read -p "Enter number: " NUM

    LINE=$(sed -n "${NUM}p" $USERS_FILE)
    USERNAME=$(echo "$LINE" | cut -d: -f1)
    UUID=$(echo "$LINE" | cut -d: -f2)

    # Remove from xray config
    apt install -y jq > /dev/null 2>&1
    jq ".inbounds[0].settings.clients |= map(select(.id != \"$UUID\"))" \
        $CONFIG > /tmp/config.json
    mv /tmp/config.json $CONFIG
    systemctl restart xray > /dev/null 2>&1

    # Remove from users file
    sed -i "${NUM}d" $USERS_FILE

    echo ""
    echo -e "${GREEN}✓ User $USERNAME deleted!${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

while true; do
    show_menu
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) generate_link ;;
        4) delete_user ;;
        5) exit 0 ;;
        *) echo -e "${RED}Invalid!${NC}" ;;
    esac
done
