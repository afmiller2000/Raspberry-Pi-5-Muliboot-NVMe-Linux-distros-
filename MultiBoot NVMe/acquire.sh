#!/usr/bin/env bash
#
# acquire.sh - ACQUIRE phase for Raspberry Pi 5 NVMe Multiboot
#
# Phase: ACQUIRE
# Purpose: Download OS images, verify checksums, and stage firmware
# Operations:
#   - Download distribution images
#   - Verify SHA256 checksums
#   - Stage firmware files
#   - Create EFI directory tree
#
# Usage: ./acquire.sh [--dry-run] [--verbose]
#
# This phase does NOT require destructive flags as it only downloads files.

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Phase-specific variables
readonly PHASE_NAME="ACQUIRE"

# Distribution image URLs (examples - should be updated with actual URLs)
declare -A DISTRO_IMAGES=(
    [ubuntu]="https://cdimage.ubuntu.com/releases/23.10/release/ubuntu-23.10-preinstalled-server-arm64+raspi.img.xz"
    [debian]="https://raspi.debian.net/tested-images/debian-12-arm64.img.xz"
)

# SHA256 checksums (examples - should be updated with actual checksums)
declare -A DISTRO_CHECKSUMS=(
    [ubuntu]="PLACEHOLDER_UBUNTU_SHA256"
    [debian]="PLACEHOLDER_DEBIAN_SHA256"
)

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

ACQUIRE phase - Download and prepare OS images

Optional arguments:
    --dry-run           Show what would be done without executing
    --verbose, -v       Enable verbose output
    --skip-download     Skip downloading images (use existing)
    --skip-verify       Skip checksum verification (not recommended)
    --help, -h          Show this help message

Example:
    # Download all images and verify
    $0

    # Dry run to see what will be downloaded
    $0 --dry-run

    # Skip downloads if images already exist
    $0 --skip-download

Note: This phase downloads large files. Ensure sufficient disk space
and a stable internet connection.
EOF
}

# Additional flags for this phase
SKIP_DOWNLOAD=false
SKIP_VERIFY=false

parse_acquire_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-download)
                SKIP_DOWNLOAD=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                log_warning "Checksum verification disabled"
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

download_image() {
    local distro=$1
    local url=$2
    local output_file="${ISOS_DIR}/${distro}.img.xz"
    
    if [[ "${SKIP_DOWNLOAD}" == "true" ]] && [[ -f "${output_file}" ]]; then
        log_info "Skipping download of ${distro} (file exists)"
        return 0
    fi
    
    log_info "Downloading ${distro} image..."
    log_verbose "URL: ${url}"
    log_verbose "Output: ${output_file}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would download ${distro} from ${url}"
        return 0
    fi
    
    # Use wget with resume support
    if command -v wget &> /dev/null; then
        run_command "Download ${distro}" \
            wget -c -O "${output_file}" "${url}"
    elif command -v curl &> /dev/null; then
        run_command "Download ${distro}" \
            curl -L -C - -o "${output_file}" "${url}"
    else
        die "Neither wget nor curl is available for downloading"
    fi
    
    log_success "Downloaded ${distro} image"
}

verify_checksum() {
    local distro=$1
    local expected_checksum=$2
    local image_file="${ISOS_DIR}/${distro}.img.xz"
    
    if [[ "${SKIP_VERIFY}" == "true" ]]; then
        log_warning "Skipping checksum verification for ${distro}"
        return 0
    fi
    
    if [[ "${expected_checksum}" == "PLACEHOLDER_"* ]]; then
        log_warning "No checksum available for ${distro}, skipping verification"
        return 0
    fi
    
    if [[ ! -f "${image_file}" ]]; then
        log_warning "Image file not found, skipping verification: ${image_file}"
        return 0
    fi
    
    log_info "Verifying checksum for ${distro}..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would verify checksum for ${distro}"
        return 0
    fi
    
    local actual_checksum
    actual_checksum=$(sha256sum "${image_file}" | awk '{print $1}')
    
    if [[ "${actual_checksum}" == "${expected_checksum}" ]]; then
        log_success "Checksum verified for ${distro}"
    else
        log_error "Checksum mismatch for ${distro}!"
        log_error "Expected: ${expected_checksum}"
        log_error "Actual:   ${actual_checksum}"
        die "Checksum verification failed for ${distro}"
    fi
}

