#!/usr/bin/env bash
#
# install.sh - INSTALL phase for Raspberry Pi 5 NVMe Multiboot
#
# Phase: INSTALL
# Purpose: Install OS images to prepared partitions
# Operations:
#   - Copy root filesystem to target partitions
#   - Update boot artifacts (kernel, initramfs, device tree)
#   - Configure bootloader (GRUB)
#   - Summarize installation
#
# Usage: ./install.sh --target /dev/nvme0n1 [--dry-run] [--distro ubuntu,debian]
#
# This phase modifies the prepared partitions.

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Phase-specific variables
readonly PHASE_NAME="INSTALL"
readonly MOUNT_BASE="/mnt/multiboot"

# Distro configuration
declare -A DISTRO_PARTITIONS=(
    [ubuntu]=3
    [debian]=4
    [fedora]=5
    [arch]=6
)

# Additional flags
SELECTED_DISTROS=""
SKIP_GRUB_UPDATE=false

show_help() {
    cat <<EOF
Usage: $0 --target DEVICE [OPTIONS]

INSTALL phase - Install OS images to partitions

Required arguments:
    --target DEVICE     Target NVMe device (e.g., /dev/nvme0n1)

Optional arguments:
    --distro LIST       Comma-separated list of distros to install
                        (default: all available)
                        Available: ubuntu, debian, fedora, arch
    --skip-grub-update  Skip GRUB configuration update
    --dry-run           Show what would be done without executing
    --verbose, -v       Enable verbose output
    --help, -h          Show this help message

Example:
    # Install all available distros (dry run)
    $0 --target /dev/nvme0n1 --dry-run

    # Install only Ubuntu and Debian
    $0 --target /dev/nvme0n1 --distro ubuntu,debian

    # Install with verbose output
    $0 --target /dev/nvme0n1 --verbose
EOF
}

parse_install_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --distro)
                SELECTED_DISTROS="$2"
                shift 2
                ;;
            --skip-grub-update)
                SKIP_GRUB_UPDATE=true
                shift
                ;;
            *)
                # Try common args parser
                if ! parse_common_args "$@"; then
                    return 1
                fi
                return 0
                ;;
        esac
    done
    return 0
}

mount_image() {
    local image_file=$1
    local mount_point=$2
    
    log_info "Mounting image ${image_file}..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would mount ${image_file} at ${mount_point}"
        return 0
    fi
    
    # Find the root partition in the image
    local loop_device
    loop_device=$(losetup -fP --show "${image_file}")
    
    # Usually partition 2 is the root partition in Raspberry Pi images
    local root_part="${loop_device}p2"
    
    if [[ ! -b "${root_part}" ]]; then
        root_part="${loop_device}2"
    fi
    
    run_command "Create mount point" mkdir -p "${mount_point}"
    run_command "Mount root partition" mount "${root_part}" "${mount_point}"
    
    log_success "Mounted ${image_file} at ${mount_point}"
    echo "${loop_device}"
}

unmount_image() {
    local mount_point=$1
    local loop_device=$2
    
    log_info "Unmounting ${mount_point}..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would unmount ${mount_point}"
        return 0
    fi
    
    run_command "Unmount" umount "${mount_point}"
    run_command "Detach loop device" losetup -d "${loop_device}"
    
    log_success "Unmounted ${mount_point}"
}

copy_rootfs() {
    local distro=$1
    local source_mount=$2
    local target_mount=$3
    
    log_info "Copying root filesystem for ${distro}..."
    log_info "  Source: ${source_mount}"
    log_info "  Target: ${target_mount}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would copy rootfs from ${source_mount} to ${target_mount}"
        return 0
    fi
    
    # Use rsync for efficient copying with progress
    if command -v rsync &> /dev/null; then
        run_command "Copy rootfs with rsync" \
            rsync -aAXHv --info=progress2 "${source_mount}/" "${target_mount}/"
    else
        # Fallback to cp
        run_command "Copy rootfs with cp" \
            cp -a "${source_mount}/." "${target_mount}/"
    fi
    
    log_success "Root filesystem copied for ${distro}"
}

