#!/bin/bash
################################################################################
# acquire.sh
# 
# Purpose: ACQUIRE phase - download OS images + fetch/stage firmware + write config
#          Non-destructive operation that downloads and prepares all artifacts
#
# Usage: ./acquire.sh
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/artifacts/logs"
LOG_FILE="$LOG_DIR/acquire_$(date +%Y%m%d_%H%M%S).log"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
FIRMWARE_DIR="$ARTIFACTS_DIR/firmware"
CHECKSUMS_DIR="$ARTIFACTS_DIR/checksums"
IMAGES_DIR="$ARTIFACTS_DIR/images"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$FIRMWARE_DIR" "$CHECKSUMS_DIR" "$IMAGES_DIR"

# Logging functions
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

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

# Download with retry
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    
    log_info "Downloading: $url"
    log_info "  to: $output"
    
    while [[ $retry -lt $max_retries ]]; do
        if wget -c -O "$output" "$url" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "  Download completed"
            return 0
        else
            retry=$((retry + 1))
            log_warning "  Download failed (attempt $retry/$max_retries)"
            sleep 5
        fi
    done
    
    log_error "  Failed to download after $max_retries attempts"
    return 1
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local checksum_file="$2"
    
    if [[ ! -f "$checksum_file" ]]; then
        log_warning "  Checksum file not found: $checksum_file (skipping verification)"
        return 0
    fi
    
    log_info "Verifying checksum for $(basename "$file")..."
    
    # Determine checksum type and verify
    if sha256sum -c "$checksum_file" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "  Checksum verification passed"
        return 0
    else
        log_error "  Checksum verification failed"
        return 1
    fi
}

log "==================================================================="
log "Starting ACQUIRE phase"
log "==================================================================="

# OS Images to download
# TODO: Add actual URLs and checksums for your target OS images
# These are examples - replace with actual distribution URLs

log "Phase 1: Downloading OS Images"
log "-------------------------------------------------------------------"

# Example: Kubuntu (Ubuntu for Raspberry Pi)
# TODO: Replace with actual Kubuntu image URL
KUBUNTU_URL="https://cdimage.ubuntu.com/releases/23.10/release/ubuntu-23.10-preinstalled-desktop-arm64+raspi.img.xz"
KUBUNTU_IMG="$IMAGES_DIR/kubuntu-raspi.img.xz"
KUBUNTU_CHECKSUM="$CHECKSUMS_DIR/kubuntu-raspi.sha256"

log_info "NOTE: Using example URLs - update with actual distribution URLs"
log_info "Kubuntu image download (commented out for safety)"
# Uncomment when actual URLs are configured:
# if [[ ! -f "$KUBUNTU_IMG" ]]; then
#     download_file "$KUBUNTU_URL" "$KUBUNTU_IMG" || log_error "Failed to download Kubuntu"
# else
#     log_info "Kubuntu image already exists: $KUBUNTU_IMG"
# fi

# Example: Fedora for Raspberry Pi
# TODO: Replace with actual Fedora image URL
FEDORA_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/39/Spins/aarch64/images/Fedora-Minimal-39-1.5.aarch64.raw.xz"
FEDORA_IMG="$IMAGES_DIR/fedora-raspi.img.xz"
FEDORA_CHECKSUM="$CHECKSUMS_DIR/fedora-raspi.sha256"

log_info "Fedora image download (commented out for safety)"
# Uncomment when actual URLs are configured:
# if [[ ! -f "$FEDORA_IMG" ]]; then
#     download_file "$FEDORA_URL" "$FEDORA_IMG" || log_error "Failed to download Fedora"
# else
#     log_info "Fedora image already exists: $FEDORA_IMG"
# fi

log_info "Creating placeholder checksum files..."
cat > "$CHECKSUMS_DIR/README.md" <<EOF
# Checksums Directory

Place SHA256 checksum files here for downloaded images.

