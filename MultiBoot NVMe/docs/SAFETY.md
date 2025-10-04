# Safety and Backup Guide

## Critical Safety Information

### ⚠️ Data Loss Warning

The scripts in this project perform **DESTRUCTIVE OPERATIONS** that will:
- **PERMANENTLY DELETE** all data on the target device
- **OVERWRITE** partition tables
- **FORMAT** all partitions
- **CANNOT BE UNDONE** once started

### Before You Begin

**MANDATORY STEPS:**

1. ✅ **Backup ALL data** from the target NVMe drive
2. ✅ **Verify backup integrity** before proceeding
3. ✅ **Double-check device identifier** (e.g., `/dev/nvme0n1`)
4. ✅ **Disconnect other drives** if possible to prevent accidents
5. ✅ **Read all documentation** thoroughly
6. ✅ **Test with dry-run mode** first

## Safety Features

### Built-in Safeguards

1. **Dry-Run Mode**
   - Test operations without making changes
   - Review exactly what will happen
   - Verify correct device and parameters

2. **Multiple Confirmation Flags**
   - Destructive operations require `--yes` flag
   - Additional `--execute` flag required
   - Interactive "type 'yes' to continue" prompt

3. **Root Requirement**
   - Prevents accidental execution by regular users
   - Forces conscious privilege escalation

4. **Device Validation**
   - Verifies target is a block device
   - Shows device information before proceeding
   - Checks device accessibility

### Example: Safe Workflow

```bash
# Step 1: Dry run to see what would happen
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute --dry-run

# Step 2: Review output carefully
# - Check all partition operations
# - Verify device path is correct
# - Ensure sizes are as expected

# Step 3: Execute if everything looks good
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute

# Step 4: Type 'yes' when prompted
# This is your final chance to abort
```

## Backup Procedures

### Before Installation

#### 1. Backup Existing NVMe Data

If your NVMe drive contains data:

```bash
# Option A: Clone entire drive
sudo dd if=/dev/nvme0n1 of=/path/to/backup.img bs=4M status=progress

# Option B: Backup specific partitions
sudo dd if=/dev/nvme0n1p1 of=/path/to/partition1.img bs=4M status=progress

# Option C: Use rsync for filesystems
sudo rsync -aAXHv --info=progress2 /mount/point /backup/location/
```

#### 2. Backup Raspberry Pi SD Card

If booting from SD card:

```bash
# From another system with SD card reader
sudo dd if=/dev/sdX of=raspberrypi-backup.img bs=4M status=progress

# Compress to save space
gzip raspberrypi-backup.img
```

#### 3. Document Current Configuration

```bash
# Save partition layout
sudo fdisk -l /dev/nvme0n1 > partition-layout.txt

# Save mount points
df -h > mounts.txt

# Save fstab
cat /etc/fstab > fstab-backup.txt

# Save boot config
cp /boot/config.txt config-backup.txt
```

### During Installation

#### Manifest Files

The system automatically creates JSON manifests:

```bash
# Manifests location
artifacts/manifests/

# Each phase creates a timestamped manifest
PREPARE-20240101-120000.json
ACQUIRE-20240101-130000.json
INSTALL-20240101-140000.json

# Backup manifests
cp -r artifacts/manifests /safe/backup/location/
```

#### Log Files

```bash
# Logs location
artifacts/logs/

# Backup logs
cp -r artifacts/logs /safe/backup/location/
```

### After Installation

#### 1. Backup Individual Distributions

After successful installation:

```bash
# Backup Ubuntu partition
sudo dd if=/dev/nvme0n1p3 of=/backup/ubuntu-root.img bs=4M status=progress

# Compress
gzip /backup/ubuntu-root.img

# Backup Debian partition
sudo dd if=/dev/nvme0n1p4 of=/backup/debian-root.img bs=4M status=progress
```

#### 2. Backup Boot Configuration

```bash
# Mount EFI partition
sudo mount /dev/nvme0n1p1 /mnt

# Backup EFI directory
sudo cp -r /mnt/EFI /backup/efi-backup/

# Backup GRUB config
sudo cp /mnt/EFI/BOOT/grub.cfg /backup/grub.cfg.backup

# Unmount
sudo umount /mnt
```

#### 3. Create Recovery Image

```bash
# Create a minimal recovery image of the entire setup
sudo dd if=/dev/nvme0n1 bs=4M count=1000 of=/backup/recovery-first-4gb.img status=progress

# This captures partition table, EFI, and BOOT partitions
```

## Recovery Procedures

### Recover from Failed Installation

#### If PREPARE Phase Fails

```bash
# The device may be in an inconsistent state
# Re-run PREPARE to start fresh

# Check device state
lsblk /dev/nvme0n1

# Unmount any mounted partitions
sudo umount /dev/nvme0n1p*

# Re-run PREPARE
sudo ./prepare.sh --target /dev/nvme0n1 --yes --execute
```

#### If ACQUIRE Phase Fails

```bash
# ACQUIRE only downloads files, no system changes
# Safe to retry or skip problematic downloads

# Check what was downloaded
ls -lh artifacts/isos/

# Remove corrupted downloads
rm artifacts/isos/problematic-distro.img.xz

# Re-run ACQUIRE
./acquire.sh

# Or skip re-downloading existing files
./acquire.sh --skip-download
```

#### If INSTALL Phase Fails

