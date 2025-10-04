# Raspberry Pi 5 NVMe Multiboot Setup

Automation scripts for creating a multi-boot NVMe device with multiple Linux distributions on Raspberry Pi 5.

## Overview

This project provides a complete, ultra-minimal workflow to prepare a single NVMe device for a multi-boot environment on Raspberry Pi 5. The process is organized into three high-level phases that wrap all low-level operations:

1. **PREPARE** - Wipe, partition, format, label, and mount the NVMe device
2. **ACQUIRE** - Download OS images, fetch firmware, and generate configuration
3. **INSTALL** - Deploy root filesystems and finalize boot artifacts

## Features

- ✅ **Simple 3-phase workflow** with clear separation of concerns
- ✅ **Safety confirmations** before destructive operations
- ✅ **Comprehensive logging** of all operations
- ✅ **Support for multiple distributions** (Kubuntu, Fedora, and extensible)
- ✅ **GRUB bootloader** configuration with recovery options
- ✅ **Shared data partition** (exFAT) accessible from all OSes
- ✅ **Automated firmware deployment** from official Raspberry Pi repository
- ✅ **Idempotent scripts** - safe to re-run phases as needed

## Prerequisites

- Raspberry Pi 5
- NVMe SSD (256GB or larger recommended)
- Linux system for preparation (Ubuntu, Debian, Fedora, etc.)
- Root/sudo access
- Required tools: `parted`, `mkfs.vfat`, `mkfs.ext4`, `mkfs.exfat`, `rsync`, `wget`, `losetup`

### Installing Required Tools

**Debian/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install parted dosfstools e2fsprogs exfat-utils rsync wget util-linux
```

**Fedora:**
```bash
sudo dnf install parted dosfstools e2fsprogs exfat-utils rsync wget util-linux
```

## Quick Start

### Option 1: One-Shot Build (All Phases)

```bash
# Clone the repository
git clone https://github.com/afmiller2000/Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-.git
cd Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-

# Run the one-shot builder (WARNING: DESTRUCTIVE!)
sudo ./scripts/build_multiboot_device.sh /dev/nvme0n1
```

### Option 2: Step-by-Step Execution

```bash
# Phase 1: Prepare the device (DESTRUCTIVE - will erase all data!)
sudo ./scripts/prepare.sh /dev/nvme0n1

# Phase 2: Acquire OS images and firmware
./scripts/acquire.sh

