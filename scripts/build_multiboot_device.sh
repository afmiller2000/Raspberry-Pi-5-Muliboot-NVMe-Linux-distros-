#!/bin/bash
################################################################################
# build_multiboot_device.sh
# 
# Purpose: One-shot wrapper that executes all three phases:
#          PREPARE -> ACQUIRE -> INSTALL
#
# Usage: sudo ./build_multiboot_device.sh /dev/nvmeXn1
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (use sudo)"
    exit 1
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}[ERROR]${NC} Usage: $0 <target_device>"
    echo -e "${RED}[ERROR]${NC} Example: $0 /dev/nvme0n1"
    exit 1
fi

TARGET="$1"

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║     Raspberry Pi 5 NVMe Multiboot Device Builder                 ║
║                                                                   ║
║     This will execute all three phases:                          ║
║       1. PREPARE - Partition and format the device               ║
║       2. ACQUIRE - Download OS images and firmware               ║
║       3. INSTALL - Deploy everything to the device               ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Target device: $TARGET${NC}"
echo ""
echo "Press Ctrl+C now to cancel, or"
read -p "Press Enter to begin the build process..."

# Phase 1: PREPARE
echo ""
echo -e "${BLUE}═════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Phase 1/3: PREPARE${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════════════════════${NC}"
echo ""

if ! "$SCRIPT_DIR/prepare.sh" "$TARGET"; then
    echo -e "${RED}[FAILED]${NC} PREPARE phase failed"
    exit 1
fi

# Phase 2: ACQUIRE
echo ""
echo -e "${BLUE}═════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Phase 2/3: ACQUIRE${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════════════════════${NC}"
echo ""

if ! "$SCRIPT_DIR/acquire.sh"; then
    echo -e "${RED}[FAILED]${NC} ACQUIRE phase failed"
    exit 1
fi

# Phase 3: INSTALL
echo ""
echo -e "${BLUE}═════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Phase 3/3: INSTALL${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════════════════════${NC}"
echo ""

if ! "$SCRIPT_DIR/install.sh"; then
    echo -e "${RED}[FAILED]${NC} INSTALL phase failed"
    exit 1
fi

# Success!
echo ""
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                    BUILD COMPLETED SUCCESSFULLY!                  ║
║                                                                   ║
║     Your multiboot NVMe device is ready for Raspberry Pi 5       ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}All three phases completed successfully!${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Unmount all partitions"
echo -e "  2. Safely remove the NVMe device"
echo -e "  3. Install in your Raspberry Pi 5"
echo -e "  4. Boot and select your OS from GRUB menu"
echo ""
echo -e "For details, see:"
echo -e "  $PROJECT_ROOT/artifacts/logs/"
echo ""

exit 0
