# VLESS + Cloudflare Auto Setup

## নতুন VPS Setup:
bash <(curl -Ls https://raw.githubusercontent.com/Eiasin/vless-setup/main/setup-vless.sh)

## নতুন User Add:
bash /root/vless-setup/generate-vless-link.sh

## User Manager:
bash /root/vless-setup/generate-vless-link.sh

## Client Settings (v2rayNG):
- Address: Cloudflare IP (104.16.119.28)
- Port: 80
- Network: ws
- Path: /ray
- Host: domain
- TLS: OFF

## সমস্যা সমাধান:

### 1. Xray চলছে না:
sudo systemctl restart xray
sudo ss -tlnp | grep 10000

### 2. Port already in use:
sudo fuser -k 10000/tcp
sudo systemctl restart xray

### 3. User connect হচ্ছে না:
cat /usr/local/etc/xray/config.json
UUID আছে কিনা চেক করো।
না থাকলে manually যোগ করো।

### 4. Nginx সমস্যা:
sudo nginx -t
sudo systemctl restart nginx
sudo ss -tlnp | grep 80

### 5. Config corrupt হলে:
cat > /usr/local/etc/xray/config.json <<XRAY
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 10000,
    "protocol": "vless",
    "settings": {
      "clients": [
        {"id": "তোমার-UUID", "flow": ""}
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/ray",
        "headers": { "Host": "তোমার-domain" }
      }
    }
  }],
  "outbounds": [{"protocol": "freedom", "settings": {}}]
}
XRAY
sudo systemctl restart xray

### 6. Cloudflare 400 Bad Request:
- Cloudflare DNS Orange Cloud (Proxied) আছে কিনা চেক করো
- Cloudflare Network - WebSockets ON আছে কিনা চেক করো

### 7. X-UI port conflict:
x-ui uninstall
sudo fuser -k 10000/tcp
sudo systemctl restart xray

### 8. Nginx config নেই:
cat > /etc/nginx/sites-enabled/vless <<NGINX
server {
    listen 80;
    server_name তোমার-domain তোমার-VPS-IP;
    location /ray {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade dollar_sign_http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host dollar_sign_host;
        proxy_buffering off;
    }
}
NGINX
sudo nginx -t
sudo systemctl restart nginx

## মনে রাখবে:
- GitHub Token কখনো share করবে না
- Repository Private রাখো
- Cloudflare DNS Proxied (Orange) সবসময় রাখবে
- User delete করার পর xray status চেক করো
- UUID হারিয়ে গেলে config.json এ manually যোগ করো
