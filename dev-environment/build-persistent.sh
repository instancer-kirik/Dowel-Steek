#!/bin/bash

# Dowel-Steek Mobile OS - Build Persistent Demo
# Builds a long-running mobile OS demo that stays open for UX development

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
DEV_ENV_DIR="$PROJECT_ROOT/dev-environment"

echo -e "${BLUE}🔨 Building Dowel-Steek Persistent Mobile OS Demo...${NC}"
echo

# Check dependencies
if ! command -v zig >/dev/null 2>&1; then
    echo -e "${RED}❌ Zig not found. Please install Zig compiler.${NC}"
    exit 1
fi

if ! pkg-config --exists sdl2; then
    echo -e "${RED}❌ SDL2 development libraries not found.${NC}"
    echo "Install with: sudo apt install libsdl2-dev"
    exit 1
fi

echo -e "${GREEN}✅ Dependencies found${NC}"

# Build the persistent demo
echo -e "${YELLOW}Building persistent mobile OS demo...${NC}"

cd "$DEV_ENV_DIR"

# Build command
zig build-exe mobile-os-persistent.zig \
    -lc \
    -lSDL2 \
    --name mobile-os-persistent \
    -O ReleaseFast

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo
    echo -e "${BLUE}📱 Persistent Mobile OS Demo built:${NC}"
    echo "   Executable: $DEV_ENV_DIR/mobile-os-persistent"
    echo "   Features: Long-running, interactive mobile OS interface"
    echo "   Controls: Mouse for touch, ESC to exit, BACKSPACE for back"
    echo
    echo -e "${YELLOW}🚀 Launch with:${NC}"
    echo "   ./mobile-os-persistent"
    echo
    echo -e "${CYAN}This demo provides:${NC}"
    echo "   • Persistent mobile OS interface (doesn't exit quickly)"
    echo "   • Multiple app screens (Launcher, Settings, Files, Calculator, Camera)"
    echo "   • Interactive buttons with visual feedback"
    echo "   • Real-time performance monitoring"
    echo "   • Zig-Kotlin integration status display"
    echo "   • Touch simulation via mouse input"
    echo "   • Smooth animations and transitions"
    echo
    echo -e "${GREEN}Perfect for extended UX development sessions! 🎨${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi
