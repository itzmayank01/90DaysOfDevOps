#!/bin/bash

SERVICE="ssh"

read -p "Do you want to check the status? (y/n): " CHOICE

if [ "$CHOICE" = "y" ]; then

    # Check if systemctl exists
    if command -v systemctl >/dev/null 2>&1; then
        
        if systemctl is-active --quiet $SERVICE; then
            echo "$SERVICE service is RUNNING"
        else
            echo "$SERVICE service is NOT running"
        fi

    else
        echo "systemctl not available on this system"
    fi

else
    echo "Skipped."
fi
