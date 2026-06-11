# Linux Security Best Practices — Server Hardening Guide

A comprehensive guide to securing your Linux servers before putting them in production.

---

## 🔐 1. SSH Hardening

SSH is the primary way servers are compromised via brute-force attacks.

### Disable Password Authentication
Only allow SSH keys.
Edit `/etc/ssh/sshd_config`:
```text
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
```

### Disable Root Login
Never log in directly as root. Log in as a standard user and use `sudo`.
Edit `/etc/ssh/sshd_config`:
```text
PermitRootLogin no
```

Restart SSH to apply: `sudo systemctl restart sshd`

---

## 🛡️ 2. Install Fail2Ban

Fail2Ban monitors log files (e.g., `/var/log/auth.log`) and temporarily bans IPs that show malicious signs like too many password failures.

```bash
sudo apt update && sudo apt install fail2ban
sudo systemctl enable --now fail2ban
```

---

## 🧱 3. Configure a Firewall (UFW)

Never leave all ports open to the public internet.

```bash
# Install UFW (Uncomplicated Firewall)
sudo apt install ufw

# Deny all incoming by default
sudo ufw default deny incoming

# Allow all outgoing by default
sudo ufw default allow outgoing

# Allow SSH (CRITICAL: Do this before enabling the firewall!)
sudo ufw allow ssh

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable the firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

---

## 🔒 4. Enable Automatic Security Updates

Don't wait to patch critical vulnerabilities.

```bash
# Ubuntu/Debian
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **SSH** | Disable `PasswordAuthentication` | 🔴 Critical |
| **SSH** | Disable `PermitRootLogin` | 🔴 Critical |
| **Network** | Enable UFW and drop all unexpected incoming traffic | 🔴 Critical |
| **Updates** | Enable unattended security upgrades | 🟡 High |
| **Intrusion** | Install and enable Fail2Ban | 🟡 High |
| **Users** | Never share the same user account; create specific users and use `sudo` | 🟡 High |