```bash
# Check which operations completed
cat artifacts/manifests/INSTALL-*.json | jq .

# Unmount any mounted images/partitions
sudo umount /mnt/multiboot/*
sudo losetup -D

# Re-run INSTALL for specific distros
sudo ./install.sh --target /dev/nvme0n1 --distro ubuntu,debian

# Or start fresh with all distros
sudo ./install.sh --target /dev/nvme0n1
```

### Restore from Backup

#### Restore Entire Drive

```bash
# Restore from full drive backup
sudo dd if=/path/to/backup.img of=/dev/nvme0n1 bs=4M status=progress

# Verify partition table
sudo fdisk -l /dev/nvme0n1
```

#### Restore Specific Partition

```bash
# Restore Ubuntu partition
sudo dd if=/backup/ubuntu-root.img of=/dev/nvme0n1p3 bs=4M status=progress

# Or restore compressed backup
gunzip -c /backup/ubuntu-root.img.gz | sudo dd of=/dev/nvme0n1p3 bs=4M status=progress
```

#### Restore Boot Configuration

```bash
# Mount EFI partition
sudo mount /dev/nvme0n1p1 /mnt

# Restore GRUB config
sudo cp /backup/grub.cfg.backup /mnt/EFI/BOOT/grub.cfg

# Restore EFI directory
sudo cp -r /backup/efi-backup/* /mnt/EFI/

# Unmount
sudo umount /mnt
```

### Manual Recovery

#### Recreate Boot Menu

If GRUB menu is broken but systems are installed:

```bash
# Boot from SD card
# Mount partitions
sudo mount /dev/nvme0n1p1 /mnt/efi
sudo mount /dev/nvme0n1p2 /mnt/boot

# Manually create GRUB config
sudo nano /mnt/efi/EFI/BOOT/grub.cfg

# Add entries (see GUIDE.md for examples)

# Unmount
sudo umount /mnt/efi /mnt/boot
```

#### Fix Unbootable System

```bash
# Boot from SD card
# Mount NVMe root partition (e.g., Ubuntu)
sudo mount /dev/nvme0n1p3 /mnt

# Mount necessary system directories
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# Chroot into system
sudo chroot /mnt

# Fix boot issues
update-initramfs -u
update-grub

# Exit chroot
exit

# Unmount
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt
```

## Best Practices

### Regular Backups

```bash
# Weekly backup of DATA partition
sudo rsync -aAXHv --delete --info=progress2 \
    /mnt/multiboot/DATA/ \
    /backup/data-weekly/

# Monthly full backup
sudo dd if=/dev/nvme0n1 of=/backup/monthly/nvme-$(date +%Y%m).img bs=4M status=progress
```

### Version Control

```bash
# Keep manifests in version control
git add artifacts/manifests/
git commit -m "Installation manifest $(date +%Y-%m-%d)"

# Tag releases
git tag -a install-$(date +%Y%m%d) -m "Production installation"
```

### Testing Strategy

1. **Always test with dry-run first**
2. **Verify each phase before proceeding to next**
3. **Keep backups until verified working**
4. **Test recovery procedures before needed**
5. **Document any custom changes**

### Monitoring

```bash
# Monitor disk health
sudo smartctl -a /dev/nvme0n1

# Check for errors
sudo dmesg | grep -i nvme

# Monitor disk usage
df -h | grep multiboot
```

## Emergency Procedures

### System Won't Boot

1. Boot from microSD card
2. Check NVMe is detected: `lsblk`
3. Mount EFI partition and check GRUB config
4. Verify kernel files exist in /boot
5. Check boot order in EEPROM config

### Partition Table Corrupted

```bash
# Attempt recovery with testdisk
sudo apt-get install testdisk
sudo testdisk /dev/nvme0n1

# Follow prompts to analyze and recover partitions
```

### Out of Space During Installation

```bash
# Stop installation (Ctrl+C)
# Check space
df -h

# Clean up
rm artifacts/isos/*.xz  # Remove compressed files
rm artifacts/logs/old-*.log

# Resume installation
sudo ./install.sh --target /dev/nvme0n1 --distro remaining-distro
```

### Lost Access to All Systems

1. Boot from recovery media (USB/SD)
2. Mount DATA partition to retrieve files
3. Restore from backup
4. Or start installation over

## Risk Mitigation

### Minimize Risk

- ✅ Use external backup drive
- ✅ Test dry-run output carefully  
- ✅ Start with one distribution
- ✅ Verify each phase completes successfully
- ✅ Keep original installation media
- ✅ Document custom configurations
- ✅ Have recovery media ready

### Acceptable Risk Levels

**Low Risk**: Acquiring images
- Only downloads files
- No system modification
- Easily repeatable

**Medium Risk**: Installing to partitions
- Modifies target partitions
- But partition table intact
- Individual systems can be redone

**High Risk**: Preparing/partitioning
- Destroys all data
- Creates partition table
- Point of no return without backup

## Legal Disclaimer

This software is provided "as is" without warranty of any kind. Users accept all risks associated with:

- Data loss
- Hardware damage
- System instability
- Failed installations
- Corruption of data

Always maintain current backups of all important data. The authors and contributors are not responsible for any damage or loss resulting from use of these scripts.

## Summary Checklist

Before running any destructive operation:

- [ ] Created full backup of target device
- [ ] Verified backup integrity
- [ ] Confirmed correct device identifier
- [ ] Disconnected non-essential drives
- [ ] Tested with dry-run mode
- [ ] Read and understood all documentation
- [ ] Have recovery media available
- [ ] Prepared to wait for completion (hours)
- [ ] Understand that data will be permanently deleted
- [ ] Accept all risks

Only proceed when ALL items are checked.
