#!/bin/bash

check_disk() {
    echo "Disk Usage:"
    df -h /
}

check_memory() {
    echo "Memory Usage:"
    free -h
}

main() {
    echo "==== system resource check ====="
    check_disk
    echo
    check_memory
}

main