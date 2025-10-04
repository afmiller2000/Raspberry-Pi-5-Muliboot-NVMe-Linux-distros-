# Script Reference Documentation

Technical reference for all scripts in the Raspberry Pi 5 NVMe Multiboot system.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [lib/common.sh](#libcommonsh)
3. [prepare.sh](#preparesh)
4. [acquire.sh](#acquiresh)
5. [install.sh](#installsh)
6. [Extending the System](#extending-the-system)

## Architecture Overview

### Design Principles

1. **Bash Strict Mode**: All scripts use `set -euo pipefail`
2. **Fail Fast**: Errors stop execution immediately
3. **Idempotent**: Safe to re-run operations
4. **Logged**: All operations tracked in manifests
5. **Testable**: Dry-run mode for all destructive operations

### Script Dependencies

```
lib/common.sh (base library)
    ├── prepare.sh (uses common.sh)
    ├── acquire.sh (uses common.sh)
    └── install.sh (uses common.sh)
```

### Data Flow

```
prepare.sh  → Creates partitions on NVMe
                ↓
acquire.sh  → Downloads images to artifacts/isos/
                ↓
install.sh  → Copies images to partitions
```

## lib/common.sh

The foundation library providing shared functionality.

### Global Variables

```bash
SCRIPT_DIR          # Directory containing the script
PROJECT_ROOT        # Root of MultiBoot NVMe directory
ARTIFACTS_DIR       # artifacts/ directory
LOGS_DIR           # artifacts/logs/
MANIFESTS_DIR      # artifacts/manifests/
ISOS_DIR           # artifacts/isos/

# Flags
DRY_RUN            # true/false
VERBOSE            # true/false
TARGET_DEVICE      # e.g., /dev/nvme0n1
YES_CONFIRMED      # true/false
EXECUTE_CONFIRMED  # true/false
```

### Color Constants

```bash
COLOR_RED          # Error messages
COLOR_GREEN        # Success messages
COLOR_YELLOW       # Warning messages
COLOR_BLUE         # Info messages
COLOR_RESET        # Reset formatting
```

### Logging Functions

#### log_info(message)
Logs informational messages in blue.

```bash
log_info "Starting operation..."
```

#### log_success(message)
Logs success messages in green.

```bash
log_success "Operation completed!"
```

#### log_warning(message)
Logs warning messages in yellow.

```bash
log_warning "Non-critical issue detected"
```

#### log_error(message)
Logs error messages in red.

```bash
log_error "Critical failure occurred"
```

#### log_verbose(message)
Logs verbose debug messages (only when VERBOSE=true).

```bash
log_verbose "Detailed debug information"
```

#### die(message)
Logs error and exits with status 1.

```bash
die "Fatal error: cannot continue"
```

### Validation Functions

#### validate_root()
Ensures script is running as root (EUID=0).

```bash
validate_root
```

#### validate_target_device()
Verifies TARGET_DEVICE is set and is a block device.

```bash
validate_target_device
```

#### validate_destructive_operation(operation_name)
Ensures both --yes and --execute flags are set for destructive operations.

```bash
validate_destructive_operation "wipe_disk"
```

### Execution Functions

#### run_command(description, command...)
Executes command, respecting dry-run mode.

```bash
run_command "Format partition" mkfs.ext4 /dev/nvme0n1p3
```

In dry-run mode:
- Logs what would be done
- Does not execute command
- Returns success

In normal mode:
- Executes command
- Logs verbose output
- Returns command exit code

#### is_dry_run()
Returns true if DRY_RUN=true.

```bash
if is_dry_run; then
    echo "Dry run mode"
fi
```

### Manifest Functions

Manifests are JSON files tracking all operations.

#### init_manifest(manifest_name)
Creates new manifest file and returns path.

```bash
manifest_file=$(init_manifest "PREPARE-$(date +%Y%m%d-%H%M%S)")
```

Creates:
```json
{
  "manifest_name": "PREPARE-20240101-120000",
  "timestamp": "2024-01-01T12:00:00Z",
  "hostname": "raspberrypi",
  "user": "root",
  "operations": []
}
```

#### append_to_manifest(manifest_file, operation, status, details)
Adds operation to manifest.

```bash
append_to_manifest "${manifest_file}" "wipe_device" "completed" "/dev/nvme0n1"
```

Adds to operations array:
```json
{
  "operation": "wipe_device",
  "status": "completed",
  "details": "/dev/nvme0n1",
  "timestamp": "2024-01-01T12:05:00Z"
}
```

#### finalize_manifest(manifest_file, final_status)
Marks manifest as complete.

```bash
finalize_manifest "${manifest_file}" "success"
```

Adds:
```json
{
  "final_status": "success",
  "completed_at": "2024-01-01T12:30:00Z"
}
```

### Utility Functions

#### ensure_directories()
Creates required artifact directories if they don't exist.

```bash
ensure_directories
```

#### get_device_info(device)
Returns formatted device information.

```bash
get_device_info "/dev/nvme0n1"
```

#### check_dependency(command)
Verifies required command is available.

```bash
check_dependency "parted"
check_dependency "mkfs.ext4"
```

#### parse_common_args(args...)
Parses standard command-line arguments.

Recognized flags:
- `--dry-run`: Enable dry-run mode
- `--verbose`, `-v`: Enable verbose output
- `--target DEVICE`: Set target device
- `--yes`: Confirm destructive operation
- `--execute`: Confirm execution
- `--help`, `-h`: Show help

Returns 0 on success, 1 if help requested or error.

```bash
if ! parse_common_args "$@"; then
    show_help
    exit 1
fi
```

#### init_common()
Initializes common environment (directories, dependencies).

```bash
init_common
```

## prepare.sh

PREPARE phase: Partitions and formats NVMe drive.

### Command-Line Interface

```bash
./prepare.sh --target DEVICE --yes --execute [OPTIONS]
```

**Required:**
- `--target DEVICE`: Target NVMe device
- `--yes`: Confirm destructive operation
- `--execute`: Confirm execution

**Optional:**
- `--dry-run`: Test without executing
- `--verbose`, `-v`: Verbose output
- `--help`, `-h`: Show help

### Configuration

#### PARTITIONS Array

Defines partition layout:

```bash
declare -A PARTITIONS=(
    [number]="LABEL:SIZE:FSTYPE:DESCRIPTION"
)
```

Example:
```bash
[1]="EFI:512M:vfat:EFI System Partition"
[3]="UBUNTU:30G:ext4:Ubuntu Root"
```

- **number**: Partition number (1-7)
- **LABEL**: Partition label
- **SIZE**: Size (512M, 30G) or 0 for remaining space
- **FSTYPE**: Filesystem type (vfat, ext4)
- **DESCRIPTION**: Human-readable description

### Functions

#### wipe_device(device)
Wipes partition table and filesystem signatures.

```bash
wipe_device "/dev/nvme0n1"
```

Operations:
1. `sgdisk --zap-all` - Remove GPT structures
2. `wipefs -a` - Remove filesystem signatures

#### create_partitions(device)
Creates GPT partition table and all partitions.

```bash
create_partitions "/dev/nvme0n1"
```

Operations:
1. Create GPT label with `parted mklabel gpt`
2. For each partition in PARTITIONS:
   - Calculate start/end positions
   - Create partition with `parted mkpart`
   - Set boot flag on EFI partition

#### format_partitions(device)
Formats all partitions with specified filesystems.

```bash
format_partitions "/dev/nvme0n1"
```

Operations:
1. Run `partprobe` to refresh partition table
2. For each partition:
   - Format vfat: `mkfs.vfat -F 32 -n LABEL`
   - Format ext4: `mkfs.ext4 -F -L LABEL`

#### mount_partitions(device)
Mounts all partitions under MOUNT_BASE.

```bash
mount_partitions "/dev/nvme0n1"
```

Operations:
1. Create mount points: `/mnt/multiboot/{EFI,BOOT,UBUNTU,...}`
2. Mount each partition: `mount /dev/nvme0n1pN /mnt/multiboot/LABEL`

#### show_summary(device)
Displays partition layout and mount status.

```bash
show_summary "/dev/nvme0n1"
```

Uses `lsblk` to show:
- Partition names
- Sizes
- Filesystem types
- Labels
- Mount points

### Workflow

1. Parse arguments
2. Initialize common environment
3. Validate requirements (root, device, flags)
4. Initialize manifest
5. Show device info
6. Interactive confirmation
7. Execute operations:
   - Wipe device
   - Create partitions
   - Format partitions
   - Mount partitions
8. Show summary
9. Finalize manifest

### Exit Codes

- `0`: Success
- `1`: Error (validation, execution, or user cancellation)

## acquire.sh

ACQUIRE phase: Downloads and verifies OS images.

### Command-Line Interface

```bash
./acquire.sh [OPTIONS]
```

**Optional:**
- `--dry-run`: Test without downloading
- `--verbose`, `-v`: Verbose output
- `--skip-download`: Use existing files
- `--skip-verify`: Skip checksum verification
- `--help`, `-h`: Show help

### Configuration

#### DISTRO_IMAGES Array

Defines download URLs:

```bash
declare -A DISTRO_IMAGES=(
    [distro]="URL"
)
```

Example:
```bash
[ubuntu]="https://cdimage.ubuntu.com/.../ubuntu-23.10-arm64.img.xz"
[debian]="https://raspi.debian.net/.../debian-12-arm64.img.xz"
```

#### DISTRO_CHECKSUMS Array

Defines SHA256 checksums:

```bash
declare -A DISTRO_CHECKSUMS=(
    [distro]="SHA256_HASH"
)
```

Example:
```bash
[ubuntu]="a1b2c3d4e5f6..."
[debian]="1a2b3c4d5e6f..."
```

### Functions

#### download_image(distro, url)
Downloads distribution image.

```bash
download_image "ubuntu" "https://..."
```

Operations:
1. Check if SKIP_DOWNLOAD and file exists
2. Use `wget -c` (with resume) or `curl -C -`
3. Save to `artifacts/isos/{distro}.img.xz`

#### verify_checksum(distro, expected_checksum)
Verifies SHA256 checksum.

```bash
verify_checksum "ubuntu" "a1b2c3d4..."
```

Operations:
1. Skip if SKIP_VERIFY or placeholder checksum
2. Calculate SHA256 with `sha256sum`
3. Compare with expected checksum
4. Die if mismatch

#### extract_image(distro)
Extracts compressed image.

```bash
extract_image "ubuntu"
```

Operations:
1. Check if already extracted
2. Run `xz -dk` to decompress
3. Creates `{distro}.img` from `{distro}.img.xz`

#### download_firmware()
Downloads Raspberry Pi firmware files.

```bash
download_firmware
```

Operations:
1. Create `artifacts/isos/firmware/` directory
2. Download from GitHub raspberrypi/firmware:
   - `start4.elf`
   - `fixup4.dat`
   - `bcm2711-rpi-4-b.dtb`
   - `bcm2712-rpi-5-b.dtb`

#### create_efi_tree()
Creates EFI directory structure.

```bash
create_efi_tree
```

Creates:
```
artifacts/isos/efi-tree/
├── EFI/
│   └── BOOT/
└── firmware/
```

### Workflow

1. Parse arguments
2. Initialize common environment
3. Check dependencies (wget/curl, sha256sum, xz)
4. Initialize manifest
5. For each distribution:
   - Download image
   - Verify checksum
   - Extract image
6. Download firmware
7. Create EFI tree
8. Show summary
9. Finalize manifest

### Exit Codes

- `0`: Success
- `1`: Error (download failure, checksum mismatch, etc.)

## install.sh

INSTALL phase: Installs OS images to partitions.

### Command-Line Interface

```bash
./install.sh --target DEVICE [OPTIONS]
```

**Required:**
- `--target DEVICE`: Target NVMe device

**Optional:**
- `--distro LIST`: Comma-separated list (e.g., "ubuntu,debian")
- `--skip-grub-update`: Skip GRUB configuration
- `--dry-run`: Test without executing
- `--verbose`, `-v`: Verbose output
- `--help`, `-h`: Show help

### Configuration

#### DISTRO_PARTITIONS Array

Maps distributions to partition numbers:

```bash
declare -A DISTRO_PARTITIONS=(
    [ubuntu]=3
    [debian]=4
    [fedora]=5
    [arch]=6
)
```

### Functions

#### mount_image(image_file, mount_point)
Mounts OS image using loop device.

```bash
loop_device=$(mount_image "ubuntu.img" "/tmp/ubuntu-mount")
```

Operations:
1. Create loop device: `losetup -fP --show`
2. Mount root partition (usually p2)
3. Return loop device path

#### unmount_image(mount_point, loop_device)
Unmounts image and detaches loop device.

```bash
unmount_image "/tmp/ubuntu-mount" "/dev/loop0"
```

Operations:
1. Unmount: `umount`
2. Detach: `losetup -d`

#### copy_rootfs(distro, source_mount, target_mount)
Copies root filesystem.

```bash
copy_rootfs "ubuntu" "/tmp/ubuntu-src" "/mnt/multiboot/UBUNTU"
```

Operations:
1. Use `rsync -aAXHv` if available (preferred)
2. Fallback to `cp -a` if rsync not found
3. Preserves permissions, ownership, timestamps

#### update_fstab(distro, target_mount, part_num, device)
Updates /etc/fstab for the distribution.

```bash
update_fstab "ubuntu" "/mnt/multiboot/UBUNTU" 3 "/dev/nvme0n1"
```

Operations:
1. Get UUID with `blkid`
2. Backup original fstab
3. Create new fstab with:
   - Root partition (by UUID)
   - EFI partition (by label)
   - BOOT partition (by label)
   - DATA partition (by label)

Generated fstab:
```
UUID=xxx  /          ext4  defaults,noatime  0  1
LABEL=EFI /boot/efi  vfat  defaults          0  2
LABEL=BOOT /boot     ext4  defaults          0  2
LABEL=DATA /data     ext4  defaults          0  2
```

#### install_boot_artifacts(distro, source_mount)
Copies kernel, initramfs, and device trees.

```bash
install_boot_artifacts "ubuntu" "/tmp/ubuntu-src"
```

Operations:
1. Create `/mnt/multiboot/BOOT/{distro}/`
2. Copy kernel (vmlinuz-* or kernel*)
3. Copy initramfs (initrd.img-* or initramfs-*)
4. Copy device tree blobs (dtbs/ or broadcom/)

#### update_grub_config()
Creates GRUB configuration.

```bash
update_grub_config
```

Operations:
1. Create `/mnt/multiboot/EFI/EFI/BOOT/grub.cfg`
2. Add menu entries for each distribution
3. Set timeout and default

Generated grub.cfg:
```
set timeout=10
set default=0

menuentry "Ubuntu" {
    linux /ubuntu/vmlinuz root=LABEL=UBUNTU ro quiet
    initrd /ubuntu/initrd.img
}
# ... more entries
```

#### install_distro(distro)
Complete installation for one distribution.

```bash
install_distro "ubuntu"
```

Workflow:
1. Check image file exists
2. Mount image
3. Copy rootfs
4. Update fstab
5. Install boot artifacts
6. Unmount image

### Workflow

1. Parse arguments
2. Initialize common environment
3. Validate requirements (root, losetup, blkid)
4. Validate target device
5. Initialize manifest
6. Determine distros to install
7. For each distribution:
   - Install distro
   - Append to manifest
8. Update GRUB config
9. Show summary
10. Finalize manifest

### Exit Codes

- `0`: Success
- `1`: Error (image not found, mount failure, copy error, etc.)

## Extending the System

### Adding a New Distribution

1. **Edit prepare.sh** - Add partition:
```bash
declare -A PARTITIONS=(
    # ... existing partitions
    [8]="NEWDISTRO:30G:ext4:New Distribution Root"
)
```

2. **Edit acquire.sh** - Add download URL and checksum:
```bash
declare -A DISTRO_IMAGES=(
    # ... existing distros
    [newdistro]="https://example.com/newdistro.img.xz"
)

declare -A DISTRO_CHECKSUMS=(
    # ... existing checksums
    [newdistro]="sha256hash..."
)
```

3. **Edit install.sh** - Add partition mapping:
```bash
declare -A DISTRO_PARTITIONS=(
    # ... existing mappings
    [newdistro]=8
)
```

4. **Edit install.sh** - Add GRUB menu entry:
```bash
menuentry "New Distribution" {
    linux /newdistro/vmlinuz root=LABEL=NEWDISTRO ro quiet
    initrd /newdistro/initrd.img
}
```

### Adding New Functionality

#### Example: Add verification step

1. Create function in `lib/common.sh`:
```bash
verify_installation() {
    local distro=$1
    local mount_point=$2
    
    log_info "Verifying ${distro} installation..."
    
    # Check critical files exist
    if [[ ! -f "${mount_point}/etc/fstab" ]]; then
        log_error "fstab missing"
        return 1
    fi
    
    log_success "Verification passed for ${distro}"
}
```

2. Export function:
```bash
export -f verify_installation
```

3. Call from install.sh:
```bash
verify_installation "${distro}" "${target_mount}"
append_to_manifest "${manifest_file}" "verify_${distro}" "completed" "Verified"
```

### Creating Custom Scripts

Use lib/common.sh as foundation:

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log_info "Starting custom script..."
    
    init_common
    
    # Your code here
    
    log_success "Custom script completed!"
}

main "$@"
```

### Best Practices

1. **Always use bash strict mode**: `set -euo pipefail`
2. **Validate inputs**: Use validation functions
3. **Log extensively**: Use log_* functions
4. **Support dry-run**: Check `is_dry_run()`
5. **Track operations**: Use manifest functions
6. **Handle errors**: Use `die()` for fatal errors
7. **Document changes**: Update this file

### Testing

```bash
# Test new functionality with dry-run
./custom-script.sh --dry-run

# Test with verbose output
./custom-script.sh --verbose

# Test error handling
./custom-script.sh --target /invalid/device
```

### Code Style

- Use lowercase with underscores for functions: `my_function()`
- Use UPPERCASE for constants: `MOUNT_BASE`
- Use descriptive variable names: `target_partition` not `tp`
- Comment complex logic
- Use consistent indentation (4 spaces)
- Quote all variables: `"${var}"`
- Use arrays for lists: `declare -a items`
- Use associative arrays for mappings: `declare -A mapping`

## Summary

This script system provides:
- **Modular design**: Reusable common library
- **Safety features**: Dry-run, validation, confirmation
- **Comprehensive logging**: Manifests track all operations
- **Extensibility**: Easy to add distributions or features
- **Maintainability**: Well-documented, consistent style

For usage instructions, see [GUIDE.md](GUIDE.md).
For safety information, see [SAFETY.md](SAFETY.md).
For development tasks, see [TASKS.md](TASKS.md).
