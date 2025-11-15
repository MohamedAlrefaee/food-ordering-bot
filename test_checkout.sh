#!/bin/bash

# Food Ordering Bot - Checkout Flow Test
# Simulates a complete checkout process

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

BOT_TOKEN="8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4"
TEST_CHAT_ID="123456789"

# Get ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$NGROK_URL" ]; then
    echo -e "${RED}ERROR: ngrok is not running!${NC}"
    echo -e "Start ngrok with: ngrok http 5678"
    exit 1
fi

WEBHOOK_URL="$NGROK_URL/webhook/telegram"

echo -e "${BLUE}=== Checkout Flow Test ===${NC}\n"
echo -e "Webhook URL: $WEBHOOK_URL\n"

# Helper function to send message
send_message() {
    local text=$1
    local callback_data=$2
    
    if [ -z "$callback_data" ]; then
        # Regular text message
        PAYLOAD="{
            \"update_id\": $RANDOM,
            \"message\": {
                \"message_id\": $RANDOM,
                \"from\": {
                    \"id\": $TEST_CHAT_ID,
                    \"first_name\": \"Test\",
                    \"username\": \"testuser\"
                },
                \"chat\": {
                    \"id\": $TEST_CHAT_ID,
                    \"type\": \"private\"
                },
                \"date\": $(date +%s),
                \"text\": \"$text\"
            }
        }"
    else
        # Callback query (button press)
        PAYLOAD="{
            \"update_id\": $RANDOM,
            \"callback_query\": {
                \"id\": \"$RANDOM\",
                \"from\": {
                    \"id\": $TEST_CHAT_ID,
                    \"first_name\": \"Test\",
                    \"username\": \"testuser\"
                },
                \"message\": {
                    \"message_id\": $RANDOM,
                    \"chat\": {
                        \"id\": $TEST_CHAT_ID,
                        \"type\": \"private\"
                    },
                    \"date\": $(date +%s),
                    \"text\": \"Previous message\"
                },
                \"data\": \"$callback_data\"
            }
        }"
    fi
    
    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" > /dev/null
    
    sleep 2
}

echo -e "${YELLOW}Step 1: Starting bot with /start${NC}"
send_message "/start"
echo -e "${GREEN}✓ Sent /start command${NC}\n"
sleep 2

echo -e "${YELLOW}Step 2: Adding items to cart${NC}"
send_message "BG1 x2, SD1, DR1"
echo -e "${GREEN}✓ Added items to cart${NC}\n"
sleep 3

echo -e "${YELLOW}Step 3: Viewing cart${NC}"
send_message "" "cart"
echo -e "${GREEN}✓ Viewed cart${NC}\n"
sleep 2

echo -e "${YELLOW}Step 4: Starting checkout${NC}"
send_message "" "checkout"
echo -e "${GREEN}✓ Started checkout${NC}\n"
sleep 2

echo -e "${YELLOW}Step 5: Selecting delivery type (Delivery)${NC}"
send_message "" "delivery"
echo -e "${GREEN}✓ Selected delivery${NC}\n"
sleep 2

echo -e "${YELLOW}Step 6: Entering name${NC}"
send_message "Ahmed Mohamed"
echo -e "${GREEN}✓ Entered name: Ahmed Mohamed${NC}\n"
sleep 2

echo -e "${YELLOW}Step 7: Entering phone number${NC}"
send_message "01012345678"
echo -e "${GREEN}✓ Entered phone: 01012345678${NC}\n"
sleep 2

echo -e "${YELLOW}Step 8: Entering address${NC}"
send_message "123 Main Street, Nasr City, Cairo, Egypt"
echo -e "${GREEN}✓ Entered address${NC}\n"
sleep 2

echo -e "${YELLOW}Step 9: Confirming order${NC}"
send_message "" "confirm_order"
echo -e "${GREEN}✓ Confirmed order${NC}\n"
sleep 3

echo -e "${BLUE}=== Checkout Flow Test Complete ===${NC}\n"

