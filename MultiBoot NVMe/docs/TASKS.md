# Development Tasks and Roadmap

Project tasks, feature requests, and development roadmap for the Raspberry Pi 5 NVMe Multiboot system.

## Project Status

### Current Version: 1.0.0-alpha

**Status**: Initial implementation complete

**What Works**:
- ✅ Three-phase installation (PREPARE, ACQUIRE, INSTALL)
- ✅ Bash strict mode and error handling
- ✅ Dry-run mode for all operations
- ✅ Destructive operation safeguards (--yes --execute)
- ✅ Comprehensive logging and manifest generation
- ✅ Shared library (lib/common.sh)
- ✅ Support for Ubuntu and Debian
- ✅ Basic GRUB configuration
- ✅ Complete documentation

**What Needs Work**:
- ⚠️ Distribution URLs need updating with current versions
- ⚠️ SHA256 checksums are placeholders
- ⚠️ Fedora and Arch support is stubbed out
- ⚠️ GRUB configuration needs testing on actual hardware
- ⚠️ Firmware download URLs may need updating

## Immediate Tasks (v1.0.0)

### Critical (Before First Release)

- [ ] **Update distribution URLs**
  - [ ] Find current Ubuntu Server ARM64 for Raspberry Pi 5
  - [ ] Find current Debian ARM64 for Raspberry Pi 5
  - [ ] Verify URLs are stable and maintained
  - [ ] Test downloads complete successfully

- [ ] **Add real SHA256 checksums**
  - [ ] Calculate checksums for each distribution
  - [ ] Update DISTRO_CHECKSUMS in acquire.sh
  - [ ] Test verification works correctly
  - [ ] Document how to update checksums

- [ ] **Test on actual Raspberry Pi 5**
  - [ ] Test PREPARE phase on real NVMe
  - [ ] Test ACQUIRE downloads work
  - [ ] Test INSTALL copies files correctly
  - [ ] Verify system boots from NVMe
  - [ ] Test GRUB menu appears and works

- [ ] **Fix any boot issues**
  - [ ] Verify kernel paths are correct
  - [ ] Ensure initramfs files are found
  - [ ] Check device tree blob locations
  - [ ] Test firmware files are adequate

### High Priority

