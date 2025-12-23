#!/bin/bash
# ============================================
# SuperMiniOS Gaming Edition - Build Script
# ============================================
# Lightweight gaming + coding distribution
# Based on MiniOS with Flux desktop
# ============================================

set -e

echo "============================================"
echo "  SuperMiniOS Gaming Edition Builder"
echo "============================================"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (sudo)"
    echo "Usage: sudo ./build-superminios.sh"
    exit 1
fi

# Set build config
export BUILD_CONF="$(pwd)/linux-live/build-gaming.conf"

echo "Build Configuration: $BUILD_CONF"
echo ""
echo "Settings:"
echo "  - Distribution: Debian Bookworm"
echo "  - Desktop: Flux (Fluxbox)"
echo "  - Variant: Minimum + Gaming"
echo "  - Architecture: amd64"
echo ""
echo "Starting build in 5 seconds... (Ctrl+C to cancel)"
sleep 5

# Run the build
./minios-live -

echo ""
echo "============================================"
echo "  Build Complete!"
echo "============================================"
echo ""
echo "ISO location: ./build/iso/"
echo ""
echo "To test in VirtualBox:"
echo "  1. Create new VM (Linux/Debian 64-bit)"
echo "  2. RAM: 2GB minimum, 4GB recommended"
echo "  3. Mount the ISO and boot"
echo ""