extract_image() {
    local distro=$1
    local compressed_file="${ISOS_DIR}/${distro}.img.xz"
    local extracted_file="${ISOS_DIR}/${distro}.img"
    
    if [[ ! -f "${compressed_file}" ]]; then
        log_warning "Compressed file not found: ${compressed_file}"
        return 0
    fi
    
    if [[ -f "${extracted_file}" ]]; then
        log_info "Extracted image already exists: ${extracted_file}"
        return 0
    fi
    
    log_info "Extracting ${distro} image..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would extract ${compressed_file}"
        return 0
    fi
    
    run_command "Extract ${distro}" \
        xz -dk "${compressed_file}"
    
    log_success "Extracted ${distro} image"
}

download_firmware() {
    local firmware_dir="${ISOS_DIR}/firmware"
    
    log_info "Downloading Raspberry Pi firmware..."
    
    run_command "Create firmware directory" \
        mkdir -p "${firmware_dir}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would download firmware to ${firmware_dir}"
        return 0
    fi
    
    # Download essential firmware files
    local base_url="https://github.com/raspberrypi/firmware/raw/master/boot"
    local files=(
        "start4.elf"
        "fixup4.dat"
        "bcm2711-rpi-4-b.dtb"
        "bcm2712-rpi-5-b.dtb"
    )
    
    for file in "${files[@]}"; do
        log_info "Downloading ${file}..."
        if command -v wget &> /dev/null; then
            run_command "Download ${file}" \
                wget -q -O "${firmware_dir}/${file}" "${base_url}/${file}" || log_warning "Failed to download ${file}"
        elif command -v curl &> /dev/null; then
            run_command "Download ${file}" \
                curl -sL -o "${firmware_dir}/${file}" "${base_url}/${file}" || log_warning "Failed to download ${file}"
        fi
    done
    
    log_success "Firmware files downloaded"
}

create_efi_tree() {
    local efi_dir="${ISOS_DIR}/efi-tree"
    
    log_info "Creating EFI directory tree..."
    
    run_command "Create EFI directory structure" \
        mkdir -p "${efi_dir}"/{EFI/BOOT,firmware}
    
    log_success "EFI tree created at ${efi_dir}"
}

show_summary() {
    log_info "Download summary:"
    
    if ! is_dry_run; then
        echo "Images in ${ISOS_DIR}:"
        ls -lh "${ISOS_DIR}"/*.img.xz 2>/dev/null || echo "  No compressed images found"
        ls -lh "${ISOS_DIR}"/*.img 2>/dev/null || echo "  No extracted images found"
        
        if [[ -d "${ISOS_DIR}/firmware" ]]; then
            echo ""
            echo "Firmware files:"
            ls -lh "${ISOS_DIR}/firmware/" 2>/dev/null || echo "  No firmware files found"
        fi
    else
        echo "[DRY-RUN] Would show downloaded files"
    fi
}

main() {
    log_info "Starting ${PHASE_NAME} phase..."
    
    # Parse arguments
    if ! parse_acquire_args "$@"; then
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
    
    # Check dependencies
    if ! is_dry_run; then
        if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
            die "Neither wget nor curl is available"
        fi
        
        check_dependency "sha256sum"
        check_dependency "xz"
    fi
    
    # Initialize manifest
    local manifest_file
    manifest_file=$(init_manifest "${PHASE_NAME}-$(date +%Y%m%d-%H%M%S)")
    
    # Download distribution images
    for distro in "${!DISTRO_IMAGES[@]}"; do
        download_image "${distro}" "${DISTRO_IMAGES[$distro]}"
        append_to_manifest "${manifest_file}" "download_${distro}" "completed" "${DISTRO_IMAGES[$distro]}"
        
        verify_checksum "${distro}" "${DISTRO_CHECKSUMS[$distro]}"
        append_to_manifest "${manifest_file}" "verify_${distro}" "completed" "Checksum verified"
        
        extract_image "${distro}"
        append_to_manifest "${manifest_file}" "extract_${distro}" "completed" "Image extracted"
    done
    
    # Download firmware
    download_firmware
    append_to_manifest "${manifest_file}" "download_firmware" "completed" "Firmware staged"
    
    # Create EFI tree
    create_efi_tree
    append_to_manifest "${manifest_file}" "create_efi_tree" "completed" "EFI structure created"
    
    # Show summary
    show_summary
    
    # Finalize manifest
    finalize_manifest "${manifest_file}" "success"
    
    log_success "${PHASE_NAME} phase completed successfully!"
    log_info "Manifest saved to: ${manifest_file}"
    log_info "Next step: Run install.sh to install OS images to partitions"
}

# Run main function
main "$@"
