#!/bin/bash

# ==============================================================================
# CONFIGURATION & CONSTANTS
# ==============================================================================
CONFIG_FILE="/etc/logrotate.d/application"
STATE_FILE="/var/log/hourly.state"
LOCK_FILE="/var/log/log_orchestrator.lock"
SCRIPT_LOG="/var/log/log_orchestrator.log"

# ==============================================================================
# STRUCTURED LOGGING FUNCTION (JSON Output)
# ==============================================================================
log_json() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Construct clean JSON block
    local json_msg
    json_msg=$(printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' "$timestamp" "$level" "$message")

    # Output to stdout and append to central script log
    echo "$json_msg"
    echo "$json_msg" >> "$SCRIPT_LOG"
}

# ==============================================================================
# ERROR HANDLING TRAP
# ==============================================================================
handle_error() {
    local line_no=$1
    local exit_code=$2
    log_json "ERROR" "Script failed unexpectedly at line $line_no with exit code $exit_code."
    exit "$exit_code"
}
trap 'handle_error ${LINENO} $?' ERR

# ==============================================================================
# MAIN EXECUTION PIPELINE
# ==============================================================================
log_json "INFO" "Log rotation orchestrator invoked."

# 1. PERMISSION CHECK
if [ "$EUID" -ne 0 ]; then
    log_json "FATAL" "Permission denied. Script must run as root."
    exit 1
fi

# 2. FILE LOCKING (Prevents concurrent runs / race conditions)
# Open a file descriptor on the lockfile
exec 200>"$LOCK_FILE"

# Attempt an exclusive, non-blocking lock
if ! flock -n 200; then
    log_json "WARN" "Another instance of this script is currently running. Exiting to prevent concurrent execution."
    exit 0
fi

# 3. EDGE CASE CHECKS
if [ ! -f "$CONFIG_FILE" ]; then
    log_json "FATAL" "Logrotate configuration missing at $CONFIG_FILE."
    exit 1
fi

# Ensure target directory exists so logrotate doesn't complain about wildcards
mkdir -p /var/log/apps

# 4. EXECUTION
log_json "INFO" "Executing logrotate with state mapping..."

# Run logrotate. Standard output/errors caught and converted to JSON alerts if failed.
if OUTPUT=$(/sbin/logrotate -s "$STATE_FILE" "$CONFIG_FILE" 2>&1); then
    log_json "INFO" "Logrotate cycle completed cleanly."
else
    # Escape quotes in output to keep JSON formatting valid
    CLEAN_OUT=$(echo "$OUTPUT" | tr '"' "'")
    log_json "ERROR" "Logrotate encountered an issue: $CLEAN_OUT"
    exit 1
fi

log_json "INFO" "Orchestrator pipeline finalized successfully."
