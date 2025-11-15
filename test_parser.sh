#!/bin/bash

# Food Ordering Bot - Parser Test Suite
# Tests structured parsing of item codes

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${BLUE}=== Parser Test Suite ===${NC}\n"

# Test function
test_parse() {
    local test_name=$1
    local input=$2
    local expected=$3
    
    # Call parser (simulated - replace with actual parser call)
    result=$(node -e "
        const text = '$input';
        const regex = /(BG|SD|DR)(\d+)(?:\s*x\s*(\d+))?/gi;
        const matches = [...text.matchAll(regex)];
        
        const items = matches.map(m => ({
            code: m[1] + m[2],
            quantity: m[3] ? parseInt(m[3]) : 1
        }));
        
        console.log(JSON.stringify(items));
    ")
    
    echo -e "${YELLOW}Test: $test_name${NC}"
    echo -e "Input:    '$input'"
    echo -e "Expected: $expected"
    echo -e "Result:   $result"
    
    if [ "$result" = "$expected" ]; then
        echo -e "${GREEN}✓ PASSED${NC}\n"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}\n"
        ((FAILED++))
    fi
}

# Run tests
echo -e "${BLUE}1. Single Item Tests${NC}\n"

test_parse "Single item no quantity" \
    "BG1" \
    '[{"code":"BG1","quantity":1}]'

test_parse "Single item with quantity" \
    "BG1 x2" \
    '[{"code":"BG1","quantity":2}]'

test_parse "Single item with spaces" \
    "BG1  x  2" \
    '[{"code":"BG1","quantity":2}]'

echo -e "${BLUE}2. Multiple Items Tests${NC}\n"

test_parse "Multiple items comma separated" \
    "BG1, SD1, DR1" \
    '[{"code":"BG1","quantity":1},{"code":"SD1","quantity":1},{"code":"DR1","quantity":1}]'

test_parse "Multiple items with quantities" \
    "BG1 x2, SD1 x3, DR1" \
    '[{"code":"BG1","quantity":2},{"code":"SD1","quantity":3},{"code":"DR1","quantity":1}]'

test_parse "Multiple items mixed" \
    "BG1, BG2 x2, SD1 x3" \
    '[{"code":"BG1","quantity":1},{"code":"BG2","quantity":2},{"code":"SD1","quantity":3}]'

echo -e "${BLUE}3. Edge Cases${NC}\n"

test_parse "No spaces" \
    "BG1x2,SD1x3" \
    '[{"code":"BG1","quantity":2},{"code":"SD1","quantity":3}]'

test_parse "Extra spaces" \
    "BG1   x   2  ,  SD1   x   3" \
    '[{"code":"BG1","quantity":2},{"code":"SD1","quantity":3}]'

test_parse "Uppercase lowercase mix" \
    "Bg1 X 2, sd1 X 3" \
    '[{"code":"BG1","quantity":2},{"code":"SD1","quantity":3}]'

test_parse "With text around" \
    "I want BG1 x2 and SD1 please" \
    '[{"code":"BG1","quantity":2},{"code":"SD1","quantity":1}]'

echo -e "${BLUE}4. Invalid Input Tests${NC}\n"

test_parse "Invalid code" \
    "XYZ123" \
    '[]'

test_parse "Empty string" \
    "" \
    '[]'

test_parse "Only text" \
    "I want a burger" \
    '[]'

test_parse "Invalid format" \
    "BG1 2 x" \
    '[{"code":"BG1","quantity":1}]'

echo -e "${BLUE}5. Real World Examples${NC}\n"

test_parse "Typical order" \
    "BG1 x2, SD1, DR1 x2" \
    '[{"code":"BG1","quantity":2},{"code":"SD1","quantity":1},{"code":"DR1","quantity":2}]'

test_parse "Large order" \
    "BG1 x3, BG2 x2, SD1 x5, SD2 x3, DR1 x4, DR2 x2" \
    '[{"code":"BG1","quantity":3},{"code":"BG2","quantity":2},{"code":"SD1","quantity":5},{"code":"SD2","quantity":3},{"code":"DR1","quantity":4},{"code":"DR2","quantity":2}]'

test_parse "Mixed with natural language" \
    "can i get BG1 x2 and also SD1 thanks" \
    '[{"code":"BG1","quantity":2},{"code":"SD1","quantity":1}]'

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}"
    exit 1
fi
