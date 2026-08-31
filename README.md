# 🚀 VLESS + Cloudflare + SSL Auto Setup

## 📦 নতুন VPS Setup (A-Z)
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Eiasin/vless-setup/main/setup-vless.sh)
```

### Setup-এ যা যা জিজ্ঞেস করবে:
- Domain: `vpn2.kanij.site`
- Cloudflare IP: Enter (default: 104.16.119.28)
- WS Path: Enter (default: /ray)
- Xray Port: Enter (default: 10000)
- Email: তোমার email (SSL-এর জন্য)
- Grey Cloud ready?: `y`

### SSL নেওয়ার আগে (গুরুত্বপূর্ণ!):
1. Cloudflare → DNS → `vpn2` A Record → **Grey Cloud (DNS Only)** করো
2. Script চালাও → SSL নেওয়া হবে
3. SSL হলে → **Orange Cloud (Proxied)** করো
4. Cloudflare → SSL/TLS → **Full** করো
5. Cloudflare → Network → **WebSockets → ON** করো

---

## 👤 User Manager
```bash
bash /root/vless-setup/generate-vless-link.sh
```

### Options:
- **1**: নতুন user তৈরি + link generate
- **2**: সব user list দেখো
- **3**: কোনো user-এর link পাও
- **4**: User delete করো
- **5**: Exit

---

## 📱 Client Settings (v2rayNG)

| Field      | Value                  |
|------------|------------------------|
| Address    | 104.16.119.28          |
| Port       | 443                    |
| Network    | ws                     |
| Path       | /ray                   |
| Host       | vpn2.kanij.site        |
| TLS        | ON                     |
| SNI        | vpn2.kanij.site        |
| Encryption | none                   |

---

## 🔒 Security Level: ⭐⭐⭐⭐ (4/5)

| বিষয় | Status |
|---|---|
| Traffic Encryption | ✅ TLS 1.2/1.3 |
| VPS IP Hidden | ✅ Cloudflare-এর পেছনে |
| DPI Bypass | ✅ WebSocket + TLS |
| ISP দেখতে পারে | ✅ না |
| Protocol Detection | ✅ Normal HTTPS মনে হয় |
| SSL Certificate | ✅ Let's Encrypt |

### ISP শুধু দেখতে পারে:
- তুমি Cloudflare-এর সাথে HTTPS connect করছো
- আর কিছু না!

---

## 🔧 সমস্যা সমাধান

### 1. Xray চলছে না
```bash
sudo systemctl restart xray
sudo ss -tlnp | grep 10000
```

### 2. Port already in use
```bash
sudo fuser -k 10000/tcp
sudo systemctl restart xray
```

### 3. User connect হচ্ছে না
```bash
cat /usr/local/etc/xray/config.json
```
UUID আছে কিনা চেক করো। না থাকলে manually যোগ করো:
```bash
sudo nano /usr/local/etc/xray/config.json
```
clients array-তে যোগ করো:
```json
{"id": "তোমার-UUID", "flow": ""}
```
তারপর:
```bash
sudo systemctl restart xray
```

### 4. Nginx সমস্যা
```bash
sudo nginx -t
sudo systemctl restart nginx
sudo ss -tlnp | grep 443
```

### 5. Config corrupt হলে
```bash
cat > /usr/local/etc/xray/config.json << 'EOF'
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
EOF
sudo systemctl restart xray
```

### 6. Cloudflare 400 Bad Request
- Cloudflare → DNS → Orange Cloud (Proxied) চেক করো
- Cloudflare → Network → WebSockets → ON করো
- Cloudflare → SSL/TLS → Full করো

### 7. X-UI port conflict
```bash
x-ui uninstall
sudo fuser -k 10000/tcp
sudo systemctl restart xray
```

### 8. Nginx config নেই
```bash
cat > /etc/nginx/sites-enabled/vless << 'EOF'
server {
    listen 80;
    server_name তোমার-domain;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name তোমার-domain;

    ssl_certificate /etc/letsencrypt/live/তোমার-domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/তোমার-domain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location /ray {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_buffering off;
    }
}
EOF
sudo nginx -t
sudo systemctl restart nginx
```

### 9. SSL certificate renew করতে
```bash
sudo certbot renew
sudo systemctl restart nginx
```

### 10. User link-এ port 80 আসছে
```bash
cat /etc/vless-config.conf
```
`CLIENT_PORT=443` এবং `CLIENT_TLS=tls` আছে কিনা চেক করো।
না থাকলে:
```bash
cat > /etc/vless-config.conf << 'EOF'
DOMAIN=vpn2.kanij.site
CF_IP=104.16.119.28
WS_PATH=/ray
XRAY_PORT=10000
CLIENT_PORT=443
CLIENT_TLS=tls
EOF
```

---

## ⚠️ মনে রাখবে

- GitHub Token কখনো share করবে না
- Repository Private রাখো
- SSL নেওয়ার সময় Cloudflare DNS Grey Cloud করো, শেষ হলে Orange Cloud করো
- Cloudflare SSL/TLS → Full রাখবে
- Cloudflare Network → WebSockets → সবসময় ON রাখবে
- User delete করার পর xray status চেক করো
- UUID হারিয়ে গেলে config.json এ manually যোগ করো
- নতুন user বানানোর পর সবসময় xray restart করো
- XTLS Vision Cloudflare proxy-এর সাথে কাজ করে না
