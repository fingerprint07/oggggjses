#!/bin/bash

# Domain Setup Script for Token Grabber
# Run with: sudo bash setup-domain.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🌐 Domain Setup for Token Grabber${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Please run as root: sudo bash setup-domain.sh${NC}"
  exit 1
fi

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ask for domain
echo -e "${YELLOW}Enter your domain (e.g. panel.yourdomain.com):${NC}"
read -r DOMAIN

if [ -z "$DOMAIN" ]; then
  echo -e "${RED}❌ Domain cannot be empty${NC}"
  exit 1
fi

# Ask for email (for Let's Encrypt)
echo ""
echo -e "${YELLOW}Enter your email (for SSL certificate notifications):${NC}"
read -r EMAIL

if [ -z "$EMAIL" ]; then
  echo -e "${RED}❌ Email cannot be empty${NC}"
  exit 1
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Domain:  ${GREEN}$DOMAIN${NC}"
echo -e "  Email:   ${GREEN}$EMAIL${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Proceed? (y/n):${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo -e "${RED}Cancelled.${NC}"
  exit 0
fi

echo ""

# Step 1: Install Nginx + Certbot
echo -e "${CYAN}[1/4] Installing Nginx & Certbot...${NC}"
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx
echo -e "${GREEN}  ✓ Nginx & Certbot installed${NC}"

# Step 2: Create temporary nginx config (HTTP only) so certbot can verify domain
echo -e "${CYAN}[2/4] Configuring Nginx...${NC}"

NGINX_CONF="/etc/nginx/sites-available/token-grabber"

cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable site, disable default
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/token-grabber
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx
echo -e "${GREEN}  ✓ Nginx configured${NC}"

# Step 3: Get SSL certificate via certbot nginx plugin
echo -e "${CYAN}[3/4] Getting SSL certificate from Let's Encrypt...${NC}"
echo -e "${YELLOW}  (Make sure your domain DNS points to this server's IP first!)${NC}"
echo ""

certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
echo -e "${GREEN}  ✓ SSL certificate installed & Nginx updated for HTTPS${NC}"

# Step 4: Update ssl.json
echo -e "${CYAN}[4/4] Updating ssl.json...${NC}"

SSL_JSON="$SCRIPT_DIR/ssl.json"

cat > "$SSL_JSON" <<EOF
{
  "domain": "$DOMAIN",
  "certPath": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem",
  "keyPath": "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
}
EOF

echo -e "${GREEN}  ✓ ssl.json updated${NC}"

# Setup cert renewal hook to reload nginx
cat > /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh <<'EOF'
#!/bin/bash
systemctl reload nginx 2>/dev/null || true
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh

# Restart the app
systemctl restart token-grabber 2>/dev/null || true

# Done
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Domain setup complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🌐 Your site:    ${GREEN}https://$DOMAIN${NC}"
echo -e "  🔧 Admin panel:  ${GREEN}https://$DOMAIN/admin${NC}"
echo -e "  📧 Webmail:      ${GREEN}https://$DOMAIN/mailbox-login.html${NC}"
echo ""
echo -e "  SSL auto-renews via certbot timer."
echo -e "  To check: ${CYAN}sudo certbot renew --dry-run${NC}"
echo ""
echo -e "  🔧 Nginx commands:"
echo -e "     Status:  ${CYAN}sudo systemctl status nginx${NC}"
echo -e "     Logs:    ${CYAN}sudo tail -f /var/log/nginx/error.log${NC}"
echo ""
