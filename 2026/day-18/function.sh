#!/bin/bash

greet() {
  local name="$1"
  echo "Hello, $name!"
}

add() {
    local num1="$1"
    local num2="$2"
    local sum=$((num1 + num2))
    echo "Sum: $sum"
}

greet Mayank
add 10 20