# Telegram Webhook Troubleshooting Guide

This guide helps you avoid and fix common webhook issues with your Telegram bot.

## Understanding Webhooks

A webhook is a way for Telegram to send updates to your bot. Instead of your bot constantly checking for new messages (polling), Telegram sends them directly to your server.

**Requirements:**
- Public HTTPS URL
- Valid SSL certificate
- Only ONE webhook per bot

## Common Webhook Problems

### Problem 1: "Webhook is already set for another URL"

**Cause:** You previously set a webhook to a different URL

**Solution:**
```bash
# Delete existing webhook
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/deleteWebhook"

# Wait 2 seconds
sleep 2

# Set new webhook
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook" \
  -d "url=YOUR_NEW_NGROK_URL/webhook/telegram"
```

### Problem 2: "pending_update_count" keeps increasing

**Cause:** Webhook URL is not responding or returning errors

**Solution:**
```bash
# Check what's wrong
curl "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo"

# Look for "last_error_message" in response

# Common fixes:
# 1. Check n8n is running
docker ps | grep n8n

# 2. Check ngrok is active
curl http://localhost:4040/api/tunnels

# 3. Check n8n workflow is activated
# Open http://localhost:5678 and verify green toggle

# 4. Test webhook manually
curl -X POST "YOUR_NGROK_URL/webhook/telegram" \
  -H "Content-Type: application/json" \
  -d '{"message":{"chat":{"id":123},"text":"test"}}'
```

### Problem 3: Bot responds once then stops

**Cause:** ngrok free tier session expired (2 hours)

**Solution:**
```bash
# Restart ngrok
pkill ngrok
ngrok http 5678 > ngrok.log 2>&1 &

# Wait 5 seconds
sleep 5

# Get new URL
NEW_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)

echo "New URL: $NEW_URL"

# Update webhook
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook" \
  -d "url=$NEW_URL/webhook/telegram"

# Verify
curl "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo"
```

### Problem 4: "Connection refused" error

**Cause:** n8n is not running or not accessible

**Solution:**
```bash
# Check if n8n is running
docker ps | grep n8n

# If not running, start it
docker-compose up -d n8n

# Check n8n logs
docker logs n8n -f

# Test n8n webhook endpoint
curl -X POST "http://localhost:5678/webhook/telegram" \
  -H "Content-Type: application/json" \
  -d '{"message":{"chat":{"id":123},"text":"test"}}'
```

### Problem 5: "Invalid SSL certificate"

**Cause:** ngrok SSL certificate not accepted (rare)

**Solution:**
```bash
# This shouldn't happen with ngrok, but if it does:

# Option 1: Use different ngrok region
ngrok http 5678 --region eu

# Option 2: Restart ngrok
pkill ngrok
ngrok http 5678

# Option 3: Get new ngrok authtoken
# Visit: https://dashboard.ngrok.com/get-started/your-authtoken
```

## Webhook Best Practices

### 1. Always Check Status First

Before changing anything:
```bash
curl "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo" | jq
```

Look for:
- `url`: Should match your ngrok URL
- `has_custom_certificate`: Should be false
- `pending_update_count`: Should be 0
- `last_error_date`: Should be 0 (no errors)
- `last_error_message`: Should not exist

### 2. Delete Before Setting

Always delete existing webhook before setting new one:
```bash
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/deleteWebhook"
sleep 2
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook" -d "url=YOUR_URL"
```

### 3. Use Correct Path

Your webhook URL must include the path:
- ✅ Correct: `https://abc123.ngrok.io/webhook/telegram`
- ❌ Wrong: `https://abc123.ngrok.io/telegram`
- ❌ Wrong: `https://abc123.ngrok.io/webhook`
- ❌ Wrong: `https://abc123.ngrok.io`

### 4. Monitor Regularly

Set up a cron job to check webhook status:
```bash
# Add to crontab (every 5 minutes)
*/5 * * * * curl -s "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo" | jq '.result.pending_update_count' > /tmp/webhook_status.txt
```

### 5. Handle ngrok Expiration

Create a script to auto-renew ngrok:
```bash
#!/bin/bash
# auto_renew_ngrok.sh

while true; do
  # Check if ngrok is running
  if ! pgrep ngrok > /dev/null; then
    echo "ngrok not running, starting..."
    ngrok http 5678 > ngrok.log 2>&1 &
    sleep 5
    
    # Get new URL
    NEW_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)
    
    # Update webhook
    curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook" \
      -d "url=$NEW_URL/webhook/telegram"
    
    echo "Webhook updated to: $NEW_URL"
  fi
  
  # Check every hour
  sleep 3600
done
```

