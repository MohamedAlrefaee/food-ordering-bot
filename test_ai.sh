#!/bin/bash

# Food Ordering Bot - AI Extraction Test Suite
# Tests Ollama AI extraction of food items

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

OLLAMA_URL="http://localhost:11434/v1/chat/completions"
MODEL="llama3.1:8b"

PASSED=0
FAILED=0

echo -e "${BLUE}=== AI Extraction Test Suite ===${NC}\n"

# Test function
test_ai_extraction() {
    local test_name=$1
    local input=$2
    local expected_codes=$3
    
    echo -e "${YELLOW}Test: $test_name${NC}"
    echo -e "Input: '$input'"
    
    # Build prompt
    PROMPT="You are a food ordering assistant. Extract items from user text and return ONLY valid JSON. Available items: BG1=Classic Burger(85), BG2=Chicken Burger(75), BG3=Cheese Burger(95), BG4=BBQ Burger(105), SD1=French Fries(30), SD2=Onion Rings(35), SD3=Coleslaw(25), SD4=Mozzarella Sticks(45), DR1=Coca Cola(15), DR2=Orange Juice(25), DR3=Water(10), DR4=Sprite(15). Arabic names: برجر كلاسيك=BG1, برجر دجاج=BG2, تشيز برجر=BG3, برجر باربيكيو=BG4, بطاطس محمرة=SD1, حلقات البصل=SD2, كول سلو=SD3, كوكاكولا=DR1, عصير برتقال=DR2, مياه=DR3, سبرايت=DR4. Return ONLY: {\"items\": [{\"code\": \"BG1\", \"quantity\": 2}]}"
    
    # Call Ollama API
    RESPONSE=$(curl -s -X POST "$OLLAMA_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$MODEL\",
            \"messages\": [
                {\"role\": \"system\", \"content\": \"$PROMPT\"},
                {\"role\": \"user\", \"content\": \"$input\"}
            ],
            \"temperature\": 0.1
        }" 2>/dev/null)
    
    # Check if Ollama is responding
    if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
        echo -e "${RED}✗ FAILED - Ollama not responding${NC}\n"
        ((FAILED++))
        return
    fi
    
    # Extract content
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)
    
    if [ -z "$CONTENT" ] || [ "$CONTENT" = "null" ]; then
        echo -e "${RED}✗ FAILED - Invalid response format${NC}\n"
        ((FAILED++))
        return
    fi
    
    # Clean and parse JSON
    CLEANED=$(echo "$CONTENT" | sed 's/```json//g' | sed 's/```//g' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract codes
    CODES=$(echo "$CLEANED" | jq -r '.items[].code' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    echo -e "Expected: $expected_codes"
    echo -e "Result:   $CODES"
    
    if [ "$CODES" = "$expected_codes" ]; then
        echo -e "${GREEN}✓ PASSED${NC}\n"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "Raw Response: $CLEANED\n"
        ((FAILED++))
    fi
}

# Check if Ollama is running
echo -e "${BLUE}Checking Ollama availability...${NC}"
HEALTH=$(curl -s http://localhost:11434/api/tags 2>/dev/null)
if [ -z "$HEALTH" ]; then
    echo -e "${RED}ERROR: Ollama is not running!${NC}"
    echo -e "Start Ollama with: docker start ollama"
    exit 1
fi
echo -e "${GREEN}Ollama is running ✓${NC}\n"

# Check if model is available
echo -e "${BLUE}Checking model availability...${NC}"
MODELS=$(curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null)
if ! echo "$MODELS" | grep -q "llama3.1:8b"; then
    echo -e "${RED}ERROR: Model llama3.1:8b not found!${NC}"
    echo -e "Pull model with: docker exec ollama ollama pull llama3.1:8b"
    exit 1
fi
echo -e "${GREEN}Model llama3.1:8b found ✓${NC}\n"

sleep 2

# Run tests
echo -e "${BLUE}1. English Natural Language Tests${NC}\n"

test_ai_extraction "Simple burger order" \
    "I want a burger" \
    "BG1"

test_ai_extraction "Two burgers" \
    "I want two burgers" \
    "BG1"

test_ai_extraction "Specific burger type" \
    "I want a chicken burger" \
    "BG2"

test_ai_extraction "Multiple items" \
    "I want two chicken burgers and fries" \
    "BG2,SD1"

test_ai_extraction "Complex order" \
    "give me two classic burgers, one cheese burger, fries and a coke" \
    "BG1,BG3,SD1,DR1"

echo -e "${BLUE}2. Arabic Natural Language Tests${NC}\n"

test_ai_extraction "Arabic simple" \
    "عايز برجر" \
    "BG1"

test_ai_extraction "Arabic with quantity" \
    "عايز اتنين برجر كلاسيك" \
    "BG1"

test_ai_extraction "Arabic multiple items" \
    "عايز برجر دجاج و بطاطس" \
    "BG2,SD1"

test_ai_extraction "Arabic complex" \
    "عايز اتنين برجر كلاسيك و برجر دجاج و بطاطس و كوكاكولا" \
    "BG1,BG2,SD1,DR1"

echo -e "${BLUE}3. Mixed Language Tests${NC}\n"

test_ai_extraction "Mixed English-Arabic" \
    "I want برجر and fries" \
    "BG1,SD1"

test_ai_extraction "Arabic with English items" \
    "عايز chicken burger و cola" \
    "BG2,DR1"

echo -e "${BLUE}4. Edge Cases${NC}\n"

test_ai_extraction "Casual language" \
    "can i get a burger please?" \
    "BG1"

test_ai_extraction "With extra words" \
    "hello, I would like to order two burgers and some fries, thank you" \
    "BG1,SD1"

test_ai_extraction "Misspelling" \
    "I want a buger and frys" \
    "BG1,SD1"

echo -e "${BLUE}5. Negative Tests${NC}\n"

test_ai_extraction "Invalid item" \
    "I want pizza" \
    ""

test_ai_extraction "Only greeting" \
    "hello there" \
    ""

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All AI tests passed! ✓${NC}"
    echo -e "\nPerformance notes:"
    echo -e "- Average response time: 3-8 seconds"
    echo -e "- Accuracy: High for common phrases"
    echo -e "- Handles both English and Arabic"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}"
    echo -e "\nTroubleshooting:"
    echo -e "1. Check Ollama logs: docker logs ollama"
    echo -e "2. Restart Ollama: docker restart ollama"
    echo -e "3. Re-pull model: docker exec ollama ollama pull llama3.1:8b"
    echo -e "4. Check temperature setting (lower = more consistent)"
    exit 1
fi
