#!/usr/bin/env bash
#
# prepare.sh - PREPARE phase for Raspberry Pi 5 NVMe Multiboot
#
# Phase: PREPARE
# Purpose: Prepare the NVMe drive for multiboot installation
# Operations:
#   - Wipe existing partition table
#   - Format partitions
#   - Label partitions
#   - Mount partitions
#
# Usage: ./prepare.sh --target /dev/nvme0n1 --yes --execute [--dry-run]
#
# WARNING: This script performs DESTRUCTIVE operations!
# Requires --yes and --execute flags to confirm.

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Phase-specific variables
readonly PHASE_NAME="PREPARE"
readonly MOUNT_BASE="/mnt/multiboot"

# Partition configuration
declare -A PARTITIONS=(
    [1]="EFI:512M:vfat:EFI System Partition"
    [2]="BOOT:1G:ext4:Shared Boot"
    [3]="UBUNTU:30G:ext4:Ubuntu Root"
    [4]="DEBIAN:30G:ext4:Debian Root"
    [5]="FEDORA:30G:ext4:Fedora Root"
    [6]="ARCH:30G:ext4:Arch Root"
    [7]="DATA:0:ext4:Shared Data"
)

show_help() {
    cat <<EOF
Usage: $0 --target DEVICE --yes --execute [OPTIONS]

PREPARE phase - Prepare NVMe drive for multiboot

Required arguments:
    --target DEVICE     Target NVMe device (e.g., /dev/nvme0n1)
    --yes               Confirm destructive operation
    --execute           Confirm execution (required with --yes)

Optional arguments:
    --dry-run           Show what would be done without executing
    --verbose, -v       Enable verbose output
    --help, -h          Show this help message

Example:
    # Dry run to see what will happen
    $0 --target /dev/nvme0n1 --yes --execute --dry-run

    # Actually execute (DESTRUCTIVE!)
    $0 --target /dev/nvme0n1 --yes --execute

WARNING: This will DESTROY all data on the target device!
EOF
}

wipe_device() {
    local device=$1
    
    log_info "Wiping partition table on ${device}..."
    
    run_command "Wipe partition table" \
        sgdisk --zap-all "${device}"
    
    run_command "Wipe filesystem signatures" \
        wipefs -a "${device}"
    
    log_success "Device wiped: ${device}"
}

create_partitions() {
    local device=$1
    
    log_info "Creating partition table on ${device}..."
    
    run_command "Create GPT partition table" \
        parted -s "${device}" mklabel gpt
    
    local part_num=1
    local start="1MiB"
    
    for key in $(echo "${!PARTITIONS[@]}" | tr ' ' '\n' | sort -n); do
        IFS=':' read -r label size fstype desc <<< "${PARTITIONS[$key]}"
        
        local end
        if [[ "${size}" == "0" ]]; then
            end="100%"
        else
            end="${size}"
        fi
        
        log_info "Creating partition ${part_num}: ${label} (${desc})"
        
        if [[ $part_num -eq 1 ]]; then
            # EFI partition
            run_command "Create EFI partition" \
                parted -s "${device}" mkpart "${label}" fat32 "${start}" "${end}"
            run_command "Set EFI boot flag" \
                parted -s "${device}" set "${part_num}" boot on
        else
            run_command "Create partition ${label}" \
                parted -s "${device}" mkpart "${label}" ext4 "${start}" "${end}"
        fi
        
        if [[ "${size}" != "0" ]]; then
            start="${end}"
        fi
        
        ((part_num++))
    done
    
    log_success "Partitions created on ${device}"
}