update_fstab() {
    local distro=$1
    local target_mount=$2
    local part_num=$3
    local device=$4
    
    log_info "Updating fstab for ${distro}..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would update fstab in ${target_mount}"
        return 0
    fi
    
    local fstab_file="${target_mount}/etc/fstab"
    local part_device="${device}p${part_num}"
    [[ ! -b "${part_device}" ]] && part_device="${device}${part_num}"
    
    # Get UUID of the partition
    local uuid
    uuid=$(blkid -s UUID -o value "${part_device}")
    
    # Backup original fstab
    if [[ -f "${fstab_file}" ]]; then
        cp "${fstab_file}" "${fstab_file}.backup"
    fi
    
    # Create new fstab
    cat > "${fstab_file}" <<EOF
# /etc/fstab for ${distro}
# Generated by MultiBoot NVMe installer

UUID=${uuid}  /  ext4  defaults,noatime  0  1
LABEL=EFI     /boot/efi  vfat  defaults  0  2
LABEL=BOOT    /boot      ext4  defaults  0  2
LABEL=DATA    /data      ext4  defaults  0  2
EOF
    
    log_success "Updated fstab for ${distro}"
}

install_boot_artifacts() {
    local distro=$1
    local source_mount=$2
    local boot_partition="${MOUNT_BASE}/BOOT"
    
    log_info "Installing boot artifacts for ${distro}..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would install boot artifacts for ${distro}"
        return 0
    fi
    
    local distro_boot="${boot_partition}/${distro}"
    run_command "Create distro boot directory" mkdir -p "${distro_boot}"
    
    # Copy kernel
    if [[ -d "${source_mount}/boot" ]]; then
        local kernel_file
        kernel_file=$(find "${source_mount}/boot" -name "vmlinuz-*" -o -name "kernel*" | head -1)
        
        if [[ -n "${kernel_file}" ]]; then
            run_command "Copy kernel" cp "${kernel_file}" "${distro_boot}/"
            log_success "Kernel installed for ${distro}"
        else
            log_warning "No kernel found for ${distro}"
        fi
        
        # Copy initramfs
        local initrd_file
        initrd_file=$(find "${source_mount}/boot" -name "initrd.img-*" -o -name "initramfs-*" | head -1)
        
        if [[ -n "${initrd_file}" ]]; then
            run_command "Copy initramfs" cp "${initrd_file}" "${distro_boot}/"
            log_success "Initramfs installed for ${distro}"
        fi
        
        # Copy device tree files
        if [[ -d "${source_mount}/boot/dtbs" ]]; then
            run_command "Copy DTBs" cp -r "${source_mount}/boot/dtbs" "${distro_boot}/"
        elif [[ -d "${source_mount}/boot/broadcom" ]]; then
            run_command "Copy DTBs" cp -r "${source_mount}/boot/broadcom" "${distro_boot}/"
        fi
    fi
    
    log_success "Boot artifacts installed for ${distro}"
}

update_grub_config() {
    local efi_partition="${MOUNT_BASE}/EFI"
    
    log_info "Updating GRUB configuration..."
    
    if [[ "${SKIP_GRUB_UPDATE}" == "true" ]]; then
        log_info "Skipping GRUB update (--skip-grub-update specified)"
        return 0
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would update GRUB configuration"
        return 0
    fi
    
    local grub_cfg="${efi_partition}/EFI/BOOT/grub.cfg"
    run_command "Create GRUB directory" mkdir -p "$(dirname "${grub_cfg}")"
    
    # Create basic GRUB configuration
    cat > "${grub_cfg}" <<'EOF'
# GRUB configuration for Raspberry Pi 5 Multiboot
set timeout=10
set default=0

menuentry "Ubuntu" {
    linux /ubuntu/vmlinuz root=LABEL=UBUNTU ro quiet
    initrd /ubuntu/initrd.img
}

menuentry "Debian" {
    linux /debian/vmlinuz root=LABEL=DEBIAN ro quiet
    initrd /debian/initrd.img
}

menuentry "Fedora" {
    linux /fedora/vmlinuz root=LABEL=FEDORA ro quiet
    initrd /fedora/initrd.img
}

menuentry "Arch Linux" {
    linux /arch/vmlinuz root=LABEL=ARCH ro quiet
    initrd /arch/initramfs.img
}
EOF
    
    log_success "GRUB configuration updated"
}

