# n8n Workflow Construction Guide

Since the complete workflow JSON is very large, I'll provide you with step-by-step instructions to build it in n8n manually.

## Workflow Structure Overview

```
Telegram Webhook → Route by Message Type → Process → Respond
                         │
                         ├─ /start command
                         ├─ Button callbacks
                         ├─ Text messages (structured/AI)
                         └─ Checkout flow
```

## Step-by-Step Workflow Creation

### 1. Create Webhook Trigger

1. Add **Webhook** node
2. Configuration:
   - **HTTP Method**: POST
   - **Path**: `telegram`
   - **Respond**: Using 'Respond to Webhook' Node
   - **Response Mode**: When Last Node Finishes

### 2. Add Switch Node - Route by Type

Add **Switch** node after webhook:

**Routing Rules:**
```javascript
// Rule 1: Start Command
{{ $json.message.text === '/start' }}

// Rule 2: Button Callback
{{ $json.callback_query }}

// Rule 3: Text Message
{{ $json.message.text }}

// Rule 4: Help Command
{{ $json.message.text === '/help' }}
```

### 3. Handle /start Command

Add **HTTP Request** node:

```javascript
// Method: POST
// URL: https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/sendMessage

// Body (JSON):
{
  "chat_id": "{{ $json.message.chat.id }}",
  "text": "مرحباً بك في مطعمنا! 🍔\n\nاختر من القائمة:",
  "reply_markup": {
    "inline_keyboard": [
      [
        {"text": "View Menu 📋", "callback_data": "menu"},
        {"text": "My Cart 🛒", "callback_data": "cart"}
      ],
      [
        {"text": "Checkout 💳", "callback_data": "checkout"},
        {"text": "Help ❓", "callback_data": "help"}
      ]
    ]
  }
}
```

### 4. Handle Button Callbacks

Add **Switch** node for callback routing:

```javascript
// Menu Button
{{ $json.callback_query.data === 'menu' }}

// Cart Button
{{ $json.callback_query.data === 'cart' }}

// Checkout Button
{{ $json.callback_query.data === 'checkout' }}

// Help Button
{{ $json.callback_query.data === 'help' }}
```

### 5. Display Menu

Add **Code** node to load menu:

```javascript
const menu = {
  "categories": [
    {
      "name": "Burgers",
      "items": [
        {"code": "BG1", "name": "Classic Burger", "price": 85},
        {"code": "BG2", "name": "Chicken Burger", "price": 75},
        {"code": "BG3", "name": "Cheese Burger", "price": 95},
        {"code": "BG4", "name": "BBQ Burger", "price": 105}
      ]
    },
    {
      "name": "Sides",
      "items": [
        {"code": "SD1", "name": "French Fries", "price": 30},
        {"code": "SD2", "name": "Onion Rings", "price": 35},
        {"code": "SD3", "name": "Coleslaw", "price": 25},
        {"code": "SD4", "name": "Mozzarella Sticks", "price": 45}
      ]
    },
    {
      "name": "Drinks",
      "items": [
        {"code": "DR1", "name": "Coca Cola", "price": 15},
        {"code": "DR2", "name": "Orange Juice", "price": 25},
        {"code": "DR3", "name": "Water", "price": 10},
        {"code": "DR4", "name": "Sprite", "price": 15}
      ]
    }
  ]
};

let text = "📋 **القائمة**\n\n";

menu.categories.forEach(cat => {
  text += `**${cat.name}**\n`;
  cat.items.forEach(item => {
    text += `• ${item.code} - ${item.name} - ${item.price} EGP\n`;
  });
  text += "\n";
});

text += "للطلب، أرسل الأكواد مثل: BG1 x2, SD1, DR1";

return [{
  chatId: $input.item.json.callback_query.message.chat.id,
  messageId: $input.item.json.callback_query.message.message_id,
  text: text
}];
```

Then add **HTTP Request** to send:

```javascript
// Method: POST
// URL: https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/editMessageText

{
  "chat_id": "{{ $json.chatId }}",
  "message_id": "{{ $json.messageId }}",
  "text": "{{ $json.text }}",
  "parse_mode": "Markdown"
}
```

### 6. Parse Text Messages

Add **Code** node for structured parsing:

```javascript
const text = $input.item.json.message.text;
const chatId = $input.item.json.message.chat.id;

// Structured parser - regex for codes
const regex = /(BG|SD|DR)(\d+)(?:\s*x\s*(\d+))?/gi;
const matches = [...text.matchAll(regex)];

if (matches.length > 0) {
  // Structured parsing success
  const items = matches.map(match => ({
    code: match[1] + match[2],
    quantity: match[3] ? parseInt(match[3]) : 1
  }));
  
  return [{
    chatId: chatId,
    items: items,
    method: 'structured'
  }];
} else {
  // Need AI extraction
  return [{
    chatId: chatId,
    text: text,
    method: 'ai'
  }];
}
```

### 7. AI Extraction (Ollama)

Add **HTTP Request** node for Ollama:

```javascript
// Method: POST
// URL: http://ollama:11434/v1/chat/completions

{
  "model": "llama3.1:8b",
  "messages": [
    {
      "role": "system",
      "content": "You are a food ordering assistant. Extract items from text and return ONLY valid JSON. Menu: BG1=Classic Burger, BG2=Chicken Burger, BG3=Cheese Burger, BG4=BBQ Burger, SD1=French Fries, SD2=Onion Rings, SD3=Coleslaw, SD4=Mozzarella Sticks, DR1=Coca Cola, DR2=Orange Juice, DR3=Water, DR4=Sprite. Return format: {\"items\": [{\"code\": \"BG1\", \"quantity\": 2}]}"
    },
    {
      "role": "user",
      "content": "{{ $json.text }}"
    }
  ],
  "temperature": 0.1,
  "response_format": { "type": "json_object" }
}
```