# Phase 3: Install everything to the device
sudo ./scripts/install.sh
```

## Partition Layout

The default configuration creates the following partitions:

| Label      | Size  | Filesystem | Purpose                              |
|------------|-------|------------|--------------------------------------|
| FIRMWARE_A | 512MB | FAT32      | Firmware blobs + config.txt          |
| BOOT_GRUB  | 1GB   | ext4       | GRUB bootloader + kernels            |
| KUBUNTU    | 40GB  | ext4       | Kubuntu root filesystem              |
| FEDORA     | 40GB  | ext4       | Fedora root filesystem               |
| DATA       | 50GB  | exFAT      | Shared user data (all OSes)          |
| SWAP       | 8GB   | swap       | Shared swap space                    |

**Total:** ~140GB (adjust sizes in `scripts/prepare.sh` based on your NVMe capacity)

See `artifacts/partition_plan.yaml` for detailed partition specifications.

## Directory Structure

```
.
├── scripts/
│   ├── prepare.sh              # Phase 1: Partition and format
│   ├── acquire.sh              # Phase 2: Download and stage
│   ├── install.sh              # Phase 3: Deploy to device
│   └── build_multiboot_device.sh # One-shot wrapper
├── artifacts/
│   ├── partition_plan.yaml     # Partition layout specification
│   ├── checksums/              # Checksum files for verification
│   ├── firmware/               # Raspberry Pi firmware files
│   ├── images/                 # Downloaded OS images
│   └── logs/                   # Execution logs
└── README.md
```

## Detailed Usage

### Phase 1: PREPARE

**Purpose:** Prepares the NVMe device with partitions, filesystems, and labels.

**⚠️ WARNING:** This phase is DESTRUCTIVE and will erase all data on the target device!

```bash
sudo ./scripts/prepare.sh /dev/nvme0n1
```

**What it does:**
- Confirms target device with user
- Wipes existing partition tables
- Creates new GPT partition table
- Creates and formats all partitions
- Assigns filesystem labels
- Mounts partitions to `/mnt/multiboot/`
- Records partition map for subsequent phases

**Safety features:**
- Requires typing "YES" to confirm
- Shows device information before wiping
- Creates comprehensive logs

### Phase 2: ACQUIRE

**Purpose:** Downloads OS images, fetches firmware, and generates configuration files.

**Non-destructive** - safe to run multiple times.

```bash
./scripts/acquire.sh
```

**What it does:**
- Downloads Raspberry Pi firmware files
- Stages OS image downloads (URLs must be configured)
- Generates `config.txt` for Raspberry Pi
- Creates GRUB configuration template
- Generates EFI boot structure
- Records firmware version information

**Customization:**
Edit `scripts/acquire.sh` to add your preferred OS image URLs:
- Update `KUBUNTU_URL` and `FEDORA_URL` variables
- Uncomment download sections
- Add checksums for verification

### Phase 3: INSTALL

**Purpose:** Deploys all artifacts to the prepared partitions.

```bash
sudo ./scripts/install.sh
```

**What it does:**
- Copies firmware files to FIRMWARE_A partition
- Sets up GRUB bootloader configuration
- Extracts and installs OS root filesystems
- Copies kernels to boot partition
- Generates installation summary
- Creates documentation on DATA partition

**Features:**
- Automatically handles compressed images (`.xz`, `.gz`)
- Uses loop devices to mount and extract OS images
- Generates UUIDs and updates GRUB configuration
- Creates recovery boot options

## Configuration

### Adding Additional Distributions

1. **Edit `prepare.sh`:** Add new partition(s)
2. **Edit `acquire.sh`:** Add download URLs for new OS
3. **Edit `install.sh`:** Add installation logic for new OS
4. **Update GRUB config:** Add new boot menu entries

### Customizing Partition Sizes

Edit the partition sizes in `scripts/prepare.sh`:

```bash
# Example: Increase Kubuntu partition from 40GB to 60GB
parted -s "$TARGET" mkpart primary ext4 1537MiB 62977MiB  # 60GB
```

Adjust subsequent partition start positions accordingly.

### Firmware Configuration

Edit `artifacts/firmware/config.txt` after running `acquire.sh` to customize:
- GPU memory allocation
- Display settings
- UART/I2C/SPI interfaces
- Camera and audio settings

## Boot Process

1. Raspberry Pi firmware reads `config.txt` from FIRMWARE_A partition
2. Firmware loads GRUB bootloader from BOOT_GRUB partition
3. GRUB presents menu with available OS options
4. Selected OS boots from its dedicated partition
5. All OSes can access shared DATA partition

## Troubleshooting

### Device doesn't boot
- Check firmware files are present in FIRMWARE_A partition
- Verify `config.txt` is correctly formatted
- Ensure GRUB is properly installed
- Check boot order in Raspberry Pi settings

### OS won't start
- Verify kernel and initrd exist in `/mnt/multiboot/boot/kernels/<os>/`
- Check GRUB configuration for correct UUIDs
- Review logs in `artifacts/logs/`
- Try booting in recovery mode

### Partition errors
- Ensure target device is not mounted during prepare phase
- Check device path is correct (`/dev/nvme0n1` vs `/dev/sda`)
- Verify sufficient disk space for all partitions

### Missing tools
```bash
# Install missing dependencies
sudo apt-get install parted dosfstools e2fsprogs exfat-utils rsync wget
```

## Logs

All operations are logged to `artifacts/logs/`:
- `prepare_YYYYMMDD_HHMMSS.log` - Partition and format operations
- `acquire_YYYYMMDD_HHMMSS.log` - Download and staging operations  
- `install_YYYYMMDD_HHMMSS.log` - Installation operations
- `partition_map.txt` - Generated partition mapping

## Safety and Best Practices

1. ✅ **Backup important data** before starting
2. ✅ **Verify target device** carefully before running prepare.sh
3. ✅ **Test on non-production devices** first
4. ✅ **Keep logs** for troubleshooting
5. ✅ **Update firmware regularly** by re-running acquire.sh
6. ✅ **Verify checksums** for downloaded OS images

## TODO / Future Enhancements

- [ ] Implement kernel consolidation script (`kernels.sh`)
- [ ] Add GRUB update utility (`grub-update.sh`)
- [ ] Create status report generator (`report.sh`)
- [ ] Add JSON output format for automation
- [ ] Implement DRY_RUN mode
- [ ] Add support for additional distributions
- [ ] Create automated checksum verification
- [ ] Add boot menu customization tool

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided as-is for educational and personal use.

## Acknowledgments

- Raspberry Pi Foundation for firmware and documentation
- Linux distribution maintainers
- GRUB bootloader project

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing logs in `artifacts/logs/`
- Review partition configuration in `artifacts/partition_plan.yaml`

---

**⚠️ Disclaimer:** This software is provided as-is. Always backup your data before performing destructive operations. The authors are not responsible for data loss or hardware damage.
