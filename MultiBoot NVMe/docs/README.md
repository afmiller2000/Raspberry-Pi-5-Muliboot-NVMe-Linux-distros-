# Raspberry Pi 5 NVMe Multiboot System

Complete automation framework for setting up multiple Linux distributions on a Raspberry Pi 5 with NVMe storage.

## Overview

This system provides a three-phase installation process to prepare, download, and install multiple Linux distributions on a single NVMe drive for Raspberry Pi 5, allowing you to choose which OS to boot at startup.

## Features

- **Three-Phase Installation**: PREPARE → ACQUIRE → INSTALL
- **Multiple Distributions**: Support for Ubuntu, Debian, Fedora, and Arch Linux
- **Safety First**: Dry-run mode, destructive operation flags
- **Comprehensive Logging**: Detailed logs and JSON manifests for every operation
- **Shared Storage**: Common boot and data partitions
- **EFI/GRUB Support**: Bootloader configuration included

## Quick Start

### Prerequisites

- Raspberry Pi 5
- NVMe drive (256GB+ recommended)
- Root access
- Internet connection for downloading images
- Required tools: `bash`, `parted`, `mkfs.vfat`, `mkfs.ext4`, `wget`/`curl`, `xz`, `rsync`, `jq`

### Installation Steps

1. **PREPARE Phase** - Prepare the NVMe drive
   ```bash
   cd "MultiBoot NVMe"
   sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute
   ```

2. **ACQUIRE Phase** - Download OS images
   ```bash
   sudo ./acquire.sh
   ```

3. **INSTALL Phase** - Install distributions
   ```bash
   sudo ./install.sh --target /dev/nvme0n1
   ```

4. **Reboot and Select OS** - Use GRUB menu to choose your distribution

## Safety Features

⚠️ **WARNING**: These scripts perform DESTRUCTIVE operations on the target device!

- **Dry-run mode**: Test without making changes (`--dry-run`)
- **Confirmation flags**: Destructive operations require `--yes --execute`
- **Interactive confirmation**: Additional prompt before wiping device
- **Manifest tracking**: Every operation logged with timestamps

### Example: Safe Testing

```bash
# See what PREPARE would do without making changes
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute --dry-run

# See what files ACQUIRE would download
./acquire.sh --dry-run

# See what INSTALL would do
sudo ./install.sh --target /dev/nvme0n1 --dry-run
```

## Directory Structure

```
MultiBoot NVMe/
├── prepare.sh              # Phase 1: Prepare NVMe drive
├── acquire.sh              # Phase 2: Download images
├── install.sh              # Phase 3: Install distributions
├── lib/
│   └── common.sh          # Shared utilities and functions
├── artifacts/
│   ├── isos/              # Downloaded OS images
│   ├── logs/              # Execution logs
│   └── manifests/         # JSON operation manifests
└── docs/
    ├── README.md          # This file
    ├── GUIDE.md           # Detailed user guide
    ├── SAFETY.md          # Safety and backup information
    ├── SCRIPTS.md         # Script reference documentation
    └── TASKS.md           # Development tasks and roadmap
```

## Partition Layout

| Partition | Label  | Size   | Filesystem | Purpose                    |
|-----------|--------|--------|------------|----------------------------|
| 1         | EFI    | 512MB  | FAT32      | EFI System Partition       |
| 2         | BOOT   | 1GB    | ext4       | Shared boot files          |
| 3         | UBUNTU | 30GB   | ext4       | Ubuntu root filesystem     |
| 4         | DEBIAN | 30GB   | ext4       | Debian root filesystem     |
| 5         | FEDORA | 30GB   | ext4       | Fedora root filesystem     |
| 6         | ARCH   | 30GB   | ext4       | Arch Linux root filesystem |
| 7         | DATA   | Rest   | ext4       | Shared data storage        |

## Command Reference

### prepare.sh
```bash
Usage: ./prepare.sh --target DEVICE --yes --execute [OPTIONS]

Required:
  --target DEVICE     Target NVMe device
  --yes               Confirm destructive operation
  --execute           Confirm execution

Optional:
  --dry-run          Show what would be done
  --verbose, -v      Enable verbose output
```

### acquire.sh
```bash
Usage: ./acquire.sh [OPTIONS]

Optional:
  --dry-run          Show what would be done
  --verbose, -v      Enable verbose output
  --skip-download    Skip downloads (use existing files)
  --skip-verify      Skip checksum verification
```

### install.sh
```bash
Usage: ./install.sh --target DEVICE [OPTIONS]

Required:
  --target DEVICE     Target NVMe device

Optional:
  --distro LIST      Comma-separated distro list (e.g., ubuntu,debian)
  --skip-grub-update Skip GRUB configuration
  --dry-run          Show what would be done
  --verbose, -v      Enable verbose output
```

## Documentation

- **[GUIDE.md](docs/GUIDE.md)** - Comprehensive installation and usage guide
- **[SAFETY.md](docs/SAFETY.md)** - Safety considerations and backup procedures
- **[SCRIPTS.md](docs/SCRIPTS.md)** - Detailed script reference and internals
- **[TASKS.md](docs/TASKS.md)** - Development roadmap and contribution guide

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Solution: Run scripts with `sudo`

2. **Device Not Found**
   - Solution: Verify device path with `lsblk`
   - Check: NVMe drive is properly connected

3. **Download Failures**
   - Solution: Check internet connection
   - Try: `--skip-download` to use cached files

4. **Insufficient Space**
   - Solution: Use larger NVMe drive (256GB+ recommended)
   - Alternative: Reduce number of distributions to install

### Getting Help

Check the logs in `artifacts/logs/` and manifests in `artifacts/manifests/` for detailed information about what was executed and any errors.

## Contributing

Contributions are welcome! See [TASKS.md](docs/TASKS.md) for development roadmap and guidelines.

## License

This project is provided as-is for educational and personal use. Use at your own risk.

## Disclaimer

⚠️ **IMPORTANT**: These scripts will DESTROY all data on the target device. Always backup important data before proceeding. The authors are not responsible for any data loss or hardware damage.
