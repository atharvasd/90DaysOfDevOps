# Lab 02: Defensive Scripting (`set -euo pipefail` and `trap`)

**Topic:** Advanced Shell Scripting

---

## Overview

Bash is notoriously forgiving. If a command fails, Bash prints an error and happily executes the next line. If a variable is misspelled, Bash treats it as an empty string. In automation and CI/CD pipelines, this behavior causes catastrophic failures (like accidentally running `rm -rf /` because a variable was empty).

Defensive scripting forces Bash to act like a strict programming language.

---

## 🛠️ Hands-on Tasks

### Task 1: The Unofficial Bash Strict Mode

Always begin your production scripts with `set -euo pipefail`.

Create `strict_mode.sh`:

```bash
#!/bin/bash

# e: Exit immediately if a command exits with a non-zero status.
# u: Treat unset variables as an error and exit immediately.
# o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

echo "Script started."

# 1. Test '-u' (Unbound variable error)
# Uncommenting the next line will crash the script because $UNSET_VAR is not defined.
# echo "The value is $UNSET_VAR"

# 2. Test '-e' (Exit on error)
# Uncommenting the next line will crash the script because 'false' returns a non-zero exit code.
# false
# echo "This will not print if the line above is uncommented."

# 3. Test '-o pipefail'
# Without pipefail, this pipeline succeeds because 'echo' succeeds, even though 'grep' fails.
# With pipefail, the script crashes.
cat non_existent_file.txt | grep "error" | echo "Processing log..."

echo "Script finished successfully."
```

### Task 2: Graceful Cleanup with `trap`

If a script creates temporary files or holds database locks, and it crashes or is interrupted by the user (`Ctrl+C`), those temporary files are left behind. 

`trap` catches signals (like `EXIT`, `SIGINT`, `SIGTERM`) and executes a cleanup function before the script dies.

Create `cleanup_trap.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temp directory: $TEMP_DIR"

# Define the cleanup function
cleanup() {
    echo "Caught exit signal! Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    echo "Cleanup complete."
}

# Trap the EXIT signal (which fires when the script ends naturally OR crashes)
trap cleanup EXIT

echo "Working with temp files..."
touch "$TEMP_DIR/data1.txt"
touch "$TEMP_DIR/data2.txt"

# Simulate a failure
echo "Oh no, a critical error occurred!"
exit 1 # Or imagine an uncaught error happened here

echo "This will never be reached."
```

---

## ✅ Verification
1. Run `strict_mode.sh` and observe how it fails at the `cat` command because of `pipefail`.
2. Run `cleanup_trap.sh`. Notice that even though the script explicitly calls `exit 1` (simulating a crash), the `cleanup` function still runs and deletes the temporary directory.
