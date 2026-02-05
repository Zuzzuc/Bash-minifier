#!/usr/bin/env bash
# Visual comparison tool for test results
# Usage: ./compare_tests.sh [test_number]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test"
MINIFY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Minify.sh"

# Track test failures
FAILED_TESTS=0

# Function to run a single test comparison
compare_test() {
    local input_file="$1"
    local test_name=$(basename "$input_file")
    local expected_file="$TEST_DIR/expected/$test_name"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Test: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "\n${YELLOW}INPUT:${NC}"
    cat "$input_file"

    echo -e "\n${YELLOW}EXPECTED OUTPUT:${NC}"
    cat "$expected_file"

    echo -e "\n${YELLOW}ACTUAL OUTPUT:${NC}"
    local actual=$("$MINIFY_SCRIPT" -f="$input_file" -F 2>/dev/null)
    echo "$actual"

    echo -e "\n${YELLOW}COMPARISON:${NC}"
    local expected_content=$(cat "$expected_file")
    if [ "$actual" == "$expected_content" ]; then
        echo -e "${GREEN}✓ MATCH - Test passes!${NC}"
    else
        echo -e "${RED}✗ MISMATCH - Test fails!${NC}"
        echo -e "\n${YELLOW}Differences:${NC}"
        echo -e "${RED}Expected body (line 2):${NC}"
        echo "$expected_content" | tail -n 1
        echo -e "${RED}Actual body (line 2):${NC}"
        echo "$actual" | tail -n 1
        FAILED_TESTS=1
    fi
    echo ""
}

# Main execution
if [ -n "$1" ]; then
    # Run specific test by number (e.g., ./compare_tests.sh 02)
    test_file="$TEST_DIR/input/${1}_*.sh"
    if ls $test_file 1> /dev/null 2>&1; then
        for f in $test_file; do
            compare_test "$f"
        done
    else
        echo -e "${RED}Test file matching '${1}' not found!${NC}"
        exit 1
    fi
else
    # Run all tests
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}        Bash Minifier - Visual Test Comparison${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    for input_file in "$TEST_DIR/input"/*.sh; do
        compare_test "$input_file"
    done

    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Comparison complete!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
fi

exit $FAILED_TESTS