- [ ] **Add .gitignore file**
  - [ ] Ignore artifacts/isos/*.img*
  - [ ] Ignore artifacts/logs/
  - [ ] Ignore artifacts/manifests/
  - [ ] Keep directory structure

- [ ] **Improve error messages**
  - [ ] Add helpful suggestions for common errors
  - [ ] Include recovery instructions
  - [ ] Link to relevant documentation

- [ ] **Add progress indicators**
  - [ ] Show progress during downloads
  - [ ] Show progress during rsync
  - [ ] Estimate time remaining

- [ ] **Validate script syntax**
  - [ ] Run shellcheck on all scripts
  - [ ] Fix any warnings or errors
  - [ ] Add shellcheck to documentation

### Medium Priority

- [ ] **Add uninstall/cleanup script**
  - [ ] Unmount all partitions
  - [ ] Remove artifacts
  - [ ] Optional: wipe NVMe (with confirmation)

- [ ] **Add status/info script**
  - [ ] Show installed distributions
  - [ ] Show disk usage per distro
  - [ ] Show boot configuration
  - [ ] List available kernels

- [ ] **Improve manifest format**
  - [ ] Add duration for each operation
  - [ ] Add resource usage (disk, memory)
  - [ ] Add checksum verification results
  - [ ] Make manifests more queryable

## Feature Roadmap

### Version 1.1.0 - Enhanced Distributions

- [ ] **Full Fedora support**
  - [ ] Find Fedora ARM64 images for Raspberry Pi
  - [ ] Test installation process
  - [ ] Update GRUB configuration
  - [ ] Document Fedora-specific setup

- [ ] **Full Arch Linux support**
  - [ ] Find Arch ARM64 images for Raspberry Pi
  - [ ] Handle Arch's rolling release model
  - [ ] Update GRUB configuration
  - [ ] Document Arch-specific setup

- [ ] **Add more distributions**
  - [ ] OpenSUSE
  - [ ] Manjaro
  - [ ] Gentoo (if feasible)
  - [ ] Alpine Linux

### Version 1.2.0 - Kernel Management

- [ ] **Kernel selection system**
  - [ ] List available kernels per distro
  - [ ] Allow kernel selection at install time
  - [ ] Support multiple kernels per distro
  - [ ] Add GRUB submenu for kernel selection

- [ ] **Kernel update script**
  - [ ] Detect new kernels
  - [ ] Update GRUB configuration
  - [ ] Backup old configuration
  - [ ] Test new kernel boots

- [ ] **Kernel fallback**
  - [ ] Keep previous kernel
  - [ ] Add fallback menu entries
  - [ ] Auto-select fallback on boot failure

### Version 1.3.0 - GRUB Enhancements

- [ ] **GRUB theme support**
  - [ ] Add graphical theme
  - [ ] Customize colors and fonts
  - [ ] Add Raspberry Pi logo
  - [ ] Make theme configurable

- [ ] **GRUB customization**
  - [ ] Allow custom menu entries
  - [ ] Support GRUB modules
  - [ ] Add rescue mode entries
  - [ ] Configure default OS and timeout

- [ ] **Advanced boot options**
  - [ ] Add recovery mode
  - [ ] Add single-user mode
  - [ ] Add memory test
  - [ ] Add firmware update mode

### Version 1.4.0 - Update Management

- [ ] **System update script**
  - [ ] Update all distributions
  - [ ] Update kernels
  - [ ] Update firmware
  - [ ] Create snapshots before updating

- [ ] **Update notifications**
  - [ ] Check for distribution updates
  - [ ] Check for script updates
  - [ ] Email/notify on updates available

- [ ] **Automated updates**
  - [ ] Schedule automatic updates
  - [ ] Rollback on failure
  - [ ] Log update history

### Version 1.5.0 - Backup and Recovery

- [ ] **Backup script**
  - [ ] Backup individual distributions
  - [ ] Backup shared partitions (BOOT, DATA)
  - [ ] Incremental backups
  - [ ] Compressed backups

- [ ] **Recovery script**
  - [ ] Restore from backup
  - [ ] Restore specific distribution
  - [ ] Verify backup integrity
  - [ ] List available backups

- [ ] **Snapshot support**
  - [ ] LVM snapshots (optional)
  - [ ] Btrfs snapshots (optional)
  - [ ] Snapshot before updates
  - [ ] Rollback to snapshot

### Version 2.0.0 - Advanced Features

- [ ] **Web interface**
  - [ ] View installed distributions
  - [ ] Manage boot order
  - [ ] View logs and manifests
  - [ ] Trigger updates

- [ ] **Container support**
  - [ ] Docker installation
  - [ ] Kubernetes (K3s) option
  - [ ] Shared container registry
  - [ ] Container networking

- [ ] **Monitoring and alerts**
  - [ ] Disk usage monitoring
  - [ ] Temperature monitoring
  - [ ] Boot failure alerts
  - [ ] Health checks

- [ ] **Multi-device support**
  - [ ] Support multiple NVMe drives
  - [ ] Support SATA SSDs
  - [ ] RAID configuration
  - [ ] Distributed storage

## Technical Improvements

### Code Quality

- [ ] **Testing framework**
  - [ ] Unit tests for common.sh functions
  - [ ] Integration tests for phases
  - [ ] Mock mode for testing without hardware
  - [ ] Automated test suite

- [ ] **Code review**
  - [ ] Run shellcheck on all scripts
  - [ ] Fix all warnings
  - [ ] Standardize coding style
  - [ ] Add code comments

- [ ] **Performance optimization**
  - [ ] Optimize rsync parameters
  - [ ] Parallel downloads in acquire.sh
  - [ ] Reduce disk I/O
  - [ ] Cache frequently accessed data

### Documentation

- [ ] **Video tutorials**
  - [ ] Installation walkthrough
  - [ ] Troubleshooting guide
  - [ ] Advanced configuration

- [ ] **FAQ document**
  - [ ] Common questions and answers
  - [ ] Troubleshooting steps
  - [ ] Best practices

- [ ] **Architecture diagrams**
  - [ ] System architecture
  - [ ] Data flow diagrams
  - [ ] Boot process flowchart

### User Experience

- [ ] **Interactive mode**
  - [ ] Guided installation wizard
  - [ ] Interactive partition sizing
  - [ ] Distribution selection menu
  - [ ] Configuration validation

- [ ] **Configuration file**
  - [ ] YAML or JSON configuration
  - [ ] Pre-defined profiles
  - [ ] Custom partition layouts
  - [ ] Distribution preferences

- [ ] **Better progress reporting**
  - [ ] Progress bars
  - [ ] Time estimates
  - [ ] Detailed status messages
  - [ ] Success/failure summaries

## Bug Fixes and Issues

### Known Issues

1. **GRUB paths may be incorrect**
   - Kernel paths depend on distribution structure
   - Need to dynamically detect kernel files
   - Solution: Add kernel detection logic

2. **Firmware downloads may fail**
   - GitHub URLs may change
   - Need fallback sources
   - Solution: Add mirror support

3. **No rollback on partial failure**
   - If install.sh fails mid-way, state is inconsistent
   - Solution: Add transaction support or cleanup

4. **No disk space validation**
   - Scripts don't check if enough space before starting
   - Solution: Add pre-flight space checks

5. **Mount points may conflict**
   - If /mnt/multiboot already used
   - Solution: Add mount point validation

### Bugs to Fix

- [ ] Fix mount point conflicts
- [ ] Add disk space validation
- [ ] Improve error recovery
- [ ] Handle interrupted operations
- [ ] Fix permission issues

## Community and Contributions

### How to Contribute

1. **Report issues**
   - Use GitHub issues
   - Include logs and manifests
   - Describe hardware configuration
   - List steps to reproduce

2. **Submit pull requests**
   - Follow coding style
   - Include tests
   - Update documentation
   - Reference related issues

3. **Documentation improvements**
   - Fix typos and errors
   - Add examples
   - Improve clarity
   - Translate to other languages

4. **Testing**
   - Test on different hardware
   - Try different distributions
   - Test edge cases
   - Report results

### Contribution Guidelines

- Follow bash best practices
- Use shellcheck
- Maintain bash strict mode
- Write clear commit messages
- Update relevant documentation
- Test changes thoroughly
- Respect existing code style

## Long-term Vision

### Goals

1. **Reference implementation**
   - Become the standard for Pi 5 multiboot
   - Well-documented and maintained
   - Community-driven development

2. **Flexibility**
   - Support any ARM64 distribution
   - Work with various storage types
   - Configurable for different use cases

3. **Reliability**
   - Comprehensive error handling
   - Extensive testing
   - Safe and predictable operation

4. **User-friendly**
   - Easy for beginners
   - Powerful for advanced users
   - Clear documentation

5. **Maintained**
   - Keep URLs updated
   - Support new distributions
   - Fix bugs promptly
   - Respond to community feedback

## Development Environment

### Setup Development Environment

```bash
# Install development tools
sudo apt-get install -y shellcheck shfmt

# Clone repository
git clone <repository-url>
cd Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-

# Navigate to scripts
cd "MultiBoot NVMe"

# Check scripts with shellcheck
shellcheck *.sh lib/*.sh

# Format scripts with shfmt
shfmt -w -i 4 *.sh lib/*.sh
```

### Testing Workflow

```bash
# 1. Test syntax
shellcheck script.sh

# 2. Test dry-run
./script.sh --dry-run

# 3. Test with verbose
./script.sh --verbose --dry-run

# 4. Review logs
cat artifacts/logs/*.log

# 5. Review manifests
cat artifacts/manifests/*.json | jq .

# 6. Test on actual hardware
# (with backups!)
```

## Resources

### Useful Links

- Raspberry Pi 5 Documentation: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html
- NVMe Boot Guide: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#nvme-ssd-boot
- GRUB Documentation: https://www.gnu.org/software/grub/manual/
- Bash Best Practices: https://google.github.io/styleguide/shellguide.html

### Distribution Resources

- Ubuntu ARM: https://ubuntu.com/download/raspberry-pi
- Debian ARM: https://raspi.debian.net/
- Fedora ARM: https://fedoraproject.org/wiki/Architectures/ARM
- Arch ARM: https://archlinuxarm.org/

## Changelog

### Version 1.0.0-alpha (Current)
- Initial implementation
- Three-phase installation system
- Bash strict mode throughout
- Dry-run support
- Comprehensive documentation
- Manifest generation
- Safety features

### Planned for 1.0.0 (Stable)
- Updated distribution URLs
- Real SHA256 checksums
- Hardware testing completed
- All critical bugs fixed
- .gitignore added

## Contact and Support

For questions, issues, or contributions:
- GitHub Issues: (repository URL)
- Documentation: See docs/ directory
- Community: (forum/chat if available)

---

**Note**: This is a living document. Tasks and priorities may change based on community feedback and testing results.
