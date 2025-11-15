# Technical Notes & Design Decisions

## 1. AI Model Selection

### Choice: Ollama with llama3.1:8b

**Rationale:**
- **Open-source**: Fully compliant with task requirements
- **Resource Efficient**: 8B parameter model runs on consumer hardware
- **Quality**: Excellent instruction-following and JSON generation
- **OpenAI Compatible**: Exposes `/v1/chat/completions` endpoint
- **Easy Deployment**: Docker-ready with simple setup

**Alternatives Considered:**
- **llama.cpp**: Lower-level, requires more setup
- **vLLM**: Better for high-throughput but overkill for demo
- **Mistral 7B**: Good alternative but llama3.1 has better Arabic support

**Model Size Trade-offs:**
- **llama3.1:3b**: Too small, poor extraction quality
- **llama3.1:8b**: ✅ Sweet spot for accuracy/speed
- **llama3.1:70b**: Better quality but too slow and resource-heavy

## 2. AI Extraction Strategy

### Prompt Engineering

The AI extraction uses a carefully crafted prompt:

```
You are a food ordering assistant. Extract items from user text.

Menu:
{menu_json}

User said: "{user_text}"

Return ONLY valid JSON:
{
  "items": [
    {"code": "BG1", "quantity": 2},
    {"code": "DR1", "quantity": 1}
  ],
  "confidence": 0.95,
  "ambiguities": []
}

Rules:
- Match items by name or description (English/Arabic)
- Default quantity: 1
- If unsure, add to ambiguities array
- Return empty items array if nothing matches
```

**Why This Works:**
1. **Context-Rich**: Full menu in prompt ensures accurate matching
2. **Structured Output**: JSON format enables validation
3. **Confidence Scoring**: Allows fallback decisions
4. **Ambiguity Handling**: Explicitly asks user for clarification
5. **Bilingual**: Supports both English and Arabic

### JSON Validation

Post-processing in Code node:
```javascript
try {
  // Strip markdown code blocks if present
  let cleaned = aiResponse.replace(/```json\n?|\n?```/g, '');
  
  // Parse JSON
  let parsed = JSON.parse(cleaned);
  
  // Validate structure
  if (!Array.isArray(parsed.items)) {
    throw new Error('Invalid structure');
  }
  
  // Validate each item
  parsed.items.forEach(item => {
    if (!item.code || !item.quantity) {
      throw new Error('Missing required fields');
    }
  });
  
  return parsed;
} catch (error) {
  // Fallback to structured parser
  return fallbackParser(userText);
}
```

### Fallback Mechanism

**Three-Tier Extraction:**

1. **Tier 1: Structured Parser** (Regex-based)
   - Pattern: `(BG|SD|DR)\d+(\s*x\s*\d+)?`
   - Fast, reliable for explicit codes
   - Examples: `BG1 x2`, `SD1, DR1`

2. **Tier 2: AI Extraction** (LLM-based)
   - Free-text understanding
   - Handles natural language
   - Examples: "two burgers and fries"

3. **Tier 3: Fuzzy Matching** (String similarity)
   - Levenshtein distance for typos
   - Handles: "buger" → "burger"
   - Last resort before failure

**Decision Flow:**
```
User Input
    │
    ├─ Contains codes (BG1, SD2)? → Structured Parser
    │
    ├─ Natural language? → AI Extraction
    │   ├─ Confidence > 0.7? → Accept
    │   └─ Confidence < 0.7? → Ask for clarification
    │
    └─ Failed? → Fuzzy Match → Manual help
```

## 3. State Management

### Data Store Schema

**Cart Storage:**
```json
{
  "key": "cart:123456789",
  "value": {
    "items": [
      {"code": "BG1", "name": "Classic Burger", "price": 85, "quantity": 2},
      {"code": "DR1", "name": "Coca Cola", "price": 15, "quantity": 1}
    ],
    "total": 185,
    "updated_at": "2025-11-14T10:30:00Z"
  }
}
```

