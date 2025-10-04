# Complete Installation Guide

This guide provides step-by-step instructions for setting up a multiboot Raspberry Pi 5 system with NVMe storage.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Hardware Setup](#hardware-setup)
3. [Software Preparation](#software-preparation)
4. [Phase 1: PREPARE](#phase-1-prepare)
5. [Phase 2: ACQUIRE](#phase-2-acquire)
6. [Phase 3: INSTALL](#phase-3-install)
7. [Post-Installation](#post-installation)
8. [Advanced Usage](#advanced-usage)

## Prerequisites

### Hardware Requirements

- **Raspberry Pi 5** with sufficient cooling
- **NVMe SSD** (256GB minimum, 512GB or 1TB recommended)
- **NVMe HAT or adapter** for Raspberry Pi 5
- **microSD card** for initial boot (optional after setup)
- **Power supply** capable of handling Pi 5 + NVMe load
- **Network connection** (Ethernet recommended)

### Software Requirements

The following tools must be installed:

```bash
# Essential tools
sudo apt-get update
sudo apt-get install -y \
    parted \
    gdisk \
    e2fsprogs \
    dosfstools \
    wget \
    curl \
    xz-utils \
    rsync \
    jq \
    util-linux
```

### Skill Requirements

- Basic Linux command line knowledge
- Understanding of disk partitioning concepts
- Ability to troubleshoot boot issues
- Root/sudo access

## Hardware Setup

### 1. Install NVMe Drive

1. Power off Raspberry Pi completely
2. Install NVMe HAT according to manufacturer instructions
3. Insert NVMe drive into HAT
4. Secure all connections
5. Power on Raspberry Pi

### 2. Verify NVMe Detection

```bash
# Check if NVMe is detected
lsblk

# Should show something like:
# nvme0n1           259:0    0  477G  0 disk

# Get detailed info
sudo nvme list

# Check PCIe link
lspci | grep -i nvme
```

## Software Preparation

### 1. Clone/Download Scripts

```bash
# If using git
git clone <repository-url>
cd Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-

# Navigate to scripts directory
cd "MultiBoot NVMe"
```

### 2. Review Configuration

Before running any scripts, review the default configuration:

- Check partition sizes in `prepare.sh`
- Review distribution URLs in `acquire.sh`
- Verify mount points and paths

### 3. Understand Dry-Run Mode

Always test with dry-run first:

```bash
# Test PREPARE phase
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute --dry-run

# Review output carefully
```

## Phase 1: PREPARE

This phase prepares your NVMe drive by creating partitions.

### ⚠️ CRITICAL WARNING

**THIS WILL DESTROY ALL DATA ON THE TARGET DEVICE!**

Ensure you:
- Have backups of important data
- Specified the correct device
- Are prepared to wait (process may take 10-20 minutes)

### Execute PREPARE

```bash
# Navigate to scripts directory
cd "MultiBoot NVMe"

# Run PREPARE phase (DRY RUN first!)
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute --dry-run

# If dry-run looks good, execute for real
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute

# You will be prompted to type 'yes' to confirm
```

### What PREPARE Does

1. **Wipes device** - Clears all existing data
2. **Creates GPT partition table**
3. **Creates 7 partitions**:
   - EFI (512MB, FAT32)
   - BOOT (1GB, ext4)
   - UBUNTU (30GB, ext4)
   - DEBIAN (30GB, ext4)
   - FEDORA (30GB, ext4)
   - ARCH (30GB, ext4)
   - DATA (remaining space, ext4)
4. **Formats all partitions**
5. **Mounts partitions** at `/mnt/multiboot`

### Verify PREPARE Success

```bash
# Check partitions
lsblk /dev/nvme0n1

# Check mounts
df -h | grep multiboot

# Should see all partitions mounted
```

### Troubleshooting PREPARE

**Issue**: Device busy error
```bash
# Solution: Unmount any existing mounts
sudo umount /dev/nvme0n1*

# Force if needed
sudo fuser -km /dev/nvme0n1
```

**Issue**: Partition creation fails
```bash
# Solution: Ensure no other process is using the device
sudo systemctl stop udisks2
```

## Phase 2: ACQUIRE

This phase downloads OS images and firmware files.

### Disk Space Check

Before starting, ensure you have enough space:

```bash
# Check available space
df -h

# You need approximately 10-15GB per distribution
# Plus space for firmware (200-300MB)
```

### Execute ACQUIRE

```bash
# Run ACQUIRE phase (no root needed)
./acquire.sh

# With verbose output
./acquire.sh --verbose

# Skip downloads if you have images already
./acquire.sh --skip-download
```

### What ACQUIRE Does

1. **Downloads OS images**:
   - Ubuntu Server for ARM64
   - Debian for ARM64
   - (Fedora and Arch if available)
2. **Verifies checksums** (SHA256)
3. **Extracts images** (decompresses .xz files)
4. **Downloads firmware** files for Raspberry Pi 5
5. **Creates EFI tree** structure

### Monitor Progress

ACQUIRE can take 30-90 minutes depending on your internet connection:

```bash
# In another terminal, monitor downloads
watch -n 5 'ls -lh artifacts/isos/'

# Check network usage
sudo iftop
```

### Verify ACQUIRE Success

```bash
# Check downloaded files
ls -lh artifacts/isos/

# Should see:
# - *.img.xz files (compressed images)
# - *.img files (extracted images)
# - firmware/ directory

# Check manifests
cat artifacts/manifests/ACQUIRE-*.json | jq .
```

### Troubleshooting ACQUIRE

**Issue**: Download interrupted
```bash
# Solution: ACQUIRE uses wget with resume
# Just run again, it will continue
./acquire.sh
```

**Issue**: Checksum mismatch
```bash
# Solution: Re-download the specific image
rm artifacts/isos/<distro>.img.xz
./acquire.sh
```

**Issue**: Out of disk space
```bash
# Solution: Free up space or use external storage
# You can symlink artifacts/isos to external drive
```

## Phase 3: INSTALL

This phase copies OS files to the prepared partitions.

### Pre-Installation Checks

```bash
# Verify partitions are still mounted
df -h | grep multiboot

# If not mounted, run prepare again
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute

# Verify images are downloaded
ls artifacts/isos/*.img
```

### Execute INSTALL

```bash
# Install all distributions (dry-run first)
sudo ./install.sh --target /dev/nvme0n1 --dry-run

# Install all distributions
sudo ./install.sh --target /dev/nvme0n1

# Install specific distributions only
sudo ./install.sh --target /dev/nvme0n1 --distro ubuntu,debian

# With verbose output
sudo ./install.sh --target /dev/nvme0n1 --verbose
```

### What INSTALL Does

1. **Mounts OS images** using loop devices
2. **Copies root filesystems** to target partitions
3. **Updates fstab** for each distribution
4. **Installs boot artifacts**:
   - Kernel images
   - Initramfs files
   - Device tree blobs
5. **Configures GRUB** bootloader
6. **Creates boot menu** entries

### Monitor Progress

INSTALL can take 20-60 minutes per distribution:

```bash
# In another terminal, monitor disk usage
watch -n 5 'df -h | grep multiboot'

# Check system load
htop
```

### Verify INSTALL Success

```bash
# Check installed files
ls /mnt/multiboot/UBUNTU/
ls /mnt/multiboot/BOOT/

# Check GRUB config
cat /mnt/multiboot/EFI/EFI/BOOT/grub.cfg

# Review manifest
cat artifacts/manifests/INSTALL-*.json | jq .
```

## Post-Installation

### 1. Unmount All Partitions

```bash
# Unmount all multiboot partitions
sudo umount /mnt/multiboot/*

# Verify nothing is mounted
df -h | grep multiboot
```

### 2. Update Raspberry Pi Firmware

```bash
# Update bootloader to support NVMe boot
sudo rpi-eeprom-update -a
sudo reboot
```

### 3. Configure Boot Order

```bash
# Edit boot config
sudo rpi-eeprom-config --edit

# Set boot order to prioritize NVMe
# BOOT_ORDER=0xf16
# Save and reboot
```

### 4. First Boot

1. Remove microSD card (if using one)
2. Reboot Raspberry Pi
3. GRUB menu should appear
4. Select your distribution
5. Complete OS-specific setup

### 5. Test Each Distribution

Boot into each installed distribution:

- Verify network connectivity
- Check shared mount points (`/boot`, `/boot/efi`, `/data`)
- Test switching between distributions

## Advanced Usage

### Custom Partition Sizes

Edit `prepare.sh` before running:

```bash
# Find the PARTITIONS array
declare -A PARTITIONS=(
    [1]="EFI:512M:vfat:EFI System Partition"
    [3]="UBUNTU:50G:ext4:Ubuntu Root"  # Changed from 30G
    # ... modify as needed
)
```

### Adding More Distributions

1. Edit `prepare.sh` to add partition
2. Edit `acquire.sh` to add download URL
3. Edit `install.sh` to add distro mapping
4. Edit `install.sh` GRUB config to add menu entry

### Selective Installation

```bash
# Install only Ubuntu
sudo ./install.sh --target /dev/nvme0n1 --distro ubuntu

# Install Ubuntu and Debian
sudo ./install.sh --target /dev/nvme0n1 --distro ubuntu,debian
```

### Manual GRUB Configuration

```bash
# Mount EFI partition
sudo mount /dev/nvme0n1p1 /mnt

# Edit GRUB config
sudo nano /mnt/EFI/BOOT/grub.cfg

# Add custom menu entries
# Unmount when done
sudo umount /mnt
```

### Sharing Data Between Distributions

The DATA partition is automatically mounted in all distributions:

```bash
# Access from any OS
ls /data

# Create shared directories
sudo mkdir -p /data/documents /data/downloads /data/projects
```

### Logging and Manifests

All operations are logged:

```bash
# View logs
ls artifacts/logs/

# View manifests (JSON format)
cat artifacts/manifests/PREPARE-*.json | jq .
cat artifacts/manifests/ACQUIRE-*.json | jq .
cat artifacts/manifests/INSTALL-*.json | jq .

# Filter by operation
jq '.operations[] | select(.status=="completed")' artifacts/manifests/*.json
```

## Next Steps

- Read [SAFETY.md](SAFETY.md) for backup and recovery procedures
- Read [SCRIPTS.md](SCRIPTS.md) for technical details
- Check [TASKS.md](TASKS.md) for features and improvements
- Configure each OS according to your needs
- Set up automatic backups for DATA partition

## Getting Help

If you encounter issues:

1. Check logs in `artifacts/logs/`
2. Review manifests in `artifacts/manifests/`
3. Run with `--verbose` flag for detailed output
4. Verify all prerequisites are installed
5. Ensure NVMe drive is properly connected
6. Check Raspberry Pi 5 firmware is up to date