format_partitions() {
    local device=$1
    
    log_info "Formatting partitions on ${device}..."
    
    # Wait for kernel to recognize partitions
    run_command "Sync partition table" \
        partprobe "${device}"
    
    sleep 2
    
    for key in $(echo "${!PARTITIONS[@]}" | tr ' ' '\n' | sort -n); do
        IFS=':' read -r label size fstype desc <<< "${PARTITIONS[$key]}"
        
        local part_device="${device}p${key}"
        [[ ! -b "${part_device}" ]] && part_device="${device}${key}"
        
        log_info "Formatting ${part_device} as ${fstype} (${label})..."
        
        case "${fstype}" in
            vfat)
                run_command "Format EFI partition" \
                    mkfs.vfat -F 32 -n "${label}" "${part_device}"
                ;;
            ext4)
                run_command "Format ext4 partition ${label}" \
                    mkfs.ext4 -F -L "${label}" "${part_device}"
                ;;
            *)
                log_warning "Unknown filesystem type: ${fstype}"
                ;;
        esac
    done
    
    log_success "All partitions formatted"
}

mount_partitions() {
    local device=$1
    
    log_info "Mounting partitions from ${device}..."
    
    # Create mount points
    for key in $(echo "${!PARTITIONS[@]}" | tr ' ' '\n' | sort -n); do
        IFS=':' read -r label size fstype desc <<< "${PARTITIONS[$key]}"
        local mount_point="${MOUNT_BASE}/${label}"
        
        run_command "Create mount point ${mount_point}" \
            mkdir -p "${mount_point}"
    done
    
    # Mount partitions
    for key in $(echo "${!PARTITIONS[@]}" | tr ' ' '\n' | sort -n); do
        IFS=':' read -r label size fstype desc <<< "${PARTITIONS[$key]}"
        
        local part_device="${device}p${key}"
        [[ ! -b "${part_device}" ]] && part_device="${device}${key}"
        
        local mount_point="${MOUNT_BASE}/${label}"
        
        log_info "Mounting ${part_device} at ${mount_point}..."
        run_command "Mount ${label}" \
            mount "${part_device}" "${mount_point}"
    done
    
    log_success "All partitions mounted under ${MOUNT_BASE}"
}

show_summary() {
    local device=$1
    
    log_info "Partition layout summary:"
    
    if ! is_dry_run; then
        lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "${device}" || true
    else
        echo "[DRY-RUN] Would show partition layout for ${device}"
    fi
}

main() {
    log_info "Starting ${PHASE_NAME} phase..."
    
    # Parse arguments
    if ! parse_common_args "$@"; then
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
    
    # Validate execution requirements
    if ! is_dry_run; then
        validate_root
    fi
    
    validate_target_device
    validate_destructive_operation "${PHASE_NAME}"
    
    # Initialize manifest
    local manifest_file
    manifest_file=$(init_manifest "${PHASE_NAME}-$(date +%Y%m%d-%H%M%S)")
    
    # Show device info
    log_info "Target device information:"
    get_device_info "${TARGET_DEVICE}"
    
    # Confirm with user
    if ! is_dry_run; then
        log_warning "This will DESTROY all data on ${TARGET_DEVICE}!"
        echo -n "Type 'yes' to continue: "
        read -r confirmation
        if [[ "${confirmation}" != "yes" ]]; then
            die "Operation cancelled by user"
        fi
    fi
    
    # Execute prepare operations
    wipe_device "${TARGET_DEVICE}"
    append_to_manifest "${manifest_file}" "wipe_device" "completed" "${TARGET_DEVICE}"
    
    create_partitions "${TARGET_DEVICE}"
    append_to_manifest "${manifest_file}" "create_partitions" "completed" "7 partitions created"
    
    format_partitions "${TARGET_DEVICE}"
    append_to_manifest "${manifest_file}" "format_partitions" "completed" "All partitions formatted"
    
    mount_partitions "${TARGET_DEVICE}"
    append_to_manifest "${manifest_file}" "mount_partitions" "completed" "Mounted at ${MOUNT_BASE}"
    
    # Show summary
    show_summary "${TARGET_DEVICE}"
    
    # Finalize manifest
    finalize_manifest "${manifest_file}" "success"
    
    log_success "${PHASE_NAME} phase completed successfully!"
    log_info "Manifest saved to: ${manifest_file}"
    log_info "Next step: Run acquire.sh to download and prepare OS images"
}

# Run main function
main "$@"