**Profile Storage:**
```json
{
  "key": "profile:123456789",
  "value": {
    "name": "Ahmed Mohamed",
    "phone": "01012345678",
    "address": "123 Main St, Cairo",
    "delivery_preference": "delivery",
    "created_at": "2025-11-14T10:00:00Z"
  }
}
```

**Order Storage:**
```json
{
  "key": "order:ORD-1731576600-123",
  "value": {
    "order_id": "ORD-1731576600-123",
    "chat_id": "123456789",
    "items": [...],
    "total": 185,
    "customer": {...},
    "status": "pending",
    "created_at": "2025-11-14T10:30:00Z"
  }
}
```

**Checkout State:**
```json
{
  "key": "checkout_state:123456789",
  "value": {
    "step": "collect_name",
    "data": {
      "delivery_type": "delivery"
    }
  }
}
```

### Why This Approach?

1. **Separation of Concerns**: Different data types in different keys
2. **Chat-based Isolation**: Each user has independent state
3. **Atomic Updates**: Single key updates are atomic
4. **Easy Debugging**: Can inspect state in n8n UI
5. **Scalability**: Horizontal scaling possible with key distribution

## 4. Checkout Flow Design

### State Machine Implementation

```
START
  │
  ├─ Empty Cart? → Error + Prompt
  │
  ├─ Ask: Pickup or Delivery?
  │     └─ Save choice → checkout_state
  │
  ├─ Has profile?
  │   ├─ YES → Confirm details → Skip to review
  │   └─ NO → Continue collection
  │
  ├─ Collect Name
  │     └─ Validate: not empty, < 100 chars
  │
  ├─ Collect Phone
  │     └─ Validate: Egyptian format (01xxxxxxxxx)
  │
  ├─ If Delivery: Collect Address
  │     └─ Validate: not empty, > 10 chars
  │
  ├─ Review Order Summary
  │     └─ Confirm or Cancel?
  │
  └─ Confirmed → Generate Order ID → Save → Notify
```

### Validation Rules

**Phone Number:**
```javascript
function validatePhone(phone) {
  // Remove spaces and dashes
  phone = phone.replace(/[\s-]/g, '');
  
  // Egyptian mobile format: 01XXXXXXXXX
  const pattern = /^01[0-9]{9}$/;
  
  if (!pattern.test(phone)) {
    return {
      valid: false,
      error: "الرجاء إدخال رقم موبايل صحيح (مثال: 01012345678)"
    };
  }
  
  return { valid: true, phone: phone };
}
```

**Address (for delivery):**
```javascript
function validateAddress(address) {
  if (address.length < 10) {
    return {
      valid: false,
      error: "الرجاء إدخال عنوان تفصيلي (على الأقل 10 حروف)"
    };
  }
  
  if (address.length > 500) {
    return {
      valid: false,
      error: "العنوان طويل جداً (حد أقصى 500 حرف)"
    };
  }
  
  return { valid: true, address: address };
}
```

## 5. Error Handling Strategy

### Comprehensive Error Coverage

**1. User Input Errors:**
- Empty cart at checkout
- Invalid item codes
- Malformed quantities
- Invalid phone numbers
- Missing address

**Response:**
```javascript
{
  "error": true,
  "message": "عذراً، لم أستطع فهم طلبك. جرب استخدام الأكواد مثل: BG1 x2",
  "suggestions": ["View Menu", "Help"]
}
```

**2. AI Extraction Failures:**
- Model timeout (> 30 seconds)
- Invalid JSON output
- Low confidence (< 0.5)
- Model unavailable

**Fallback:**
```javascript
if (aiExtractionFailed) {
  // Try structured parser
  result = structuredParser(userText);
  
  if (result.items.length === 0) {
    // Try fuzzy matching
    result = fuzzyMatcher(userText, menu);
  }
  
  if (result.items.length === 0) {
    // Give up gracefully
    return helpMessage();
  }
}
```

**3. System Errors:**
- Data Store unavailable
- Webhook timeout
- Network issues

