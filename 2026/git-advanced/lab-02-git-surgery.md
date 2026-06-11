# Lab 02: Advanced Git Surgery (`reflog` and History Rewriting)

**Topic:** Advanced Git

---

## Overview

Sometimes things go terribly wrong. You accidentally ran `git reset --hard` and lost your work. Or you accidentally committed an AWS key to `main` and pushed it to GitHub. This lab covers how to perform emergency surgery on a Git repository.

---

## 🛠️ Hands-on Tasks

### Task 1: Time Travel with `git reflog`

`git log` shows the commit history. But `git reflog` (Reference Log) shows a history of *every action your local Git repository has taken*, even if those actions deleted commits.

1. **Create some history and then destroy it:**
```bash
mkdir surgery-demo && cd surgery-demo
git init
echo "First" > file.txt && git add . && git commit -m "C1"
echo "Second" > file.txt && git add . && git commit -m "C2"
echo "Third" > file.txt && git add . && git commit -m "C3"

# Oh no, I accidentally reset back to C1 and wiped out C2 and C3!
git reset --hard HEAD~2
git log --oneline # C2 and C3 are gone!
```

2. **Recover using reflog:**
```bash
# View the reflog
git reflog
```
*You will see a list of actions like `HEAD@{1}: commit: C3`.*

3. **Restore the lost state:**
Find the ID (e.g., `HEAD@{1}`) right before you did the destructive `reset --hard`, and reset back to it:
```bash
git reset --hard HEAD@{1}
git log --oneline # C2 and C3 are back!
```

### Task 2: Removing Sensitive Data from History (BFG Repo-Cleaner)

If you commit a password, simply deleting the file in the next commit does **NOT** remove it from Git. The password will live forever in the `.git` folder history.

You must rewrite history. While `git filter-branch` exists, the **BFG Repo-Cleaner** is the modern, faster standard.

1. **Commit a secret:**
```bash
echo "AWS_KEY=AKIAIOSFODNN7EXAMPLE" > aws_credentials.txt
git add . && git commit -m "Accidentally added AWS key"
```

2. **Download BFG:**
```bash
# Requires Java
wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar
```

3. **Delete the file from all history:**
```bash
# Run BFG against the repo
java -jar bfg-1.14.0.jar --delete-files aws_credentials.txt .

# BFG doesn't physically delete the old data immediately; you must force garbage collection
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

4. **Verify:**
```bash
git log --stat
```
*The commit still exists, but the file is gone from it! Note: If you already pushed to GitHub, you must now `git push --force`.*

---

## ✅ Best Practices
- **Rotate Keys Immediately:** Even if you use BFG to rewrite history, if the secret was pushed to GitHub for even *one second*, assume it is compromised. GitHub is constantly scanned by bots. Rewrite history AND rotate the key.
- **Never Force Push to Shared Branches:** Try to avoid `git push --force` on `main` if other developers have already pulled the code, as it rewrites history and will break their local repositories.
