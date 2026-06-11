# Lab 01: Git Hooks (Client-Side Automation)

**Topic:** Advanced Git

---

## Overview

Git hooks are scripts that Git executes before or after events such as: `commit`, `push`, and `receive`. They are a built-in feature of Git and require no external tools. They are heavily used in DevOps to enforce code quality and security *before* code ever leaves a developer's machine.

---

## 🛠️ Hands-on Tasks

### Task 1: The `.git/hooks` Directory

Every Git repository has a hidden `.git/hooks` directory populated with sample hooks.

1. **Initialize a dummy repository:**
```bash
mkdir hooks-demo && cd hooks-demo
git init
ls -la .git/hooks/
```
*Notice all the `.sample` files. If you remove the `.sample` extension and make them executable, Git will run them automatically.*

### Task 2: Create a `pre-commit` Hook

A `pre-commit` hook runs before you even type your commit message. It is used to inspect the snapshot that's about to be committed.

1. **Create the hook script:**
```bash
# Create a new pre-commit file
cat << 'EOF' > .git/hooks/pre-commit
#!/bin/bash

echo "Running pre-commit hook..."

# Check if any files being committed contain the word "password"
if git diff --cached | grep -i "password="; then
    echo "ERROR: You are trying to commit a hardcoded password!"
    echo "Commit rejected."
    exit 1 # Non-zero exit code stops the commit!
fi

echo "Pre-commit checks passed."
exit 0
EOF
```

2. **Make it executable (Crucial!):**
```bash
chmod +x .git/hooks/pre-commit
```

### Task 3: Test the Hook

1. **Create a safe file:**
```bash
echo "Hello World" > safe.txt
git add safe.txt
git commit -m "Add safe file"
```
*The hook should run, print "Pre-commit checks passed", and allow the commit.*

2. **Create a dangerous file:**
```bash
echo "password=supersecret" > config.ini
git add config.ini
git commit -m "Add config"
```
*The hook should catch the password, print the ERROR message, and REJECT the commit.*

### Task 4: Bypassing Hooks

Sometimes, a hook has a false positive, or you have an emergency.

1. **Bypass the hook:**
```bash
git commit -m "I know what I'm doing" --no-verify
```
*This skips the `pre-commit` and `commit-msg` hooks.*

---

## ✅ Best Practices
- **Shared Hooks:** The `.git/hooks` directory is NOT committed to the repository (it's local to your machine). To share hooks with your team, use a tool like **Husky** (for Node.js) or **pre-commit** (Python-based framework), which configure Git to use a committed folder for hooks (e.g., `git config core.hooksPath .githooks`).
