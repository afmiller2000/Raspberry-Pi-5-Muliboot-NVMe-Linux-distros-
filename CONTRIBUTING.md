# Contributing to Raspberry Pi 5 Multiboot NVMe Setup

Thank you for your interest in contributing! This project aims to provide a simple, reliable way to create multiboot NVMe devices for Raspberry Pi 5.

## How to Contribute

### Reporting Issues

If you encounter bugs or have feature requests:

1. Check existing issues to avoid duplicates
2. Provide detailed information:
   - Your environment (OS, Raspberry Pi model, NVMe device)
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant log files from `artifacts/logs/`
   - Script version/commit hash

### Suggesting Enhancements

We welcome suggestions for:
- Additional Linux distributions
- Improved partition layouts
- Better error handling
- Performance optimizations
- Documentation improvements

### Code Contributions

#### Before You Start

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test thoroughly
5. Submit a pull request

#### Coding Standards

**Bash Scripts**:
- Use `set -euo pipefail` at the top of scripts
- Include comprehensive error handling
- Add logging for all operations
- Use meaningful variable names in UPPER_CASE for globals
- Comment complex logic
- Follow existing code style

**Example**:
```bash
#!/bin/bash
set -euo pipefail

# Global configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$LOG_DIR/script_$(date +%Y%m%d_%H%M%S).log"

# Function with error handling
my_function() {
    local input="$1"
    
    if [[ ! -f "$input" ]]; then
        log_error "File not found: $input"
        return 1
    fi
    
    log_info "Processing $input..."
    # ... operation ...
    log_success "Completed"
}
```

**Documentation**:
- Update README.md for user-facing changes
- Update scripts/README.md for script modifications
- Include inline comments for complex operations
- Provide examples where appropriate

#### Testing Guidelines

Before submitting:

1. **Syntax Check**: Run `bash -n script.sh` on modified scripts
2. **Manual Testing**: Test your changes on actual hardware/VM
3. **Log Review**: Verify logs are clear and comprehensive
4. **Edge Cases**: Test error conditions and edge cases
5. **Documentation**: Ensure documentation matches code

**Test Checklist**:
- [ ] Scripts pass syntax check (`bash -n`)
- [ ] Tested on fresh NVMe device
- [ ] Error conditions handled gracefully
- [ ] Logs are informative
- [ ] Documentation updated
- [ ] No hardcoded paths or assumptions
- [ ] Works with different device names (`/dev/nvme0n1`, `/dev/sda`)

#### Pull Request Process

1. Update documentation to reflect your changes
2. Add your changes to the appropriate section
3. Ensure scripts are executable (`chmod +x`)
4. Test on a clean environment
5. Submit PR with clear description:
   - What problem does it solve?
   - How was it tested?
   - Any breaking changes?

### Adding New Distributions

To add support for a new Linux distribution:

1. **Update prepare.sh**:
   - Add partition creation logic
   - Update partition size calculations

2. **Update acquire.sh**:
   - Add download URL for the new distro
   - Add checksum verification
   - Document the source

3. **Update install.sh**:
   - Add installation logic for the new distro
   - Update GRUB configuration
   - Handle distro-specific kernel locations

4. **Update Documentation**:
   - Add distro to README.md
   - Update partition_plan.yaml
   - Document any special requirements

### Code Review

All contributions go through code review to ensure:
- Code quality and consistency
- Proper error handling
- Comprehensive logging
- Security considerations
- Documentation completeness

### Areas for Contribution

Current priorities (see README TODO section):
- [ ] Implement `kernels.sh` for kernel consolidation
- [ ] Create `grub-update.sh` for GRUB configuration
- [ ] Develop `report.sh` for status reporting
- [ ] Add DRY_RUN mode to all scripts
- [ ] Improve checksum verification
- [ ] Add more distribution support
- [ ] Create automated test suite
- [ ] Add boot menu customization tool

## Project Structure

```
.
├── README.md              # Main documentation
├── CONTRIBUTING.md        # This file
├── scripts/               # Core automation scripts
│   ├── README.md         # Script documentation
│   ├── prepare.sh        # Phase 1: Prepare device
│   ├── acquire.sh        # Phase 2: Acquire artifacts
│   ├── install.sh        # Phase 3: Install to device
│   └── build_multiboot_device.sh  # One-shot wrapper
└── artifacts/            # Downloaded/generated artifacts
    ├── partition_plan.yaml  # Partition specification
    ├── checksums/        # Checksum verification files
    ├── firmware/         # Raspberry Pi firmware
    ├── images/           # OS distribution images
    └── logs/             # Execution logs
```

## Development Setup

```bash
# Clone the repository
git clone https://github.com/afmiller2000/Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-.git
cd Raspberry-Pi-5-Muliboot-NVMe-Linux-distros-

# Create a feature branch
git checkout -b feature/my-feature

# Make your changes
# ... edit files ...

# Test your changes
bash -n scripts/prepare.sh
bash -n scripts/acquire.sh
bash -n scripts/install.sh

# Test functionality (use a test device or VM!)
sudo ./scripts/prepare.sh /dev/test_device  # BE CAREFUL!
./scripts/acquire.sh
sudo ./scripts/install.sh

# Commit your changes
git add .
git commit -m "Add: brief description of changes"

# Push to your fork
git push origin feature/my-feature

# Open a Pull Request on GitHub
```

## Coding Philosophy

This project follows these principles:

1. **Simplicity**: Keep operations straightforward and easy to understand
2. **Safety**: Always prioritize data safety with confirmations and validations
3. **Logging**: Comprehensive logging for troubleshooting
4. **Idempotency**: Where possible, scripts should be safe to re-run
5. **Extensibility**: Make it easy to add new distributions and features
6. **Documentation**: Code should be self-documenting with clear names and comments

## Security Considerations

When contributing:

- ⚠️ Never commit sensitive data (passwords, keys, tokens)
- ⚠️ Validate all user inputs
- ⚠️ Use absolute paths to prevent path traversal attacks
- ⚠️ Check file permissions and ownership
- ⚠️ Avoid shell injection vulnerabilities
- ⚠️ Download files only from trusted sources
- ⚠️ Verify checksums for all downloads

## Getting Help

- **Issues**: Open an issue for bugs or questions
- **Discussions**: Use GitHub Discussions for general questions
- **Documentation**: Check scripts/README.md for detailed script documentation

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project.

## Recognition

Contributors will be recognized in the project's commit history and potentially in a CONTRIBUTORS file (if created).

---

Thank you for contributing to make Raspberry Pi 5 multiboot setup easier for everyone!