echo -e "${BLUE}Verification Steps:${NC}"
echo -e "1. Check Telegram bot for complete conversation"
echo -e "2. Verify order was created with Order ID"
echo -e "3. Check n8n Data Store for cart, profile, and order"
echo -e "4. If WhatsApp is configured, check admin notification"
echo ""

echo -e "${YELLOW}Manual Verification:${NC}"
echo -e "Open Telegram and check the bot conversation"
echo -e "You should see:"
echo -e "  ✓ Welcome message"
echo -e "  ✓ Items added confirmation"
echo -e "  ✓ Cart display"
echo -e "  ✓ Checkout prompts (delivery type, name, phone, address)"
echo -e "  ✓ Order confirmation with Order ID"
echo ""

echo -e "${BLUE}n8n Verification:${NC}"
echo -e "1. Open http://localhost:5678"
echo -e "2. Go to 'Executions' tab"
echo -e "3. Check recent executions for:"
echo -e "   - Successful webhook receptions"
echo -e "   - Cart updates"
echo -e "   - Order creation"
echo ""

echo -e "${BLUE}Data Store Verification:${NC}"
echo -e "In n8n UI, check Data Store for:"
echo -e "  - Key: cart:$TEST_CHAT_ID"
echo -e "  - Key: profile:$TEST_CHAT_ID"
echo -e "  - Key: order:ORD-*"
echo ""

# Test pickup flow
read -p "Do you want to test Pickup flow? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}=== Testing Pickup Flow ===${NC}\n"
    
    echo -e "${YELLOW}Clearing cart first...${NC}"
    send_message "" "clear_cart"
    send_message "" "confirm_clear"
    sleep 2
    
    echo -e "${YELLOW}Adding new items...${NC}"
    send_message "BG2, DR2"
    sleep 3
    
    echo -e "${YELLOW}Starting checkout...${NC}"
    send_message "" "checkout"
    sleep 2
    
    echo -e "${YELLOW}Selecting Pickup...${NC}"
    send_message "" "pickup"
    sleep 2
    
    echo -e "${YELLOW}Entering name...${NC}"
    send_message "Sara Ahmed"
    sleep 2
    
    echo -e "${YELLOW}Entering phone...${NC}"
    send_message "01098765432"
    sleep 2
    
    echo -e "${YELLOW}Confirming order...${NC}"
    send_message "" "confirm_order"
    sleep 3
    
    echo -e "${GREEN}✓ Pickup flow complete${NC}\n"
fi

# Test error cases
read -p "Do you want to test error cases? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}=== Testing Error Cases ===${NC}\n"
    
    echo -e "${YELLOW}Test 1: Empty cart checkout${NC}"
    send_message "" "clear_cart"
    send_message "" "confirm_clear"
    sleep 2
    send_message "" "checkout"
    echo -e "${GREEN}✓ Should show empty cart error${NC}\n"
    sleep 2
    
    echo -e "${YELLOW}Test 2: Invalid phone number${NC}"
    send_message "BG1"
    sleep 2
    send_message "" "checkout"
    sleep 2
    send_message "" "delivery"
    sleep 2
    send_message "Test User"
    sleep 2
    send_message "123"
    echo -e "${GREEN}✓ Should show invalid phone error${NC}\n"
    sleep 2
    
    echo -e "${YELLOW}Test 3: Invalid item codes${NC}"
    send_message "" "menu"
    sleep 2
    send_message "XYZ123, ABC456"
    echo -e "${GREEN}✓ Should show invalid codes error${NC}\n"
    sleep 2
fi

echo -e "${BLUE}=== All Tests Complete ===${NC}\n"
echo -e "${GREEN}Review the bot conversation in Telegram to verify all tests passed${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "1. Check bot responses in Telegram"
echo -e "2. Verify data in n8n Data Store"
echo -e "3. Check n8n execution logs for errors"
echo -e "4. Test with real Telegram account (not simulated)"
echo ""
