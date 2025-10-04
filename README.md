# Raspberry Pi 5 NVMe Multiboot Linux Distros

Comprehensive automation framework for setting up multiple Linux distributions on a Raspberry Pi 5 with NVMe storage.

## Overview

This project provides a complete three-phase installation system to prepare, download, and install multiple Linux distributions on a single NVMe drive for Raspberry Pi 5. Choose your OS at boot time using a GRUB menu.

## Features

- 🚀 **Three-Phase Installation**: PREPARE → ACQUIRE → INSTALL
- 🐧 **Multiple Distributions**: Ubuntu, Debian, Fedora, Arch Linux (and more)
- 🛡️ **Safety First**: Dry-run mode and destructive operation safeguards
- 📊 **Comprehensive Logging**: JSON manifests track every operation
- 🔄 **Shared Storage**: Common boot and data partitions across all OSes
- ⚙️ **EFI/GRUB Support**: Complete bootloader configuration

## Quick Start

### Prerequisites

- Raspberry Pi 5 with NVMe drive (256GB+ recommended)
- Root access
- Internet connection
- Required tools: `bash`, `parted`, `mkfs.ext4`, `wget`/`curl`, `xz`, `rsync`, `jq`

### Installation

```bash
# Navigate to the scripts directory
cd "MultiBoot NVMe"

# Phase 1: Prepare the NVMe drive (DESTRUCTIVE!)
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute

# Phase 2: Download OS images
sudo ./acquire.sh

# Phase 3: Install distributions
sudo ./install.sh --target /dev/nvme0n1

# Reboot and select your OS from GRUB menu
```

⚠️ **WARNING**: The prepare phase will DESTROY all data on the target device. Always backup important data first!

## Safe Testing

Test operations without making changes:

```bash
# Test prepare phase
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute --dry-run

# Test acquire phase
./acquire.sh --dry-run

# Test install phase
sudo ./install.sh --target /dev/nvme0n1 --dry-run
```

## Documentation

Comprehensive documentation is available in the `MultiBoot NVMe/docs/` directory:

- **[README.md](MultiBoot%20NVMe/docs/README.md)** - System overview and quick reference
- **[GUIDE.md](MultiBoot%20NVMe/docs/GUIDE.md)** - Complete installation guide with step-by-step instructions
- **[SAFETY.md](MultiBoot%20NVMe/docs/SAFETY.md)** - Safety considerations, backup procedures, and recovery
- **[SCRIPTS.md](MultiBoot%20NVMe/docs/SCRIPTS.md)** - Technical reference for all scripts and functions
- **[TASKS.md](MultiBoot%20NVMe/docs/TASKS.md)** - Development roadmap and contribution guide

## Project Structure

```
MultiBoot NVMe/
├── prepare.sh              # Phase 1: Partition and format NVMe
├── acquire.sh              # Phase 2: Download OS images and firmware
├── install.sh              # Phase 3: Install distributions to partitions
├── lib/
│   └── common.sh          # Shared utilities and functions
├── artifacts/
│   ├── isos/              # Downloaded OS images (gitignored)
│   ├── logs/              # Execution logs (gitignored)
│   └── manifests/         # JSON operation manifests (gitignored)
└── docs/
    ├── README.md          # System overview
    ├── GUIDE.md           # Installation guide
    ├── SAFETY.md          # Safety and backup information
    ├── SCRIPTS.md         # Technical documentation
    └── TASKS.md           # Development roadmap
```

## Partition Layout

The system creates the following partition structure:

| Partition | Label  | Size   | Filesystem | Purpose                |
|-----------|--------|--------|------------|------------------------|
| 1         | EFI    | 512MB  | FAT32      | EFI System Partition   |
| 2         | BOOT   | 1GB    | ext4       | Shared boot files      |
| 3         | UBUNTU | 30GB   | ext4       | Ubuntu root filesystem |
| 4         | DEBIAN | 30GB   | ext4       | Debian root filesystem |
| 5         | FEDORA | 30GB   | ext4       | Fedora root filesystem |
| 6         | ARCH   | 30GB   | ext4       | Arch root filesystem   |
| 7         | DATA   | Rest   | ext4       | Shared data storage    |

## Requirements

### Hardware
- Raspberry Pi 5
- NVMe SSD (256GB minimum, 512GB+ recommended)
- NVMe HAT or adapter
- Stable power supply

### Software
```bash
sudo apt-get update
sudo apt-get install -y parted gdisk e2fsprogs dosfstools \
    wget curl xz-utils rsync jq util-linux
```

## Key Features

### Bash Strict Mode
All scripts use `set -euo pipefail` for robust error handling.

### Dry-Run Mode
Test any operation safely:
```bash
./script.sh --dry-run
```

### Destructive Operation Protection
Sensitive operations require multiple confirmations:
```bash
./prepare.sh --target /dev/nvme0n1 --yes --execute
# Plus interactive "type 'yes' to continue" prompt
```

### Manifest Generation
Every operation is logged to JSON manifests:
```bash
cat artifacts/manifests/PREPARE-*.json | jq .
```

### Verbose Logging
Detailed debug output available:
```bash
./script.sh --verbose
```

## Advanced Usage

### Install Specific Distributions Only

```bash
sudo ./install.sh --target /dev/nvme0n1 --distro ubuntu,debian
```

### Skip Downloads (Use Cached Images)

```bash
./acquire.sh --skip-download
```

### Skip GRUB Update

```bash
sudo ./install.sh --target /dev/nvme0n1 --skip-grub-update
```

## Troubleshooting

Check the documentation for detailed troubleshooting:
- Logs: `MultiBoot NVMe/artifacts/logs/`
- Manifests: `MultiBoot NVMe/artifacts/manifests/`
- [GUIDE.md](MultiBoot%20NVMe/docs/GUIDE.md) - Troubleshooting section
- [SAFETY.md](MultiBoot%20NVMe/docs/SAFETY.md) - Recovery procedures

## Contributing

Contributions are welcome! See [TASKS.md](MultiBoot%20NVMe/docs/TASKS.md) for the development roadmap and contribution guidelines.

## License

This project is provided as-is for educational and personal use. Use at your own risk.

## Disclaimer

⚠️ **IMPORTANT**: These scripts perform DESTRUCTIVE operations that will PERMANENTLY DELETE all data on the target device. Always backup important data before proceeding. The authors and contributors are not responsible for any data loss or hardware damage.

## Credits

Created for the Raspberry Pi 5 community to simplify multiboot NVMe setups.

## Support

- 📖 Read the [documentation](MultiBoot%20NVMe/docs/)
- 🐛 Report issues on GitHub
- 💡 Submit feature requests
- 🤝 Contribute improvements

---

**Status**: Alpha - Initial implementation complete. Tested in dry-run mode. Real hardware testing needed.
