# 📘 Day 18 – Shell Scripting: Functions & Intermediate Concepts


Topic: Functions, Strict Mode, Local Variables, Structured Scripts  

---

# 🔹 1. Introduction

In Day 18, we focused on writing **clean, reusable, and production-safe shell scripts**.

We learned:

- How to write and call functions
- How to pass arguments to functions
- How strict mode (`set -euo pipefail`) prevents hidden bugs
- How to use local variables
- How to structure a professional shell script
- How to build a real-world system information reporter

---

# 🔹 2. Functions in Shell Script

## ✅ Why Use Functions?

Functions help:

- Avoid repetition (DRY principle)
- Make scripts modular
- Improve readability
- Simplify debugging
- Structure large automation scripts

---

## ✅ Function Syntax

```bash
function_name() {
    commands
}
```

Example:

```bash
greet() {
    echo "Hello $1"
}

greet "Mayank"
```

---

## ✅ Passing Arguments to Functions

Inside a function:

| Variable | Meaning |
|-----------|----------|
| `$1` | First argument |
| `$2` | Second argument |
| `$@` | All arguments |
| `$#` | Number of arguments |

Example:

```bash
add() {
    local num1="$1"
    local num2="$2"
    local sum=$((num1 + num2))
    echo "Sum: $sum"
}

add 10 20
```

Output:
```
Sum: 30
```

---

# 🔹 3. Return Values & Exit Codes

In Bash:

- Functions do not return values like Python.
- They return exit codes (0–255).

```bash
return 0
```

### Exit Code Meaning:

| Code | Meaning |
|------|----------|
| 0 | Success |
| Non-zero | Failure |

To check last exit code:

```bash
echo $?
```

---

# 🔹 4. Strict Mode – `set -euo pipefail` 🔥

Add this after shebang:

```bash
#!/bin/bash
set -euo pipefail
```

This makes your script production-safe.

---

## ✅ `set -e`

Exit immediately if a command fails.

Without `-e`:
Script continues even after errors.

With `-e`:
Script stops immediately when a command fails.

---

## ✅ `set -u`

Treat undefined variables as errors.

Example:

```bash
echo $name
```

If `name` is not defined → script exits with error.

Prevents:
- Typos
- Silent bugs
- Unexpected empty values

---

## ✅ `set -o pipefail`

If any command in a pipeline fails, the whole pipeline fails.

Example:

```bash
grep "hello" file.txt | wc -l
```

If `grep` fails:
- Normally → `wc` still runs
- With pipefail → script exits

Prevents hidden pipeline failures.

---

## 🔥 Why Strict Mode is Important

Production automation must:

- Fail fast
- Not ignore errors
- Prevent silent failures
- Be predictable

That’s why DevOps engineers always use:

```bash
set -euo pipefail
```

---

# 🔹 5. Local vs Global Variables

## ✅ Local Variable

```bash
my_function() {
    local name="Mayank"
    echo $name
}
```

- Exists only inside function
- Safer
- Prevents conflicts

---

## ❌ Global Variable

```bash
my_function() {
    name="Mayank"
}
```

- Accessible outside function
- Can overwrite other variables
- Dangerous in large scripts

---

## ✅ Best Practice

Always declare variables inside functions using:

```bash
local variable_name
```

---

# 🔹 6. Command Substitution

Used to store output of a command.

```bash
hostname=$(hostname)
```

OR

```bash
echo "OS: $(uname -o)"
```

It runs the command and inserts the result.

---

# 🔹 7. Redirection & Error Handling

## ✅ Hide Errors

```bash
2>/dev/null
```

- `2` → stderr
- `/dev/null` → discard output

Used when permission errors may occur.

---

## ✅ Standard Streams

| Symbol | Meaning |
|--------|----------|
| `>` | Redirect output |
| `>>` | Append output |
| `2>` | Redirect error |
| `&>` | Redirect both |

---

# 🔹 8. Useful System Monitoring Commands

## Disk Usage

```bash
df -h
du -h
```

## Memory Usage

```bash
free -h
```

## CPU Processes

```bash
ps -eo pid,cmd,%cpu,%mem --sort=-%cpu
```

## Uptime

```bash
uptime
```

---

# 🔹 9. Professional Script Structure

Industry-standard format:

```bash
#!/bin/bash
set -euo pipefail

function1() {
    # code
}

function2() {
    # code
}

main() {
    function1
    function2
}

main
```

---

## ✅ Why Use `main()`?

- Clear execution flow
- Better readability
- Easy debugging
- Professional structure

---

# 🔹 10. Mini System Info Reporter Structure

Example structure:

```bash
print_header() {
    echo "=============================="
    echo "$1"
    echo "=============================="
}

system_info() {
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -o)"
}

main() {
    print_header "SYSTEM INFO"
    system_info
}

main
```

---

# 🔹 11. Key DevOps Concepts Learned

| Concept | Why It Matters |
|----------|---------------|
| Functions | Reusable automation |
| Strict Mode | Prevents hidden production bugs |
| Local Variables | Avoids side effects |
| Exit Codes | Enables error handling |
| Pipefail | Detects pipeline failures |
| main() structure | Clean architecture |

---

# 🔹 12. Interview Ready Answers

## ❓ Why use `set -euo pipefail`?

It ensures the script fails fast, prevents undefined variable usage, and detects failures inside pipelines, making automation safe for production environments.

---

## ❓ Difference between local and global variable?

Local variables exist only inside functions, while global variables are accessible everywhere and may cause unintended side effects.

---

## ❓ Why structure scripts using functions?

To improve modularity, readability, maintainability, and debugging in large automation scripts.

---

# 🔹 13. What I Learned – Day 18

1. Shell scripting can be written like structured programming.
2. Strict mode is essential for production-safe scripts.
3. Local variables prevent accidental overwrites.
4. Proper script structure makes automation scalable.
5. DevOps scripting is about reliability, not just commands.

---

# 🚀 DevOps Mindset Upgrade

Before:
Writing commands manually in terminal.

After:
Writing modular, safe, production-ready automation scripts.

---

# 📌 Final Thought

Shell scripting is not about running commands.
It is about building reliable automation systems.

Day 18 completed successfully ✅  
#90DaysOfDevOps #DevOpsKaJosh #TrainWithShubham