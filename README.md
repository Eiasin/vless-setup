# VLESS + Cloudflare Auto Setup

## নতুন VPS Setup:
bash <(curl -Ls https://raw.githubusercontent.com/Eiasin/vless-setup/main/setup-vless.sh)

## নতুন User Add:
bash /root/vless-setup/add-vless-user.sh

## User Manager:
bash /root/vless-setup/generate-vless-link.sh

## Client Settings (v2rayNG):
- Address: Cloudflare IP (104.16.119.28)
- Port: 80
- Network: ws
- Path: /ray
- Host: তোমার domain
- TLS: OFF

## মনে রাখবে:
- GitHub Token কখনো share করবে না
- Repository Private রাখো
- Cloudflare DNS Proxied (Orange) রাখবে
