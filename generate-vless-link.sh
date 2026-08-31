#!/bin/bash

CONFIG="/usr/local/etc/xray/config.json"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to generate UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# Menu
show_menu() {
    echo -e "${YELLOW}════════════════════════════════════${NC}"
    echo -e "${YELLOW}   VLESS Link Generator${NC}"
    echo -e "${YELLOW}════════════════════════════════════${NC}"
    echo "1. Create New User & Generate Link"
    echo "2. List All Users"
    echo "3. Generate Link for Existing User"
    echo "4. Delete User"
    echo "5. Exit"
    echo ""
    read -p "Choose option (1-5): " choice
}

# Create new user
create_user() {
    read -p "Enter username/email (e.g., user1@myserver): " email
    
    NEW_UUID=$(generate_uuid)
    
    # Add to config
    sudo jq ".inbounds[0].settings.clients += [{\"id\": \"$NEW_UUID\", \"flow\": \"\"}]" $CONFIG > /tmp/xray_config.json
    sudo mv /tmp/xray_config.json $CONFIG
    
    # Restart xray
    sudo systemctl restart xray
    sleep 1
    
    echo ""
    echo -e "${GREEN}✓ User Created Successfully!${NC}"
    echo ""
    echo -e "${BLUE}User Details:${NC}"
    echo -e "  Email: ${YELLOW}$email${NC}"
    echo -e "  UUID:  ${YELLOW}$NEW_UUID${NC}"
    echo ""
    
    # Generate link
    LINK="vless://$NEW_UUID@104.16.119.28:80?path=%2Fray&host=vpn2.kanij.site&type=ws&encryption=none#$email"
    
    echo -e "${BLUE}VLESS Link:${NC}"
    echo -e "${GREEN}$LINK${NC}"
    echo ""
    echo "Copy this link and paste in v2rayNG (+ → Share link)"
    echo ""
    
    # Copy to clipboard (if xclip installed)
    if command -v xclip &> /dev/null; then
        echo "$LINK" | xclip -selection clipboard
        echo -e "${GREEN}✓ Link copied to clipboard!${NC}"
    fi
    echo ""
}

# List users
list_users() {
    echo ""
    echo -e "${BLUE}All Users:${NC}"
    echo "────────────────────────────────────────────"
    sudo jq -r '.inbounds[0].settings.clients[] | "\(.id)"' $CONFIG | nl
    echo "────────────────────────────────────────────"
    echo ""
}

# Generate link for existing user
generate_link() {
    read -p "Enter email/name: " email
    read -p "Enter UUID: " uuid
    
    LINK="vless://$uuid@104.16.119.28:80?path=%2Fray&host=vpn2.kanij.site&type=ws&encryption=none#$email"
    
    echo ""
    echo -e "${BLUE}VLESS Link:${NC}"
    echo -e "${GREEN}$LINK${NC}"
    echo ""
    
    if command -v xclip &> /dev/null; then
        echo "$LINK" | xclip -selection clipboard
        echo -e "${GREEN}✓ Copied to clipboard!${NC}"
    fi
    echo ""
}

# Delete user
delete_user() {
    read -p "Enter UUID to delete: " uuid_to_delete
    
    sudo jq ".inbounds[0].settings.clients |= map(select(.id != \"$uuid_to_delete\"))" $CONFIG > /tmp/xray_config.json
    sudo mv /tmp/xray_config.json $CONFIG
    
    sudo systemctl restart xray
    sleep 1
    
    echo -e "${GREEN}✓ User deleted!${NC}"
    echo ""
}

# Main loop
while true; do
    show_menu
    
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) generate_link ;;
        4) delete_user ;;
        5) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
