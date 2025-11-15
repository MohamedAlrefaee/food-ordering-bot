#!/bin/bash

echo "=== Food Ordering Chatbot Setup ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
TELEGRAM_BOT_TOKEN="8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4"
NGROK_TOKEN="31xDsAD7fsJT1mvY3qMofwQQaLU_7h4VXSPE2L954RX7bgbhP"

echo -e "${BLUE}Step 1: Starting Docker containers...${NC}"
docker-compose up -d

echo ""
echo -e "${BLUE}Step 2: Waiting for services to start (30 seconds)...${NC}"
sleep 30

echo ""
echo -e "${BLUE}Step 3: Pulling Ollama model (llama3.1:8b)...${NC}"
docker exec ollama ollama pull llama3.1:8b

echo ""
echo -e "${BLUE}Step 4: Setting up ngrok...${NC}"

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo -e "${RED}ngrok is not installed. Installing...${NC}"
    
    # Download ngrok
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xvzf ngrok-v3-stable-linux-amd64.tgz -C /usr/local/bin
    rm ngrok-v3-stable-linux-amd64.tgz
fi

# Configure ngrok
ngrok config add-authtoken $NGROK_TOKEN

# Start ngrok in background
echo -e "${BLUE}Starting ngrok tunnel...${NC}"
nohup ngrok http 5678 > ngrok.log 2>&1 &
NGROK_PID=$!

sleep 5

# Get ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$NGROK_URL" ]; then
    echo -e "${RED}Failed to get ngrok URL. Check ngrok.log${NC}"
    exit 1
fi

echo -e "${GREEN}ngrok URL: $NGROK_URL${NC}"

# Update webhook URL
WEBHOOK_URL="$NGROK_URL/webhook/telegram"

echo ""
echo -e "${BLUE}Step 5: Setting Telegram webhook...${NC}"

# Delete existing webhook (to avoid conflicts)
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/deleteWebhook"

sleep 2

# Set new webhook
WEBHOOK_RESPONSE=$(curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"$WEBHOOK_URL\"}")

echo $WEBHOOK_RESPONSE

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo -e "${GREEN}Your ngrok URL: $NGROK_URL${NC}"
echo -e "${GREEN}Webhook URL: $WEBHOOK_URL${NC}"
echo -e "${GREEN}n8n Interface: http://localhost:5678${NC}"
echo -e "${GREEN}Ollama API: http://localhost:11434${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Open http://localhost:5678 in your browser"
echo "2. Import the workflow from n8n-workflow.json"
echo "3. Update the Webhook node URL with: $WEBHOOK_URL"
echo "4. Activate the workflow"
echo "5. Test the bot on Telegram"
echo ""
echo -e "${BLUE}To check webhook status:${NC}"
echo "curl https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"
echo ""
echo -e "${BLUE}To view logs:${NC}"
echo "docker-compose logs -f"