Format: One line per file containing:
\`\`\`
<sha256sum>  <filename>
\`\`\`

Example files:
- kubuntu-raspi.sha256
- fedora-raspi.sha256

To generate checksums:
\`\`\`bash
sha256sum filename > filename.sha256
\`\`\`
EOF

log "Phase 2: Fetching Raspberry Pi Firmware"
log "-------------------------------------------------------------------"

# Raspberry Pi firmware repository
FIRMWARE_REPO="https://github.com/raspberrypi/firmware/raw/master/boot"

# Essential firmware files for Raspberry Pi 5
declare -a FIRMWARE_FILES=(
    "start4.elf"
    "start4x.elf"
    "start4cd.elf"
    "start4db.elf"
    "fixup4.dat"
    "fixup4x.dat"
    "fixup4cd.dat"
    "fixup4db.dat"
    "bootcode.bin"
    "bcm2711-rpi-4-b.dtb"
    "bcm2711-rpi-400.dtb"
    "bcm2711-rpi-cm4.dtb"
)

log_info "Downloading Raspberry Pi firmware files..."
for fw_file in "${FIRMWARE_FILES[@]}"; do
    fw_path="$FIRMWARE_DIR/$fw_file"
    if [[ ! -f "$fw_path" ]]; then
        log_info "  Fetching: $fw_file"
        download_file "$FIRMWARE_REPO/$fw_file" "$fw_path" || log_warning "Could not download $fw_file"
    else
        log_info "  Already exists: $fw_file"
    fi
done

log "Phase 3: Generating Configuration Files"
log "-------------------------------------------------------------------"

# Generate config.txt for Raspberry Pi
CONFIG_TXT="$FIRMWARE_DIR/config.txt"
log_info "Generating config.txt..."

cat > "$CONFIG_TXT" <<'EOF'
# Raspberry Pi 5 Multiboot Configuration
# Generated by acquire.sh

[all]
# Enable 64-bit kernel
arm_64bit=1

# GPU Memory (adjust as needed)
gpu_mem=128

# HDMI settings
hdmi_drive=2

# Boot delay (gives time for NVMe to initialize)
boot_delay=1

# Enable UART for debugging (optional)
enable_uart=1

# USB settings
max_usb_current=1

# Display settings
disable_overscan=1

# Audio
dtparam=audio=on

# I2C and SPI (uncomment if needed)
#dtparam=i2c_arm=on
#dtparam=spi=on

# Camera (uncomment if needed)
#start_x=1

[pi5]
# Pi 5 specific settings
kernel=kernel8.img
arm_64bit=1

[all]
EOF

log_success "Generated config.txt at: $CONFIG_TXT"

# Generate cmdline.txt template
CMDLINE_TXT="$FIRMWARE_DIR/cmdline.txt.template"
log_info "Generating cmdline.txt template..."

cat > "$CMDLINE_TXT" <<'EOF'
console=serial0,115200 console=tty1 root=PARTUUID=PLACEHOLDER rootfstype=ext4 fsck.repair=yes rootwait
EOF

log_success "Generated cmdline.txt template at: $CMDLINE_TXT"

# Create EFI directory structure template
EFI_STRUCTURE="$ARTIFACTS_DIR/efi_structure.txt"
log_info "Documenting EFI structure..."

cat > "$EFI_STRUCTURE" <<'EOF'
EFI Boot Structure for Multiboot Setup
========================================

Required directory structure on BOOT_GRUB partition:

/
├── EFI/
│   └── BOOT/
│       ├── bootaa64.efi (GRUB for ARM64)
│       └── grub.cfg
├── grub/
│   ├── grub.cfg
│   └── grubenv
└── kernels/
    ├── kubuntu/
    │   ├── vmlinuz
    │   └── initrd.img
    └── fedora/
        ├── vmlinuz
        └── initrd.img

Note: GRUB will need to be installed during the install phase.
EOF

log_success "EFI structure documented at: $EFI_STRUCTURE"

# Generate GRUB configuration template
GRUB_CFG="$ARTIFACTS_DIR/grub.cfg.template"
log_info "Generating GRUB configuration template..."

cat > "$GRUB_CFG" <<'EOF'
# GRUB Configuration for Raspberry Pi 5 Multiboot
# This is a template - actual UUIDs will be populated during install phase

set timeout=10
set default=0

# Load video drivers
insmod all_video
insmod gfxterm

# Set graphics mode
set gfxmode=auto
terminal_output gfxterm

# Theme (optional)
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

# Kubuntu Entry
menuentry "Kubuntu" {
    search --no-floppy --fs-uuid --set=root KUBUNTU_UUID
    linux /boot/vmlinuz root=UUID=KUBUNTU_UUID ro quiet splash
    initrd /boot/initrd.img
}

# Fedora Entry
menuentry "Fedora" {
    search --no-floppy --fs-uuid --set=root FEDORA_UUID
    linux /boot/vmlinuz root=UUID=FEDORA_UUID ro quiet
    initrd /boot/initrd.img
}

# Recovery options
menuentry "Kubuntu (Recovery Mode)" {
    search --no-floppy --fs-uuid --set=root KUBUNTU_UUID
    linux /boot/vmlinuz root=UUID=KUBUNTU_UUID ro recovery nomodeset
    initrd /boot/initrd.img
}

menuentry "Fedora (Recovery Mode)" {
    search --no-floppy --fs-uuid --set=root FEDORA_UUID
    linux /boot/vmlinuz root=UUID=FEDORA_UUID ro recovery nomodeset
    initrd /boot/initrd.img
}

# Firmware update (optional)
menuentry "Reboot" {
    reboot
}

menuentry "Power Off" {
    halt
}
EOF

log_success "Generated GRUB config template at: $GRUB_CFG"

# Create firmware version tracking file
FIRMWARE_VERSION="$FIRMWARE_DIR/firmware_version.txt"
log_info "Recording firmware version information..."

cat > "$FIRMWARE_VERSION" <<EOF
Firmware Acquisition Details
==============================

Date: $(date)
Source: $FIRMWARE_REPO
Files: ${#FIRMWARE_FILES[@]} files downloaded

Files list:
$(printf '  - %s\n' "${FIRMWARE_FILES[@]}")

Note: Firmware files are from the official Raspberry Pi firmware repository.
Update regularly to get the latest improvements and bug fixes.
EOF

log_success "Firmware version info saved to: $FIRMWARE_VERSION"

# Create acquisition summary
SUMMARY_FILE="$ARTIFACTS_DIR/acquisition_summary.txt"
log "Creating acquisition summary..."

cat > "$SUMMARY_FILE" <<EOF
=================================================================
ACQUIRE Phase Summary
=================================================================

Execution Date: $(date)
Log File: $LOG_FILE

Directories Created/Updated:
  - Images:     $IMAGES_DIR
  - Firmware:   $FIRMWARE_DIR
  - Checksums:  $CHECKSUMS_DIR

Firmware Files:
  - ${#FIRMWARE_FILES[@]} firmware files staged
  - config.txt generated
  - cmdline.txt template created

Configuration Files:
  - GRUB config template: $GRUB_CFG
  - EFI structure doc:    $EFI_STRUCTURE
  - Firmware version:     $FIRMWARE_VERSION

TODO Items:
  [ ] Add actual OS image URLs to this script
  [ ] Download Kubuntu image
  [ ] Download Fedora image
  [ ] Generate/download checksum files
  [ ] Verify checksums after download
  [ ] Add additional distributions as needed

Next Step:
  Run install.sh to deploy the acquired artifacts to prepared partitions

=================================================================
EOF

cat "$SUMMARY_FILE" | tee -a "$LOG_FILE"

log_success "==================================================================="
log_success "ACQUIRE phase completed successfully!"
log_success "==================================================================="
log_success "Artifacts stored in: $ARTIFACTS_DIR"
log_success "Log file: $LOG_FILE"
log_success "Summary: $SUMMARY_FILE"
log_success ""
log_success "Next step: Run install.sh to install OS images to partitions"
log_success "==================================================================="

exit 0
