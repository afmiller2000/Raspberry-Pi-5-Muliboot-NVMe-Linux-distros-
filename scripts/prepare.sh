#!/bin/bash
################################################################################
# prepare.sh
# 
# Purpose: PREPARE phase - wipe + partition + format + labels + mount
#          Destructive operation that prepares a single NVMe device for
#          multi-boot environment
#
# Usage: sudo ./prepare.sh /dev/nvmeXn1
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/artifacts/logs"
LOG_FILE="$LOG_DIR/prepare_$(date +%Y%m%d_%H%M%S).log"
MOUNT_BASE="/mnt/multiboot"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    log_error "Usage: $0 <target_device>"
    log_error "Example: $0 /dev/nvme0n1"
    exit 1
fi

TARGET="$1"

# Validate target device
if [[ ! -b "$TARGET" ]]; then
    log_error "Target device $TARGET does not exist or is not a block device"
    exit 1
fi

# Safety confirmation
log_warning "==================================================================="
log_warning "DESTRUCTIVE OPERATION WARNING"
log_warning "==================================================================="
log_warning "This will DESTROY ALL DATA on: $TARGET"
log_warning ""
log_warning "Target device information:"
lsblk "$TARGET" 2>&1 | tee -a "$LOG_FILE"
log_warning ""
log_warning "==================================================================="
echo -n "Type 'YES' in capital letters to confirm: "
read -r CONFIRMATION

if [[ "$CONFIRMATION" != "YES" ]]; then
    log_error "Operation cancelled by user"
    exit 1
fi

log "Starting PREPARE phase for $TARGET"

# Unmount any existing partitions on target
log "Unmounting any existing partitions on $TARGET..."
for part in "${TARGET}"*[0-9]; do
    if [[ -b "$part" ]]; then
        umount "$part" 2>/dev/null || true
    fi
done

# Wipe existing structures
log "Wiping existing partition table..."
wipefs -a "$TARGET" 2>&1 | tee -a "$LOG_FILE" || true
dd if=/dev/zero of="$TARGET" bs=1M count=10 status=progress 2>&1 | tee -a "$LOG_FILE"
sync

# Create new GPT partition table
log "Creating new GPT partition table..."
parted -s "$TARGET" mklabel gpt 2>&1 | tee -a "$LOG_FILE"

# Create partitions
# Example layout (adjust sizes as needed):
# 1. FIRMWARE_A: 512MB FAT32 (firmware blobs + config.txt)
# 2. BOOT_GRUB: 1GB ext4 (GRUB + kernels)
# 3. KUBUNTU: 40GB ext4 (Kubuntu rootfs)
# 4. FEDORA: 40GB ext4 (Fedora rootfs)
# 5. DATA: 50GB exFAT (shared user data)
# 6. SWAP: 8GB swap (optional)
# Remaining space can be left for additional distros

log "Creating partitions..."

# FIRMWARE_A partition (512MB)
parted -s "$TARGET" mkpart primary fat32 1MiB 513MiB 2>&1 | tee -a "$LOG_FILE"
parted -s "$TARGET" set 1 boot on 2>&1 | tee -a "$LOG_FILE"

# BOOT_GRUB partition (1GB)
parted -s "$TARGET" mkpart primary ext4 513MiB 1537MiB 2>&1 | tee -a "$LOG_FILE"

# KUBUNTU partition (40GB)
parted -s "$TARGET" mkpart primary ext4 1537MiB 42497MiB 2>&1 | tee -a "$LOG_FILE"

# FEDORA partition (40GB)
parted -s "$TARGET" mkpart primary ext4 42497MiB 83457MiB 2>&1 | tee -a "$LOG_FILE"

# DATA partition (50GB)
parted -s "$TARGET" mkpart primary 83457MiB 134657MiB 2>&1 | tee -a "$LOG_FILE"

# SWAP partition (8GB)
parted -s "$TARGET" mkpart primary linux-swap 134657MiB 142849MiB 2>&1 | tee -a "$LOG_FILE"

sync
sleep 2

# Determine partition device names
if [[ "$TARGET" == *"nvme"* ]]; then
    PART_PREFIX="${TARGET}p"
else
    PART_PREFIX="${TARGET}"
fi

PART1="${PART_PREFIX}1"
PART2="${PART_PREFIX}2"
PART3="${PART_PREFIX}3"
PART4="${PART_PREFIX}4"
PART5="${PART_PREFIX}5"
PART6="${PART_PREFIX}6"

