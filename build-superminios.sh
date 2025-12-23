#!/bin/bash
# ============================================
#  ███████╗██╗   ██╗██████╗ ███████╗██████╗ 
#  ██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗
#  ███████╗██║   ██║██████╔╝█████╗  ██████╔╝
#  ╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗
#  ███████║╚██████╔╝██║     ███████╗██║  ██║
#  ╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝
#  ███╗   ███╗██╗███╗   ██╗██╗ ██████╗ ███████╗
#  ████╗ ████║██║████╗  ██║██║██╔═══██╗██╔════╝
#  ██╔████╔██║██║██╔██╗ ██║██║██║   ██║███████╗
#  ██║╚██╔╝██║██║██║╚██╗██║██║██║   ██║╚════██║
#  ██║ ╚═╝ ██║██║██║ ╚████║██║╚██████╔╝███████║
#  ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚══════╝
#            Gaming Edition Builder
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
echo "  ║   ███████╗██╗   ██╗██████╗ ███████╗██████╗                ║"
echo "  ║   ██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗               ║"
echo "  ║   ███████╗██║   ██║██████╔╝█████╗  ██████╔╝               ║"
echo "  ║   ╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗               ║"
echo "  ║   ███████║╚██████╔╝██║     ███████╗██║  ██║               ║"
echo "  ║   ╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝               ║"
echo "  ║   ███╗   ███╗██╗███╗   ██╗██╗ ██████╗ ███████╗            ║"
echo "  ║   ████╗ ████║██║████╗  ██║██║██╔═══██╗██╔════╝            ║"
echo "  ║   ██╔████╔██║██║██╔██╗ ██║██║██║   ██║███████╗            ║"
echo "  ║   ██║╚██╔╝██║██║██║╚██╗██║██║██║   ██║╚════██║            ║"
echo "  ║   ██║ ╚═╝ ██║██║██║ ╚████║██║╚██████╔╝███████║            ║"
echo "  ║   ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚══════╝            ║"
echo "  ║                                                           ║"
echo "  ║              🎮 Gaming Edition Builder 🎮                 ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (sudo)${NC}"
    echo "Usage: sudo ./build-superminios.sh"
    exit 1
fi

# Set build config
export BUILD_CONF="$(pwd)/linux-live/build-gaming.conf"

echo -e "${YELLOW}Build Configuration:${NC} $BUILD_CONF"
echo ""
echo -e "${GREEN}┌─────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${NC}  ${CYAN}Distribution:${NC}  Debian Bookworm    ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}  ${CYAN}Desktop:${NC}       Flux (Fluxbox)     ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}  ${CYAN}Variant:${NC}       Gaming Edition     ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}  ${CYAN}Architecture:${NC}  amd64              ${GREEN}│${NC}"
echo -e "${GREEN}├─────────────────────────────────────┤${NC}"
echo -e "${GREEN}│${NC}  ${CYAN}Includes:${NC}                         ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}    ✓ Steam                         ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}    ✓ Lutris                        ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}    ✓ Wine                          ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}    ✓ Mesa/Vulkan drivers           ${GREEN}│${NC}"
echo -e "${GREEN}│${NC}    ✓ Dev tools (git, gcc, python)  ${GREEN}│${NC}"
echo -e "${GREEN}└─────────────────────────────────────┘${NC}"
echo ""
echo -e "${YELLOW}Starting build in 5 seconds... (Ctrl+C to cancel)${NC}"
sleep 5

# Run the build
./minios-live -

echo ""
echo -e "${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
echo "  ║              ✅ BUILD COMPLETE! ✅                        ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${CYAN}ISO location:${NC} ./build/iso/"
echo ""
echo -e "${YELLOW}To test in VirtualBox:${NC}"
echo "  1. Create new VM (Linux/Debian 64-bit)"
echo "  2. RAM: 2GB minimum, 4GB recommended"
echo "  3. Mount the ISO and boot"
echo ""
echo -e "${GREEN}Default credentials:${NC}"
echo "  User: gamer"
echo "  Password: evil"
echo ""