Then add **Code** node to parse AI response:

```javascript
try {
  const response = $input.item.json.choices[0].message.content;
  const cleaned = response.replace(/```json\n?|\n?```/g, '');
  const parsed = JSON.parse(cleaned);
  
  if (Array.isArray(parsed.items) && parsed.items.length > 0) {
    return [{
      chatId: $input.item.json.chatId,
      items: parsed.items,
      method: 'ai'
    }];
  } else {
    // Fallback
    return [{
      chatId: $input.item.json.chatId,
      error: 'Could not understand request',
      method: 'failed'
    }];
  }
} catch (error) {
  return [{
    chatId: $input.item.json.chatId,
    error: error.message,
    method: 'failed'
  }];
}
```

### 8. Load Cart from Data Store

Add **Get Data Store** node:

```javascript
// Key: cart:{{ $json.chatId }}
```

### 9. Update Cart

Add **Code** node:

```javascript
const currentCart = $input.first().json || { items: [] };
const newItems = $input.all()[1].json.items;
const menu = /* menu data */;

// Add new items to cart
newItems.forEach(newItem => {
  const menuItem = findInMenu(menu, newItem.code);
  if (menuItem) {
    const existing = currentCart.items.find(i => i.code === newItem.code);
    if (existing) {
      existing.quantity += newItem.quantity;
    } else {
      currentCart.items.push({
        code: newItem.code,
        name: menuItem.name,
        price: menuItem.price,
        quantity: newItem.quantity
      });
    }
  }
});

// Calculate total
currentCart.total = currentCart.items.reduce((sum, item) => 
  sum + (item.price * item.quantity), 0
);

return [currentCart];
```

### 10. Save Cart to Data Store

Add **Set Data Store** node:

```javascript
// Key: cart:{{ $json.chatId }}
// Value: {{ $json }}
```

### 11. Checkout Flow

**State Machine using Data Store:**

States:
- `collect_delivery_type`
- `collect_name`
- `collect_phone`
- `collect_address`
- `confirm_order`

Use **Switch** nodes to route based on current state stored in Data Store key `checkout_state:{{ $json.chatId }}`

### 12. Order Confirmation

Add **Code** node to generate Order ID:

```javascript
const orderId = `ORD-${Date.now()}-${$json.chatId}`;
const order = {
  order_id: orderId,
  chat_id: $json.chatId,
  items: $json.cart.items,
  total: $json.cart.total,
  customer: $json.customer,
  status: 'pending',
  created_at: new Date().toISOString()
};

return [order];
```

### 13. WhatsApp Notification (Bonus)

Add **HTTP Request** node:

```javascript
// Method: POST
// URL: https://graph.facebook.com/v18.0/WA_PHONE_ID/messages

// Headers:
Authorization: Bearer WA_TOKEN

// Body:
{
  "messaging_product": "whatsapp",
  "to": "WA_ADMIN_NUMBER",
  "type": "text",
  "text": {
    "body": "🆕 New Order: {{ $json.order_id }}\n\nTotal: {{ $json.total }} EGP\nCustomer: {{ $json.customer.name }}\nPhone: {{ $json.customer.phone }}"
  }
}
```

## Workflow Best Practices

1. **Error Handling**: Add error handlers to all HTTP nodes
2. **Timeouts**: Set 30s timeout for Ollama requests
3. **Retries**: Enable 2 retries for Telegram API calls
4. **Logging**: Use **Set** nodes to log important steps
5. **Testing**: Test each branch separately

## Data Store Keys

```
cart:{chat_id}              - User's shopping cart
profile:{chat_id}           - User profile info
checkout_state:{chat_id}    - Current checkout step
order:{order_id}            - Completed order
```

## Complete Workflow JSON

Due to size limitations, the complete workflow JSON is provided in a separate file: `n8n-workflow.json`

You can import it directly into n8n:
1. Open n8n UI
2. Click "Import from File"
3. Select `n8n-workflow.json`
4. Update webhook URL with your ngrok URL
5. Activate workflow

## Quick Setup Commands

```bash
# 1. Start services
docker-compose up -d

# 2. Pull Ollama model
docker exec ollama ollama pull llama3.1:8b

# 3. Get ngrok URL
curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'

# 4. Set Telegram webhook
NGROK_URL="your_ngrok_url"
curl -X POST "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/setWebhook" \
  -d "url=$NGROK_URL/webhook/telegram"

# 5. Verify webhook
curl "https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo"
```

## Testing Checklist

- [ ] /start command works
- [ ] Menu displays correctly
- [ ] Structured ordering (BG1 x2, SD1)
- [ ] AI extraction (free text)
- [ ] Arabic text extraction
- [ ] Cart view and clear
- [ ] Checkout flow (pickup)
- [ ] Checkout flow (delivery)
- [ ] Phone validation
- [ ] Order confirmation
- [ ] WhatsApp notification
- [ ] Error handling (empty cart)
- [ ] Error handling (invalid codes)

## Troubleshooting

### Webhook not responding
```bash
# Check webhook status
curl https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/getWebhookInfo

# Reset webhook
curl -X POST https://api.telegram.org/bot8246352423:AAGe6R3M5VLUXzlWMmFdccQMi2QuNebdZN4/deleteWebhook
```

### AI not working
```bash
# Test Ollama
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"test"}]}'
```

### n8n errors
```bash
# Check logs
docker logs n8n -f

# Restart
docker restart n8n
```
