# Lab 02: Linux Performance Tuning (sysctl & ulimits)

**Topic:** Advanced Linux Administration

---

## Overview

By default, Linux kernels are tuned for general-purpose desktop/server usage. When running high-traffic web servers, databases, or container orchestrators (like Kubernetes), you must tune the kernel to prevent resource exhaustion.

---

## 🛠️ Hands-on Tasks

### Task 1: Tuning Network Stack with `sysctl`

The `/etc/sysctl.conf` file allows you to modify kernel parameters at runtime.

1. **Increase the maximum number of open files and connections:**
Add the following to `/etc/sysctl.conf`:
```ini
# Increase max number of open files
fs.file-max = 2097152

# Increase max number of incoming connections (backlog)
net.core.somaxconn = 65535

# Enable TCP SYN cookies to protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1

# Reduce the time the system keeps sockets in FIN-WAIT-2 state
net.ipv4.tcp_fin_timeout = 15
```

2. **Apply the changes immediately:**
```bash
sudo sysctl -p
```

3. **Verify a specific value:**
```bash
sysctl net.core.somaxconn
```

### Task 2: Managing Process Limits with `ulimit`

The kernel imposes limits on how many resources a specific user or shell can consume.

1. **Check current limits:**
```bash
ulimit -a  # View all limits
ulimit -n  # View max open files
```

2. **Temporarily change a limit:**
```bash
ulimit -n 65535
```

3. **Permanently change limits:**
Edit `/etc/security/limits.conf`:
```text
# <domain>   <type>   <item>   <value>
*            soft     nofile   65535
*            hard     nofile   65535
root         soft     nofile   100000
root         hard     nofile   100000
```
*Note: Users must log out and log back in for these changes to take effect.*

---

## ✅ Verification
1. Run `sysctl fs.file-max` and ensure it matches your configuration.
2. Log out and log back in, then run `ulimit -n` to verify the new open file limit.
