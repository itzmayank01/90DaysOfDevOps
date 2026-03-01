#!/bin/bash

# List of packages
packages=("nginx" "curl" "wget")

# Loop through each package
for pkg in "${packages[@]}"
do
    echo "Checking $pkg..."

    # For Ubuntu/Debian systems
    if dpkg -s "$pkg" &> /dev/null
    then
        echo "$pkg is already installed ✅"
    else
        echo "$pkg is not installed. Installing..."
        sudo apt-get update -y
        sudo apt-get install -y "$pkg"
        echo "$pkg installed successfully 🚀"
    fi

    echo "-----------------------------"
done