#!/bin/bash

read -p "Enter file name: " NAME

if [ -f "$NAME" ]; then
    echo "file exists"
else
    echo "file does not exist"
fi