# Shell Scripting Security Best Practices

A guide to writing secure shell scripts that don't leak credentials or expose your system to command injection.

---

## 🛑 1. Command Injection Prevention

Never pass untrusted user input directly into executable commands without sanitization.

### The Vulnerability
```bash
#!/bin/bash
# ❌ BAD: Vulnerable to command injection
read -p "Enter a domain to ping: " DOMAIN
ping -c 1 $DOMAIN
```
If the user types `google.com; rm -rf /`, the script expands the variable and executes both commands!

### The Fix
Always quote variables. However, quotes don't protect against `eval` or certain subshells. Avoid `eval` completely. Validate input using regular expressions.

```bash
#!/bin/bash
# ✅ GOOD: Validate input before execution
read -p "Enter a domain to ping: " DOMAIN

# Regex to allow only alphanumeric characters, dots, and hyphens
if [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    ping -c 1 "$DOMAIN"
else
    echo "Invalid domain format."
    exit 1
fi
```

---

## 🔑 2. Never Hardcode Secrets

Storing passwords or API keys in scripts means they end up in Git history or are readable by anyone on the system.

### The Vulnerability
```bash
# ❌ BAD: Hardcoded secrets
DB_USER="admin"
DB_PASS="SuperSecret123"
mysql -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;"
```

### The Fix
Read secrets from a `.env` file that is restricted (`chmod 600`), or fetch them from a secrets manager (like AWS Secrets Manager or HashiCorp Vault) at runtime.

```bash
# ✅ GOOD: Read from a secure config file
if [ -f "/etc/db_secrets.conf" ]; then
    source "/etc/db_secrets.conf"
else
    echo "Secrets file missing!"
    exit 1
fi

# Even better: Don't pass the password as a CLI argument (which shows up in 'ps aux')
# Provide it via stdin or environment variable configuration
MYSQL_PWD="$DB_PASS" mysql -u "$DB_USER" -e "SHOW DATABASES;"
```

---

## 🔒 3. Safe Temporary Files

When scripts create temporary files in `/tmp`, attackers can predict the filename and create a malicious symlink ahead of time (Symlink attack), tricking your script into overwriting a critical system file (like `/etc/passwd`).

### The Vulnerability
```bash
# ❌ BAD: Predictable temp file
TEMP_FILE="/tmp/backup_log.txt"
echo "Starting backup" > "$TEMP_FILE"
```

### The Fix
Always use `mktemp`, which creates a cryptographically randomized filename and sets secure permissions (`600`) automatically.

```bash
# ✅ GOOD: Use mktemp
TEMP_FILE=$(mktemp)
echo "Starting backup" > "$TEMP_FILE"
```

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Errors** | Always start scripts with `set -euo pipefail` | 🔴 Critical |
| **Variables** | Always double-quote variables (`"$VAR"`) to prevent word splitting and globbing | 🔴 Critical |
| **Input** | Never use `eval` with untrusted input | 🔴 Critical |
| **Secrets** | Never hardcode API keys or passwords; load from `.env` or Vault | 🔴 Critical |
| **Files** | Use `mktemp` for temporary files, never predictable paths | 🟡 High |
