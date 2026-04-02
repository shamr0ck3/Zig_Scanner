#!/bin/bash
CSV_FILE="${SCRIPT_DIR}/green/scan_logs/server_kernel_scan.csv"

csv_init() {
    mkdir -p "$(dirname "$CSV_FILE")"
    if [ ! -f "$CSV_FILE" ]; then
        echo "timestamp,target,server_software,server_version,kernel_version,is_old" > "$CSV_FILE"
    fi
}

csv_log () {
    local target="$1"
    local server_soft="$2"
    local server_ver="$3"
    local kernel_ver="$4"
    local is_old="$5"
    local timestamp=$(date +%Y-%m-%d_%H:%M:%S)
    echo "$timestamp,$target,$server_soft,$server_ver,$kernel_ver,$is_old" >> "$CSV_FILE"
}
