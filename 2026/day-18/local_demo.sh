#!/bin/bash

demo_local() {
    local message="I am mayank"
    echo "Inside funtion: $message"
}

demo_global() {
    message="I am Aniket"
    echo "Inside function: $message"
} 

demo_local
echo "Outside function after local: ${message:-Not defined}"

echo

demo_global
echo "Outside function after global: $message"