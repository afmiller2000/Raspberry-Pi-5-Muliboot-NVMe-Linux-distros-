# Quick Start Guide

Get your Raspberry Pi 5 multiboot NVMe device up and running in minutes.

## Prerequisites Checklist

- [ ] Raspberry Pi 5
- [ ] NVMe SSD (256GB or larger)
- [ ] Linux system for preparation
- [ ] Root/sudo access
- [ ] Internet connection

## Installation

### Step 1: Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install parted dosfstools e2fsprogs exfat-utils rsync wget util-linux
```

**Fedora:**
```bash
sudo dnf install parted dosfstools e2fsprogs exfat-utils rsync wget util-linux
```

### Step 2: Clone Repository

```bash
git clone https://github.com/afmiller2000/Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-.git
cd Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-
```

### Step 3: Configure OS Images (Optional)

If you want to automatically download OS images, edit `scripts/acquire.sh`:

```bash
nano scripts/acquire.sh
```

Update the URLs for your desired distributions and uncomment the download sections.

## Usage Options

### Option A: One-Shot Build (Easiest)

⚠️ **WARNING**: This will erase all data on the target device!

```bash
# Identify your NVMe device
lsblk

# Run the complete build (replace /dev/nvme0n1 with your device)
sudo ./scripts/build_multiboot_device.sh /dev/nvme0n1
```

The script will:
1. Prompt for confirmation
2. Partition and format the device
3. Download firmware and OS images
4. Install everything
5. Display completion summary

**Estimated time**: 30-60 minutes (depending on download speed)

### Option B: Step-by-Step (More Control)

For more control over each phase:

#### Phase 1: Prepare Device (DESTRUCTIVE!)

```bash
# Identify your device
lsblk

# Prepare the device
sudo ./scripts/prepare.sh /dev/nvme0n1
```

You'll be asked to type "YES" to confirm. This creates and formats all partitions.

#### Phase 2: Acquire Artifacts

```bash
# Download firmware and (optionally) OS images
./scripts/acquire.sh
```

This downloads Raspberry Pi firmware. If you configured OS image URLs, it will download those too.

#### Phase 3: Install to Device

```bash
# Deploy everything to the device
sudo ./scripts/install.sh
```

This copies firmware, creates boot configuration, and installs OS images (if available).

## Manual OS Image Installation

If you prefer to manually download OS images:

```bash
# Download Kubuntu
wget -O artifacts/images/kubuntu-raspi.img.xz \
  https://cdimage.ubuntu.com/releases/23.10/release/ubuntu-23.10-preinstalled-desktop-arm64+raspi.img.xz

# Download Fedora
wget -O artifacts/images/fedora-raspi.img.xz \
  https://download.fedoraproject.org/pub/fedora/linux/releases/39/Spins/aarch64/images/Fedora-Minimal-39-1.5.aarch64.raw.xz

# Then run install phase
sudo ./scripts/install.sh
```

## Final Steps

### 1. Unmount Everything

```bash
sudo umount /mnt/multiboot/firmware
sudo umount /mnt/multiboot/boot
sudo umount /mnt/multiboot/kubuntu
sudo umount /mnt/multiboot/fedora
sudo umount /mnt/multiboot/data
sudo swapoff /dev/nvme0n1p6
```

### 2. Safely Remove NVMe

```bash
# Sync all writes
sync

# Safely remove device
sudo eject /dev/nvme0n1
```

### 3. Install in Raspberry Pi 5

1. Power off your Raspberry Pi 5
2. Install the NVMe drive in the M.2 slot
3. Power on the Raspberry Pi 5
4. You should see the GRUB boot menu
5. Select your desired OS

## Troubleshooting

### Device Not Found

```bash
# List all block devices
lsblk

# Check for NVMe devices
ls /dev/nvme*
```

Ensure your NVMe is connected and recognized.

### Permission Denied

Scripts need root access for disk operations:
```bash
sudo ./scripts/prepare.sh /dev/nvme0n1
```

### Download Fails

Check internet connection and verify URLs in `scripts/acquire.sh` are correct.

### Boot Fails

1. Check firmware files exist in the firmware partition
2. Verify config.txt is present and formatted correctly
3. Check boot order in Raspberry Pi firmware settings

## Verification

Check the installation summary:
```bash
cat /mnt/multiboot/data/MULTIBOOT_SUMMARY.txt
```

View logs:
```bash
ls -lh artifacts/logs/
tail -100 artifacts/logs/install_*.log
```

## Next Steps

- Check out the full [README.md](README.md) for detailed documentation
- Review [scripts/README.md](scripts/README.md) for script details
- Read [CONTRIBUTING.md](CONTRIBUTING.md) if you want to contribute

## Common Questions

**Q: How long does the process take?**  
A: 30-60 minutes depending on your internet speed and download sizes.

**Q: Can I add more distributions later?**  
A: Yes! The device has space for additional partitions. Edit the scripts to add more distros.

**Q: Will this erase my existing data?**  
A: Yes! The prepare.sh script is destructive and will erase all data on the target device.

**Q: Can I customize partition sizes?**  
A: Yes! Edit the partition sizes in `scripts/prepare.sh` before running it.

**Q: What if I don't want to download images automatically?**  
A: Leave the download sections commented out in `acquire.sh` and manually place images in `artifacts/images/`.

**Q: Can I use this on Raspberry Pi 4?**  
A: The scripts target Raspberry Pi 5, but can be adapted for Pi 4 with minor modifications.

## Support

For issues or questions:
- Check logs in `artifacts/logs/`
- Review documentation in README.md
- Open an issue on GitHub

---

**Happy Multibooting! 🚀**
