# 🚀 VLESS + Cloudflare Auto Setup

## 📦 নতুন VPS Setup
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Eiasin/vless-setup/main/setup-vless.sh)
```

## 👤 User Manager
```bash
bash /root/vless-setup/generate-vless-link.sh
```

## 📱 Client Settings (v2rayNG)

| Field   | HTTP (port 80) | HTTPS (port 443) |
|---------|----------------|------------------|
| Address | 104.16.119.28  | 104.16.119.28    |
| Port    | 80             | 443              |
| Network | ws             | ws               |
| Path    | /ray           | /ray             |
| Host    | তোমার domain   | তোমার domain     |
| TLS     | OFF            | ON               |
| SNI     | -              | তোমার domain     |

---

## 🔒 SSL Certificate Setup (গুরুত্বপূর্ণ)

### SSL নেওয়ার আগে:
1. Cloudflare Dashboard → DNS
2. তোমার domain A Record → Grey Cloud (DNS Only) করো
3. Script চালাও → SSL certificate নেওয়া হবে
4. SSL নেওয়া হলে → আবার Orange Cloud (Proxied) করো
5. Cloudflare → SSL/TLS → Full করো

### SSL নেওয়ার পর Cloudflare Settings:
- DNS → Orange Cloud (Proxied) ✓
- SSL/TLS Mode → Full ✓
- Network → WebSockets → ON ✓

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
sudo ss -tlnp | grep 80
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
- Cloudflare Dashboard → DNS → Orange Cloud (Proxied) চেক করো
- Cloudflare Dashboard → Network → WebSockets → ON করো

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
    server_name তোমার-domain তোমার-VPS-IP;

    location /ray {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF
sudo nginx -t
sudo systemctl restart nginx
```

### 9. X-UI panel access না হলে
```bash
sqlite3 /etc/x-ui/x-ui.db "UPDATE settings SET value='0.0.0.0' WHERE key='webListen';"
x-ui restart
```

### 10. SSL certificate renew করতে
```bash
sudo certbot renew
sudo systemctl restart nginx
```

---

## ⚠️ মনে রাখবে

- GitHub Token কখনো share করবে না
- Repository Private রাখো
- SSL নেওয়ার সময় Cloudflare DNS Grey Cloud করো, শেষ হলে Orange Cloud করো
- Cloudflare SSL/TLS → Full রাখবে (SSL থাকলে)
- Cloudflare SSL/TLS → Flexible রাখবে (SSL না থাকলে)
- Cloudflare Network → WebSockets → সবসময় ON রাখবে
- User delete করার পর xray status চেক করো
- UUID হারিয়ে গেলে config.json এ manually যোগ করো
- নতুন user বানানোর পর সবসময় xray restart করো
