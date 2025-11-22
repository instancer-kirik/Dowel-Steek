#!/bin/bash

# Dowel-Steek Mobile OS - Guided UX Development Demo
# Interactive launcher with real-time guidance for UX development

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║                  DOWEL-STEEK MOBILE OS                          ║"
echo "║                 Guided UX Development Demo                       ║"
echo "║                                                                  ║"
echo "║               Interactive Development Environment                 ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}🎯 Welcome to Dowel-Steek Mobile OS UX Development!${NC}"
echo
echo -e "${BLUE}This guided demo will help you explore and develop the mobile OS interface.${NC}"
echo

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
DISPLAY_DIR="$PROJECT_ROOT/mobile-rewrite/display-system"

# Pre-flight check
echo -e "${YELLOW}📋 Pre-flight Check...${NC}"
if [[ ! -f "$DISPLAY_DIR/zig-out/bin/display-demo" ]]; then
    echo -e "${YELLOW}   Building display system...${NC}"
    cd "$DISPLAY_DIR" && zig build install >/dev/null 2>&1
    echo -e "${GREEN}   ✅ Display system ready${NC}"
else
    echo -e "${GREEN}   ✅ Display system ready${NC}"
fi

echo -e "${GREEN}   ✅ SDL2 graphics available${NC}"
echo -e "${GREEN}   ✅ Zig compiler available${NC}"
echo

echo -e "${CYAN}${BOLD}🖥️  What You'll See:${NC}"
echo -e "${BLUE}   📱 Mobile OS Interface${NC} - Complete 1080x2340 mobile display"
echo -e "${BLUE}   🎨 Status Bar${NC} - Time, battery, signal indicators"
echo -e "${BLUE}   🔘 Interactive Buttons${NC} - Settings, Apps, Files (clickable!)"
echo -e "${BLUE}   ✨ Smooth Animations${NC} - Rotating elements and transitions"
echo -e "${BLUE}   📊 Performance Metrics${NC} - Real-time FPS and frame time"
echo -e "${BLUE}   🌈 Color Demonstrations${NC} - Full spectrum gradient display"
echo

echo -e "${MAGENTA}${BOLD}🖱️  How to Interact:${NC}"
echo -e "${CYAN}   • Mouse Click${NC} = Touch simulation on mobile interface"
echo -e "${CYAN}   • Look for 3 buttons${NC} = Settings (gray), Apps (blue), Files (orange)"
echo -e "${CYAN}   • Watch animations${NC} = 5 colored circles rotating in center"
echo -e "${CYAN}   • Check performance${NC} = FPS counter in bottom-left corner"
echo -e "${CYAN}   • Press ESC${NC} = Exit the demo when finished"
echo

echo -e "${YELLOW}${BOLD}🎯 UX Development Goals:${NC}"
echo -e "${GREEN}   1.${NC} Test button interaction and visual feedback"
echo -e "${GREEN}   2.${NC} Evaluate mobile interface layout and spacing"
echo -e "${GREEN}   3.${NC} Assess animation smoothness and appeal"
echo -e "${GREEN}   4.${NC} Check performance metrics for optimization"
echo -e "${GREEN}   5.${NC} Consider color scheme and visual hierarchy"
echo

echo -e "${BLUE}${BOLD}📝 What to Look For:${NC}"
echo -e "   • Are touch targets large enough for comfortable use?"
echo -e "   • Does button feedback feel immediate and clear?"
echo -e "   • Are colors and contrast appropriate for mobile viewing?"
echo -e "   • Do animations enhance or distract from usability?"
echo -e "   • Is the overall layout intuitive and organized?"
echo

echo -e "${CYAN}Press ENTER to launch the mobile OS interface, or Ctrl+C to cancel...${NC}"
read -r

echo
echo -e "${GREEN}🚀 Launching Dowel-Steek Mobile OS Interface...${NC}"
echo
echo -e "${YELLOW}💡 Pro Tips:${NC}"
echo -e "   • The interface IS interactive - click the buttons!"
echo -e "   • Watch the FPS counter to monitor performance"
echo -e "   • Try clicking different areas to test responsiveness"
echo -e "   • Note which design elements work well for mobile"
echo
echo -e "${BLUE}Remember: This is YOUR mobile OS - use this time to evaluate and plan UX improvements!${NC}"
echo
echo -e "${MAGENTA}Starting in 3 seconds... Get ready to interact!${NC}"
sleep 1
echo -e "${MAGENTA}2...${NC}"
sleep 1
echo -e "${MAGENTA}1...${NC}"
sleep 1
echo

# Set environment variables for enhanced experience
export DOWEL_MODE=guided_ux_development
export DOWEL_LOG_LEVEL=info
export SDL_VIDEO_WINDOW_POS=100,50

# Launch with enhanced feedback
cd "$DISPLAY_DIR"

echo -e "${GREEN}✨ Mobile OS Interface launching now!${NC}"
echo -e "${CYAN}   Window should appear - click the buttons and explore!${NC}"
echo -e "${YELLOW}   Press ESC in the demo window when finished.${NC}"
echo

# Run the demo
./zig-out/bin/display-demo

echo
echo -e "${GREEN}${BOLD}🎉 Demo Session Complete!${NC}"
echo
echo -e "${CYAN}📊 UX Development Feedback Questions:${NC}"
echo -e "${BLUE}   • How did the button interactions feel?${NC}"
echo -e "${BLUE}   • Was the mobile interface layout intuitive?${NC}"
echo -e "${BLUE}   • Did the animations enhance the experience?${NC}"
echo -e "${BLUE}   • What would you change about the visual design?${NC}"
echo -e "${BLUE}   • How was the overall performance and responsiveness?${NC}"
echo
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo -e "   • Modify design elements in: ${DISPLAY_DIR}/src/demo.zig"
echo -e "   • Rebuild with: cd ${DISPLAY_DIR} && zig build install"
echo -e "   • Test changes with: ./guided-demo.sh"
echo -e "   • Document successful UX patterns for hardware implementation"
echo
echo -e "${GREEN}Your Dowel-Steek Mobile OS UX development environment is ready for iteration! 🚀${NC}"
