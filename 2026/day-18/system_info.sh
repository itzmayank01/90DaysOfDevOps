#!/bin/bash
set -euo pipefail

print_header() {
    echo "======================================"
    echo "$1"
    echo "======================================"
}

system_info() {
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -o)"
}

uptime_info() {
    print_header "UPTIME"
    uptime
}

disk_usage() {
    print_header "TOP 5 DISK USAGE"
    du -h / 2>/dev/null | sort -rh | head -n 5
}

memory_usage() {
    free -h
}

top_processes() {
    print_header "TOP 5 CPU PROCESSES"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 6
}

top_processes
memory_usage
disk_usage
system_info
uptime_info