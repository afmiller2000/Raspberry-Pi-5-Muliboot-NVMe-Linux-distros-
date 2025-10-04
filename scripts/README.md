# Multiboot Scripts Documentation

This directory contains the core automation scripts for creating a Raspberry Pi 5 multiboot NVMe device.

## Scripts Overview

### 1. prepare.sh
**Phase**: PREPARE  
**Requires**: Root access (sudo)  
**Destructive**: YES - will erase all data on target device  

```bash
sudo ./prepare.sh /dev/nvme0n1
```

**Purpose**: Prepares the NVMe device with partitions, filesystems, and mount points.

**Operations**:
- Validates target device
- Requires explicit user confirmation ("YES")
- Unmounts existing partitions
- Wipes partition table
- Creates new GPT partition table
- Creates 6 partitions (FIRMWARE_A, BOOT_GRUB, KUBUNTU, FEDORA, DATA, SWAP)
- Formats each partition with appropriate filesystem
- Assigns filesystem labels
- Mounts partitions to `/mnt/multiboot/`
- Generates partition map file

**Output**:
- Partitions created and mounted
- Partition map: `artifacts/logs/partition_map.txt`
- Log file: `artifacts/logs/prepare_YYYYMMDD_HHMMSS.log`

**Safety Features**:
- Device validation
- Confirmation prompt with device information
- Comprehensive logging

---

### 2. acquire.sh
**Phase**: ACQUIRE  
**Requires**: Internet connection  
**Destructive**: NO - safe to run multiple times  

```bash
./acquire.sh
```

**Purpose**: Downloads OS images, firmware files, and generates configuration files.

**Operations**:
- Downloads Raspberry Pi firmware from official repository
- Creates config.txt with optimal settings
- Generates GRUB configuration templates
- Documents EFI boot structure
- Creates checksum verification templates
- Records firmware version information

**Downloads**:
- start4*.elf (GPU firmware files)
- fixup4*.dat (memory fixup data)
- bootcode.bin (bootloader)
- bcm2711*.dtb (device tree blobs)

**Generated Files**:
- `artifacts/firmware/config.txt`
- `artifacts/firmware/cmdline.txt.template`
- `artifacts/grub.cfg.template`
- `artifacts/efi_structure.txt`
- `artifacts/checksums/README.md`

**Output**:
- Firmware files in `artifacts/firmware/`
- Configuration files
- Log file: `artifacts/logs/acquire_YYYYMMDD_HHMMSS.log`

**Note**: OS image downloads are commented out by default. Edit the script to add actual URLs.

---

### 3. install.sh
**Phase**: INSTALL  
**Requires**: Root access (sudo)  
**Destructive**: NO - but modifies partitions created by prepare.sh  

```bash
sudo ./install.sh
```

**Purpose**: Deploys firmware, OS images, and boot configuration to the prepared device.

**Prerequisites**:
- prepare.sh must have been run (partitions must exist and be mounted)
- acquire.sh should have been run (firmware and images should be available)

**Operations**:
- Copies firmware files to FIRMWARE_A partition
- Creates EFI/GRUB directory structure on BOOT_GRUB partition
- Generates GRUB configuration with actual partition UUIDs
- Extracts and installs OS root filesystems (if images available)
- Copies kernels and initrd to boot partition
- Creates installation summary on DATA partition

**Features**:
- Automatically handles compressed images (.xz)
- Uses loop devices for safe image extraction
- Generates UUIDs for GRUB configuration
- Creates recovery boot options
- Handles missing images gracefully (creates placeholders)

**Output**:
- Fully configured multiboot device
- Installation summary: `MULTIBOOT_SUMMARY.txt` on DATA partition
- Log file: `artifacts/logs/install_YYYYMMDD_HHMMSS.log`

---

### 4. build_multiboot_device.sh
**Phase**: ALL (wrapper)  
**Requires**: Root access (sudo)  
**Destructive**: YES (runs prepare.sh)  

```bash
sudo ./build_multiboot_device.sh /dev/nvme0n1
```

**Purpose**: One-shot execution of all three phases in sequence.