install_distro() {
    local distro=$1
    local image_file="${ISOS_DIR}/${distro}.img"
    
    if [[ ! -f "${image_file}" ]]; then
        log_warning "Image file not found for ${distro}: ${image_file}"
        return 1
    fi
    
    log_info "Installing ${distro}..."
    
    # Get partition number for this distro
    local part_num="${DISTRO_PARTITIONS[$distro]}"
    local target_partition="${TARGET_DEVICE}p${part_num}"
    [[ ! -b "${target_partition}" ]] && target_partition="${TARGET_DEVICE}${part_num}"
    
    local target_mount="${MOUNT_BASE}/$(echo ${distro} | tr '[:lower:]' '[:upper:]')"
    
    # Mount the image
    local temp_mount="/tmp/multiboot-${distro}"
    local loop_device
    loop_device=$(mount_image "${image_file}" "${temp_mount}")
    
    # Copy rootfs
    copy_rootfs "${distro}" "${temp_mount}" "${target_mount}"
    
    # Update fstab
    update_fstab "${distro}" "${target_mount}" "${part_num}" "${TARGET_DEVICE}"
    
    # Install boot artifacts
    install_boot_artifacts "${distro}" "${temp_mount}"
    
    # Unmount the image
    unmount_image "${temp_mount}" "${loop_device}"
    
    log_success "Installed ${distro}"
}

show_summary() {
    log_info "Installation summary:"
    
    if ! is_dry_run; then
        echo ""
        echo "Installed distributions:"
        for distro in "${!DISTRO_PARTITIONS[@]}"; do
            local part_num="${DISTRO_PARTITIONS[$distro]}"
            local target_partition="${TARGET_DEVICE}p${part_num}"
            [[ ! -b "${target_partition}" ]] && target_partition="${TARGET_DEVICE}${part_num}"
            
            if mountpoint -q "${MOUNT_BASE}/$(echo ${distro} | tr '[:lower:]' '[:upper:]')" 2>/dev/null; then
                echo "  ✓ ${distro} (${target_partition})"
            fi
        done
        
        echo ""
        echo "Mount points:"
        df -h | grep "${MOUNT_BASE}" || echo "  No mounts found"
    else
        echo "[DRY-RUN] Would show installation summary"
    fi
}

main() {
    log_info "Starting ${PHASE_NAME} phase..."
    
    # Parse arguments
    if ! parse_install_args "$@"; then
        show_help
        exit 1
    fi
    
    # Show help if requested
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Initialize common environment
    init_common
    
    # Validate requirements
    if ! is_dry_run; then
        validate_root
        check_dependency "losetup"
        check_dependency "blkid"
        
        if command -v rsync &> /dev/null; then
            log_verbose "Using rsync for efficient copying"
        else
            log_warning "rsync not found, using cp (slower)"
        fi
    fi
    
    validate_target_device
    
    # Initialize manifest
    local manifest_file
    manifest_file=$(init_manifest "${PHASE_NAME}-$(date +%Y%m%d-%H%M%S)")
    
    # Determine which distros to install
    local distros_to_install=()
    if [[ -n "${SELECTED_DISTROS}" ]]; then
        IFS=',' read -ra distros_to_install <<< "${SELECTED_DISTROS}"
    else
        distros_to_install=("${!DISTRO_PARTITIONS[@]}")
    fi
    
    log_info "Will install: ${distros_to_install[*]}"
    
    # Install each distribution
    for distro in "${distros_to_install[@]}"; do
        if [[ -z "${DISTRO_PARTITIONS[$distro]}" ]]; then
            log_warning "Unknown distro: ${distro}, skipping"
            continue
        fi
        
        install_distro "${distro}"
        append_to_manifest "${manifest_file}" "install_${distro}" "completed" "Installed to partition ${DISTRO_PARTITIONS[$distro]}"
    done
    
    # Update GRUB configuration
    update_grub_config
    append_to_manifest "${manifest_file}" "update_grub" "completed" "GRUB configured"
    
    # Show summary
    show_summary
    
    # Finalize manifest
    finalize_manifest "${manifest_file}" "success"
    
    log_success "${PHASE_NAME} phase completed successfully!"
    log_info "Manifest saved to: ${manifest_file}"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Review the installation"
    log_info "  2. Unmount all partitions: umount ${MOUNT_BASE}/*"
    log_info "  3. Reboot and select OS from GRUB menu"
}

# Run main function
main "$@"
