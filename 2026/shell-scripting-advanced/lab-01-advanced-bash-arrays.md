# Lab 01: Advanced Bash (Arrays and Parameter Expansion)

**Topic:** Advanced Shell Scripting

---

## Overview

Most basic shell scripts rely on variables containing single strings. However, as scripts become complex (e.g., managing multiple servers, generating dynamic configurations), you need robust data structures. Bash supports one-dimensional indexed arrays and associative arrays (key-value pairs, like dictionaries).

---

## 🛠️ Hands-on Tasks

### Task 1: Indexed Arrays

Indexed arrays are standard lists where each element is accessed via a numeric index (starting at 0).

Create a script `indexed_arrays.sh`:

```bash
#!/bin/bash

# 1. Declare an array
servers=("web01" "web02" "db01" "cache01")

# 2. Add an element
servers+=("worker01")

# 3. Print a specific element
echo "First server: ${servers[0]}"

# 4. Print all elements
echo "All servers: ${servers[@]}"

# 5. Print the number of elements
echo "Total servers: ${#servers[@]}"

# 6. Iterate through the array
echo "Deploying to servers..."
for server in "${servers[@]}"; do
    echo "  -> Deploying to $server"
done
```

### Task 2: Associative Arrays (Dictionaries)

Associative arrays allow you to use strings as keys. *Note: Requires Bash 4.0 or newer.*

Create a script `associative_arrays.sh`:

```bash
#!/bin/bash

# 1. Explicitly declare an associative array (required!)
declare -A server_ips

# 2. Populate the array
server_ips=( ["web01"]="10.0.1.10" ["db01"]="10.0.1.20" ["cache01"]="10.0.1.30" )

# 3. Add a new key-value pair
server_ips["worker01"]="10.0.1.40"

# 4. Access a specific value
echo "The IP of db01 is: ${server_ips["db01"]}"

# 5. Iterate over keys and values
for server in "${!server_ips[@]}"; do
    echo "Server: $server | IP: ${server_ips[$server]}"
done
```

### Task 3: Parameter Expansion Magic

Parameter expansion allows you to manipulate strings without calling external tools like `sed` or `awk` or `cut`. This is much faster.

Create a script `parameter_expansion.sh`:

```bash
#!/bin/bash

FILENAME="backup_2026-05-10.tar.gz"

echo "Original string: $FILENAME"

# 1. Default Values (Use "default.txt" if variable is empty)
EMPTY_VAR=""
echo "Default value: ${EMPTY_VAR:-"default.txt"}"

# 2. Substring Extraction (Start at index 7, extract 10 characters)
echo "Date part: ${FILENAME:7:10}"

# 3. Remove Prefix (Remove 'backup_')
echo "Remove Prefix: ${FILENAME#backup_}"

# 4. Remove Suffix (Remove '.tar.gz')
echo "Remove Suffix: ${FILENAME%.tar.gz}"

# 5. Search and Replace (Replace '-' with '/')
DATE_PART="${FILENAME:7:10}"
echo "Replaced date format: ${DATE_PART//-/\/}"
```

---

## ✅ Verification
1. Run `chmod +x *.sh` on all your scripts.
2. Execute each script and verify the output matches your expectations. Observe how fast parameter expansion runs compared to piping strings into `sed`.
