#!/bin/bash

# Test script for ChatGPT Viewer
# This script tests various ways to launch the viewer

echo "ChatGPT Viewer Test Script"
echo "=========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if the viewer executable exists
if [ ! -f "./chatgpt-viewer" ]; then
    echo -e "${RED}Error: chatgpt-viewer executable not found!${NC}"
    echo "Please build it first with: dub build --config=chatgpt_viewer"
    exit 1
fi

echo -e "${GREEN}✓ Found chatgpt-viewer executable${NC}"
echo ""

# Test 1: Check Jan directory
echo "Test 1: Checking for Jan conversations..."
JAN_PATH="$HOME/.local/share/Jan/data/conversations.json"
if [ -f "$JAN_PATH" ]; then
    echo -e "${GREEN}✓ Found Jan conversations at: $JAN_PATH${NC}"
    FILE_SIZE=$(du -h "$JAN_PATH" | cut -f1)
    echo "  File size: $FILE_SIZE"
else
    echo -e "${YELLOW}⚠ No Jan conversations found at: $JAN_PATH${NC}"
fi
echo ""

# Test 2: Check other common locations
echo "Test 2: Checking other common locations..."
LOCATIONS=(
    "$HOME/Downloads/conversations.json"
    "$HOME/Documents/conversations.json"
    "$HOME/Desktop/conversations.json"
    "$HOME/chatgpt-conversations.json"
    "$HOME/conversations.json"
)

FOUND_ANY=false
for LOC in "${LOCATIONS[@]}"; do
    if [ -f "$LOC" ]; then
        echo -e "${GREEN}✓ Found conversations at: $LOC${NC}"
        FILE_SIZE=$(du -h "$LOC" | cut -f1)
        echo "  File size: $FILE_SIZE"
        FOUND_ANY=true
    fi
done

if [ "$FOUND_ANY" = false ]; then
    echo -e "${YELLOW}⚠ No conversations found in common locations${NC}"
fi
echo ""

# Test 3: Launch modes
echo "Test 3: Testing launch modes..."
echo ""
echo "Choose a test mode:"
echo "1) Launch with auto-detection (no arguments)"
echo "2) Launch with --jan flag"
echo "3) Launch with --file flag (you'll need to specify a file)"
echo "4) Launch with --inspect flag (inspect JSON structure)"
echo "5) Launch with --help (show help)"
echo "6) Launch with --debug (verbose output)"
echo "7) Exit"
echo ""
read -p "Enter choice (1-7): " choice

case $choice in
    1)
        echo "Launching with auto-detection..."
        ./chatgpt-viewer
        ;;
    2)
        echo "Launching with --jan flag..."
        ./chatgpt-viewer --jan
        ;;
    3)
        read -p "Enter path to conversations file: " FILE_PATH
        if [ -f "$FILE_PATH" ]; then
            echo "Launching with file: $FILE_PATH"
            ./chatgpt-viewer --file="$FILE_PATH"
        else
            echo -e "${RED}Error: File not found: $FILE_PATH${NC}"
        fi
        ;;
    4)
        read -p "Enter path to JSON file to inspect: " FILE_PATH
        if [ -f "$FILE_PATH" ]; then
            echo "Inspecting file: $FILE_PATH"
            ./chatgpt-viewer --inspect="$FILE_PATH"
        else
            echo -e "${RED}Error: File not found: $FILE_PATH${NC}"
        fi
        ;;
    5)
        echo "Showing help..."
        ./chatgpt-viewer --help
        ;;
    6)
        echo "Launching with debug output..."
        echo "Choose debug mode:"
        echo "1) Debug with auto-detection"
        echo "2) Debug with --jan"
        read -p "Enter choice (1-2): " debug_choice
        case $debug_choice in
            1)
                ./chatgpt-viewer --debug
                ;;
            2)
                ./chatgpt-viewer --jan --debug
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
        ;;
    7)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        ;;
esac

echo ""
echo "Test completed."