# Wait for partitions to appear
log "Waiting for partition devices to be ready..."
for i in {1..10}; do
    if [[ -b "$PART1" ]]; then
        break
    fi
    sleep 1
done

# Create filesystems
log "Creating filesystems..."

log "  Creating FAT32 filesystem on $PART1 (FIRMWARE_A)..."
mkfs.vfat -F 32 -n FIRMWARE_A "$PART1" 2>&1 | tee -a "$LOG_FILE"

log "  Creating ext4 filesystem on $PART2 (BOOT_GRUB)..."
mkfs.ext4 -F -L BOOT_GRUB "$PART2" 2>&1 | tee -a "$LOG_FILE"

log "  Creating ext4 filesystem on $PART3 (KUBUNTU)..."
mkfs.ext4 -F -L KUBUNTU "$PART3" 2>&1 | tee -a "$LOG_FILE"

log "  Creating ext4 filesystem on $PART4 (FEDORA)..."
mkfs.ext4 -F -L FEDORA "$PART4" 2>&1 | tee -a "$LOG_FILE"

log "  Creating exFAT filesystem on $PART5 (DATA)..."
mkfs.exfat -n DATA "$PART5" 2>&1 | tee -a "$LOG_FILE"

log "  Creating swap on $PART6 (SWAP)..."
mkswap -L SWAP "$PART6" 2>&1 | tee -a "$LOG_FILE"

sync

# Create mount points and mount partitions
log "Creating mount points and mounting partitions..."

mkdir -p "$MOUNT_BASE"/{firmware,boot,kubuntu,fedora,data}

mount "$PART1" "$MOUNT_BASE/firmware" 2>&1 | tee -a "$LOG_FILE"
mount "$PART2" "$MOUNT_BASE/boot" 2>&1 | tee -a "$LOG_FILE"
mount "$PART3" "$MOUNT_BASE/kubuntu" 2>&1 | tee -a "$LOG_FILE"
mount "$PART4" "$MOUNT_BASE/fedora" 2>&1 | tee -a "$LOG_FILE"
mount "$PART5" "$MOUNT_BASE/data" 2>&1 | tee -a "$LOG_FILE"

# Enable swap
swapon "$PART6" 2>&1 | tee -a "$LOG_FILE" || true

# Record partition map
PARTITION_MAP="$LOG_DIR/partition_map.txt"
log "Recording partition map to $PARTITION_MAP..."
cat > "$PARTITION_MAP" <<EOF
# Partition Map for $TARGET
# Created: $(date)

TARGET_DEVICE=$TARGET
FIRMWARE_PARTITION=$PART1
BOOT_PARTITION=$PART2
KUBUNTU_PARTITION=$PART3
FEDORA_PARTITION=$PART4
DATA_PARTITION=$PART5
SWAP_PARTITION=$PART6

MOUNT_FIRMWARE=$MOUNT_BASE/firmware
MOUNT_BOOT=$MOUNT_BASE/boot
MOUNT_KUBUNTU=$MOUNT_BASE/kubuntu
MOUNT_FEDORA=$MOUNT_BASE/fedora
MOUNT_DATA=$MOUNT_BASE/data
EOF

# Display final partition layout
log "Final partition layout:"
lsblk "$TARGET" 2>&1 | tee -a "$LOG_FILE"

log_success "==================================================================="
log_success "PREPARE phase completed successfully!"
log_success "==================================================================="
log_success "Partitions have been created, formatted, labeled, and mounted:"
log_success "  FIRMWARE_A: $PART1 -> $MOUNT_BASE/firmware"
log_success "  BOOT_GRUB:  $PART2 -> $MOUNT_BASE/boot"
log_success "  KUBUNTU:    $PART3 -> $MOUNT_BASE/kubuntu"
log_success "  FEDORA:     $PART4 -> $MOUNT_BASE/fedora"
log_success "  DATA:       $PART5 -> $MOUNT_BASE/data"
log_success "  SWAP:       $PART6 (active)"
log_success ""
log_success "Partition map saved to: $PARTITION_MAP"
log_success "Log file: $LOG_FILE"
log_success ""
log_success "Next step: Run acquire.sh to download OS images and firmware"
log_success "==================================================================="

exit 0