**Response:**
```javascript
{
  "error": true,
  "message": "عذراً، حدث خطأ مؤقت. الرجاء المحاولة مرة أخرى.",
  "retry_after": 5,
  "support": "للمساعدة، اضغط /help"
}
```

### Retry Logic

```javascript
async function withRetry(fn, maxRetries = 3, delay = 1000) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await sleep(delay * (i + 1)); // Exponential backoff
    }
  }
}
```

## 6. Webhook Management

### The Webhook Problem

Telegram webhooks require:
1. **Public HTTPS URL**: Can't use localhost directly
2. **Valid SSL Certificate**: Self-signed won't work
3. **No Duplicate Webhooks**: Only one webhook per bot

### Solution: ngrok

**Why ngrok?**
- Provides public HTTPS URL instantly
- Handles SSL certificates automatically
- Free tier sufficient for development
- Can be replaced with real domain in production

**Setup Process:**
```bash
# 1. Configure ngrok
ngrok config add-authtoken YOUR_TOKEN

# 2. Start tunnel
ngrok http 5678

# 3. Get public URL
WEBHOOK_URL=$(curl -s http://localhost:4040/api/tunnels | \
  jq -r '.tunnels[0].public_url')

# 4. Set webhook
curl -X POST "https://api.telegram.org/botTOKEN/setWebhook" \
  -d "url=$WEBHOOK_URL/webhook/telegram"
```

### Webhook Debugging

**Check Status:**
```bash
curl https://api.telegram.org/botTOKEN/getWebhookInfo
```

**Good Response:**
```json
{
  "ok": true,
  "result": {
    "url": "https://abc123.ngrok.io/webhook/telegram",
    "has_custom_certificate": false,
    "pending_update_count": 0,
    "last_error_date": 0
  }
}
```

**Problem Indicators:**
- `pending_update_count > 0`: Webhook not processing
- `last_error_date`: Recent webhook failures
- `last_error_message`: Specific error details

### Production Alternatives

For production deployment:

1. **Cloud Hosting**: Deploy n8n to AWS/GCP/Azure
2. **Reverse Proxy**: Use nginx with Let's Encrypt
3. **Serverless**: AWS Lambda + API Gateway
4. **n8n Cloud**: Managed n8n hosting

## 7. Performance Optimizations

### Response Time Targets

- **Structured Parsing**: < 500ms
- **AI Extraction**: < 5 seconds
- **Cart Operations**: < 1 second
- **Checkout**: < 2 seconds per step

### Caching Strategy

**Menu Cache:**
```javascript
// Cache menu in memory
const MENU_CACHE = JSON.parse(fs.readFileSync('menu.json'));

function getMenu() {
  return MENU_CACHE; // No disk I/O
}
```

**AI Prompt Cache:**
```javascript
// Pre-build AI prompt template
const AI_PROMPT_TEMPLATE = buildPromptTemplate(MENU_CACHE);

function callAI(userText) {
  const prompt = AI_PROMPT_TEMPLATE.replace('{user_text}', userText);
  return ollama.complete(prompt);
}
```

### Concurrent Request Handling

n8n handles concurrency automatically, but we ensure:

1. **Stateless Operations**: No shared mutable state
2. **Chat-based Isolation**: Each user gets own data
3. **Atomic Updates**: Single Data Store operations
4. **No Race Conditions**: Use chat_id as lock key

## 8. Testing Strategy

### Unit Tests

**Parser Tests:**
```javascript
// test_parser.js
assert(parse("BG1 x2").items[0].quantity === 2);
assert(parse("BG1, SD1").items.length === 2);
assert(parse("invalid").items.length === 0);
```

**Validation Tests:**
```javascript
// test_validation.js
assert(validatePhone("01012345678").valid === true);
assert(validatePhone("123").valid === false);
assert(validateAddress("123 Main St").valid === true);
```

### Integration Tests

**Checkout Flow:**
```javascript
// test_checkout.js
1. Add items to cart
2. Start checkout
3. Submit delivery type
4. Submit name
5. Submit phone
6. Submit address
7. Confirm order
8. Verify order ID
9. Check Data Store
```

