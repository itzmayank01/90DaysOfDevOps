#!/bin/bash

read -p "Enter a number " NUM

if [ "$NUM" -gt 0 ]; then
    echo "Number is Postive"
elif [ "$NUM" -lt 0 ]; then
    echo "Number is negative"
else 
    echo "Number is zero"
fi
