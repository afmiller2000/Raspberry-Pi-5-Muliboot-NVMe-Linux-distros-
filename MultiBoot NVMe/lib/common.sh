#!/usr/bin/env bash
#
# common.sh - Shared utilities for Raspberry Pi 5 NVMe Multiboot
#
# Provides logging, validation, manifest generation, and common functions
# for all multiboot scripts.

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# Script metadata
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"
readonly LOGS_DIR="${ARTIFACTS_DIR}/logs"
readonly MANIFESTS_DIR="${ARTIFACTS_DIR}/manifests"
readonly ISOS_DIR="${ARTIFACTS_DIR}/isos"

# Color codes for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Global flags
DRY_RUN=false
VERBOSE=false
TARGET_DEVICE=""
YES_CONFIRMED=false
EXECUTE_CONFIRMED=false

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${COLOR_BLUE}[VERBOSE]${COLOR_RESET} $*" >&2
    fi
}

# Error handling
die() {
    log_error "$@"
    exit 1
}

# Validation functions
validate_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root"
    fi
}

validate_target_device() {
    if [[ -z "${TARGET_DEVICE}" ]]; then
        die "Target device not specified. Use --target /dev/sdX"
    fi
    
    if [[ ! -b "${TARGET_DEVICE}" ]]; then
        die "Target device ${TARGET_DEVICE} is not a block device"
    fi
    
    log_verbose "Validated target device: ${TARGET_DEVICE}"
}

validate_destructive_operation() {
    local operation=$1
    
    if [[ "${YES_CONFIRMED}" != "true" ]]; then
        die "${operation} requires --yes flag to confirm destructive operation"
    fi
    
    if [[ "${EXECUTE_CONFIRMED}" != "true" ]]; then
        die "${operation} requires --execute flag to confirm execution"
    fi
    
    log_verbose "Validated destructive operation: ${operation}"
}

# Dry run wrapper
run_command() {
    local description=$1
    shift
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] ${description}"
        log_verbose "[DRY-RUN] Command: $*"
        return 0
    else
        log_verbose "Executing: $*"
        "$@"
    fi
}

# Manifest generation
init_manifest() {
    local manifest_name=$1
    local manifest_file="${MANIFESTS_DIR}/${manifest_name}.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p "${MANIFESTS_DIR}"
    
    cat > "${manifest_file}" <<EOF
{
  "manifest_name": "${manifest_name}",
  "timestamp": "${timestamp}",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "operations": []
}
EOF
    
    log_verbose "Initialized manifest: ${manifest_file}"
    echo "${manifest_file}"
}

append_to_manifest() {
    local manifest_file=$1
    local operation=$2
    local status=$3
    local details=$4
    
    if [[ ! -f "${manifest_file}" ]]; then
        log_warning "Manifest file not found: ${manifest_file}"
        return 1
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_file=$(mktemp)
    
    # Read current manifest and append operation
    jq --arg op "${operation}" \
       --arg st "${status}" \
       --arg det "${details}" \
       --arg ts "${timestamp}" \
       '.operations += [{"operation": $op, "status": $st, "details": $det, "timestamp": $ts}]' \
       "${manifest_file}" > "${temp_file}" && mv "${temp_file}" "${manifest_file}"
    
    log_verbose "Appended to manifest: ${operation} [${status}]"
}

finalize_manifest() {
    local manifest_file=$1
    local final_status=$2
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_file=$(mktemp)
    
    jq --arg st "${final_status}" \
       --arg ts "${timestamp}" \
       '.final_status = $st | .completed_at = $ts' \
       "${manifest_file}" > "${temp_file}" && mv "${temp_file}" "${manifest_file}"
    
    log_success "Finalized manifest: ${manifest_file} [${final_status}]"
}

# Directory setup
ensure_directories() {
    mkdir -p "${ARTIFACTS_DIR}" "${LOGS_DIR}" "${MANIFESTS_DIR}" "${ISOS_DIR}"
    log_verbose "Ensured artifact directories exist"
}

# Device information
get_device_info() {
    local device=$1
    
    if [[ ! -b "${device}" ]]; then
        echo "Device not found"
        return 1
    fi
    
    echo "Device: ${device}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "${device}" 2>/dev/null || echo "Unable to get device info"
}

# Check if running in dry-run mode
is_dry_run() {
    [[ "${DRY_RUN}" == "true" ]]
}

# Parse common arguments
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_info "Dry-run mode enabled"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                log_verbose "Verbose mode enabled"
                shift
                ;;
            --target)
                TARGET_DEVICE="$2"
                shift 2
                ;;
            --yes)
                YES_CONFIRMED=true
                shift
                ;;
            --execute)
                EXECUTE_CONFIRMED=true
                shift
                ;;
            --help|-h)
                return 1
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    return 0
}

# Check dependencies
check_dependency() {
    local cmd=$1
    if ! command -v "${cmd}" &> /dev/null; then
        die "Required command not found: ${cmd}"
    fi
    log_verbose "Dependency check passed: ${cmd}"
}

# Initialize common environment
init_common() {
    ensure_directories
    
    # Check for jq (required for manifest generation)
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found. Manifest generation will be disabled."
    fi
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_verbose
export -f die validate_root validate_target_device validate_destructive_operation
export -f run_command init_manifest append_to_manifest finalize_manifest
export -f ensure_directories get_device_info is_dry_run check_dependency