### Load Testing

```bash
# Simulate 100 concurrent users
for i in {1..100}; do
  curl -X POST "webhook_url" \
    -d '{"message":{"text":"BG1"}}' &
done
```

## 9. Security Considerations

### Input Sanitization

```javascript
function sanitizeInput(text) {
  // Remove control characters
  text = text.replace(/[\x00-\x1F\x7F]/g, '');
  
  // Limit length
  if (text.length > 1000) {
    text = text.substring(0, 1000);
  }
  
  // Escape HTML
  text = text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  
  return text;
}
```

### Rate Limiting

```javascript
const rateLimiter = new Map();

function checkRateLimit(chatId) {
  const key = `rate:${chatId}`;
  const now = Date.now();
  const requests = rateLimiter.get(key) || [];
  
  // Remove old requests (> 1 minute)
  const recent = requests.filter(t => now - t < 60000);
  
  if (recent.length >= 30) {
    return { allowed: false, retryAfter: 60 };
  }
  
  recent.push(now);
  rateLimiter.set(key, recent);
  
  return { allowed: true };
}
```

### Data Privacy

- **No PII Logging**: Never log names, phones, addresses
- **Encrypted Storage**: Consider encrypting sensitive fields
- **Data Retention**: Auto-delete old orders after 30 days
- **GDPR Compliance**: Provide data export/deletion

## 10. Assumptions & Limitations

### Assumptions

1. **Single Restaurant**: One menu only
2. **EGP Currency**: No multi-currency support
3. **Egyptian Users**: Phone validation for Egypt only
4. **No Payment**: Cash on delivery/pickup only
5. **No Real-time Tracking**: Order status is manual
6. **No Inventory**: Unlimited stock assumed
7. **Single Language UI**: Mixed Arabic/English

### Known Limitations

1. **AI Latency**: 3-8 seconds for LLM inference
2. **ngrok Timeout**: Free tier has 2-hour sessions
3. **No Image Support**: Text-only menu
4. **No Customization**: Can't modify items (no "no pickles")
5. **No Order History**: Can't view past orders
6. **Limited Menu**: 12 items total
7. **No Analytics**: No tracking/reporting

### Future Enhancements

1. **Payment Integration**: Fawry, Paymob, Stripe
2. **Order Tracking**: Real-time status updates
3. **Menu Management**: Admin panel for menu updates
4. **Analytics Dashboard**: Order stats, popular items
5. **Multi-language**: Full Arabic/English support
6. **Image Menu**: Photo-based item selection
7. **Loyalty Program**: Points and rewards
8. **Delivery Integration**: Bosta, Aramex APIs

## 11. Deployment Checklist

### Pre-Production

- [ ] Replace hardcoded tokens with env vars
- [ ] Set up proper SSL certificate
- [ ] Configure production domain
- [ ] Enable rate limiting
- [ ] Set up monitoring (Sentry, Datadog)
- [ ] Configure backups for Data Store
- [ ] Add logging and alerting
- [ ] Load test with expected traffic
- [ ] Security audit
- [ ] GDPR compliance review

### Production

- [ ] Deploy to cloud (AWS/GCP/Azure)
- [ ] Set up auto-scaling
- [ ] Configure CDN for static assets
- [ ] Enable DDoS protection
- [ ] Set up CI/CD pipeline
- [ ] Document runbooks
- [ ] Train support team
- [ ] Create admin dashboard

## Conclusion

This implementation prioritizes:
1. **Reliability**: Comprehensive error handling
2. **Performance**: Fast response times with fallbacks
3. **Usability**: Natural conversation flow
4. **Maintainability**: Clean separation of concerns
5. **Scalability**: Ready for production deployment

The open-source stack (n8n + Ollama) provides:
- **Zero Costs**: No API fees
- **Full Control**: No vendor lock-in
- **Privacy**: Data stays on your servers
- **Customization**: Modify as needed