## Testing Webhooks

### Test 1: Manual Webhook Call

```bash
# Get your ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)

# Send test update
curl -X POST "$NGROK_URL/webhook/telegram" \
  -H "Content-Type: application/json" \
  -d '{
    "update_id": 123456789,
    "message": {
      "message_id": 1,
      "from": {
        "id": 123456789,
        "first_name": "Test",
        "username": "testuser"
      },
      "chat": {
        "id": 123456789,
        "type": "private"
      },
      "date": 1234567890,
      "text": "/start"
    }
  }'
```

### Test 2: Check n8n Execution

1. Open n8n: http://localhost:5678
2. Go to "Executions" tab
3. Look for recent executions
4. Check for errors

### Test 3: Live Testing

```bash
# Enable debug mode
export N8N_LOG_LEVEL=debug

# Restart n8n
docker restart n8n

# Watch logs
docker logs n8n -f

# Now send message to bot and watch logs
```

## Debugging Workflow

When webhook issues occur, follow this debugging workflow:

```
1. Check Telegram webhook status
   ↓
2. Check ngrok is running and URL is correct
   ↓
3. Check n8n is running and accessible
   ↓
4. Check n8n workflow is activated
   ↓
5. Test webhook manually
   ↓
6. Check n8n execution logs
   ↓
7. Fix and verify
```

## Emergency Reset

If nothing works, do a complete reset:

```bash
# 1. Stop everything
docker-compose down
pkill ngrok

# 2. Delete webhook
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/deleteWebhook"

# 3. Wait
sleep 5

# 4. Start fresh
docker-compose up -d

# 5. Wait for services
sleep 30

# 6. Start ngrok
ngrok http 5678 > ngrok.log 2>&1 &
sleep 5

# 7. Get URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)

# 8. Set webhook
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook" \
  -d "url=$NGROK_URL/webhook/telegram"

# 9. Verify
curl "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo"

# 10. Test
# Send /start to bot
```

## Production Webhook Setup

For production (no ngrok):

### Option 1: Domain + Let's Encrypt

```bash
# Install certbot
sudo apt install certbot

# Get SSL certificate
sudo certbot certonly --standalone -d yourdomain.com

# Configure nginx
sudo nano /etc/nginx/sites-available/n8n

# Add this configuration:
server {
    listen 443 ssl;
    server_name yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    location /webhook/telegram {
        proxy_pass http://localhost:5678/webhook/telegram;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Enable and restart nginx
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# Set webhook
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook" \
  -d "url=https://yourdomain.com/webhook/telegram"
```

### Option 2: Cloud Functions (AWS Lambda)

Deploy n8n to AWS Lambda and use API Gateway for webhook endpoint.

### Option 3: Railway/Render/Heroku

Use platform webhooks (automatic HTTPS).

## Monitoring Script

Create a monitoring script:

```bash
#!/bin/bash
# webhook_monitor.sh

BOT_TOKEN="8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4"
ALERT_EMAIL="your@email.com"

while true; do
  # Get webhook info
  INFO=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo")
  
  # Extract pending count
  PENDING=$(echo $INFO | jq '.result.pending_update_count')
  
  # Check if too many pending
  if [ "$PENDING" -gt 10 ]; then
    echo "WARNING: $PENDING pending updates!"
    # Send alert email
    echo "Webhook has $PENDING pending updates" | mail -s "Webhook Alert" $ALERT_EMAIL
    
    # Auto-fix: restart services
    docker restart n8n
  fi
  
  # Check every 5 minutes
  sleep 300
done
```

## Summary

**Key Points:**
1. Always delete webhook before setting new one
2. Use correct URL with full path
3. Monitor `pending_update_count`
4. Handle ngrok expiration
5. Test manually before going live
6. Keep logs for debugging
7. Use production setup for real deployment

**Quick Commands:**
```bash
# Status
curl https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo

# Delete
curl -X POST https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/deleteWebhook

# Set
curl -X POST https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook -d "url=YOUR_URL/webhook/telegram"
```

**Remember:** The most common issue is ngrok URL expiring. Always check webhook status first!