**Operations**:
1. Displays informational banner
2. Runs prepare.sh (destructive)
3. Runs acquire.sh
4. Runs install.sh
5. Displays completion banner

**Use Case**: Quick setup when you want to automate the entire process.

**Error Handling**: Stops execution if any phase fails.

---

## Execution Order

### Standard Workflow
```bash
# Step 1: Prepare device (DESTRUCTIVE!)
sudo ./scripts/prepare.sh /dev/nvme0n1

# Step 2: Download artifacts
./scripts/acquire.sh

# Step 3: Install everything
sudo ./scripts/install.sh
```

### One-Shot Workflow
```bash
sudo ./scripts/build_multiboot_device.sh /dev/nvme0n1
```

---

## Idempotency

- **prepare.sh**: NOT idempotent - will destroy existing data
- **acquire.sh**: Idempotent - skips already downloaded files
- **install.sh**: Partially idempotent - can be re-run to update configuration

---

## Logging

All scripts create detailed logs in `artifacts/logs/`:
- Timestamped filenames
- Color-coded output (INFO, SUCCESS, WARNING, ERROR)
- Complete command output captured
- Operation timestamps

---

## Safety Features

### prepare.sh
- Explicit confirmation required ("YES")
- Shows device information before wiping
- Validates block device existence

### acquire.sh
- Download retry logic (3 attempts)
- Checksum verification support
- Non-destructive operations

### install.sh
- Checks for partition map before proceeding
- Graceful handling of missing images
- Loop device cleanup on error

---

## Customization

### Changing Partition Sizes
Edit `prepare.sh` and adjust the parted commands:
```bash
# Example: Make Kubuntu partition 60GB instead of 40GB
parted -s "$TARGET" mkpart primary ext4 1537MiB 62977MiB
```

### Adding OS Distributions
1. Edit `prepare.sh`: Add new partition
2. Edit `acquire.sh`: Add download URL
3. Edit `install.sh`: Add installation logic
4. Update GRUB template with new menu entry

### Updating Firmware Configuration
After running `acquire.sh`, edit:
```bash
artifacts/firmware/config.txt
```
Then re-run `install.sh` to deploy changes.

---

## Troubleshooting

### Script Fails Immediately
- Check syntax: `bash -n script.sh`
- Verify permissions: `ls -l scripts/`
- Check dependencies: `which parted mkfs.ext4 wget`

### prepare.sh Fails
- Verify device path: `lsblk`
- Ensure device is not mounted: `umount /dev/nvme0n1*`
- Check for root access: `id`

### acquire.sh Download Fails
- Check internet connection
- Verify URLs are correct
- Check disk space: `df -h`

### install.sh Cannot Find Partitions
- Check partition map exists: `ls artifacts/logs/partition_map.txt`
- Verify mounts: `mount | grep multiboot`
- Re-run prepare.sh if needed

---

## Future Enhancements

Planned scripts (from TODO in problem statement):
- **kernels.sh** - Kernel consolidation and pruning
- **grub-update.sh** - GRUB configuration regeneration
- **report.sh** - Status and health reporting with JSON output

---

## Dependencies

Required commands:
- `parted` - Partition management
- `mkfs.vfat` - FAT32 filesystem
- `mkfs.ext4` - ext4 filesystem
- `mkfs.exfat` - exFAT filesystem
- `mkswap` - Swap creation
- `wget` - File download
- `rsync` - File synchronization
- `losetup` - Loop device management
- `blkid` - UUID/label detection
- `lsblk` - Block device listing
- `wipefs` - Filesystem signature wiping
- `dd` - Low-level disk operations

Install on Debian/Ubuntu:
```bash
sudo apt-get install parted dosfstools e2fsprogs exfat-utils rsync wget util-linux
```

---

## Exit Codes

- **0**: Success
- **1**: Error (check logs for details)

---

## Best Practices

1. ✅ Always backup data before running prepare.sh
2. ✅ Verify target device path carefully
3. ✅ Run acquire.sh before install.sh
4. ✅ Check logs after each phase
5. ✅ Test on non-production hardware first
6. ✅ Keep logs for troubleshooting
7. ✅ Update firmware regularly (re-run acquire.sh)
