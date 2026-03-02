#!/bin/bash
set -euo pipefail

echo "Strict mode demo"

# Undefined variable test (set -u)
echo "$UNDEFINED_VAR"

# 2️⃣ Failing command test (set -e)
# false

# 3️⃣ Pipe failure test (set -o pipefail)
grep "hello" nonexistentfile | wc -l 
