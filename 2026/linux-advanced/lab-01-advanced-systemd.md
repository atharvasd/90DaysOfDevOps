# Lab 01: Advanced Systemd (Timers, Targets, and Cgroups)

**Topic:** Advanced Linux Administration

---

## Overview

You already know how to `start`, `stop`, and `enable` services using `systemctl`. But `systemd` is much more than a service manager; it is an entire initialization system that handles scheduling (Timers), system states (Targets), and resource management (Cgroups).

---

## 🛠️ Hands-on Tasks

### Task 1: Replacing Cron with Systemd Timers

Cron is great, but systemd timers provide better logging (via `journalctl`), dependency management, and millisecond precision.

1. **Create a Service Unit:**
```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Daily Backup Service

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -a /var/www /backup/
```

2. **Create the Timer Unit (must match the service name):**
```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Run backup daily at midnight

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true # Run immediately if the system was off at midnight

[Install]
WantedBy=timers.target
```

3. **Enable and Start the Timer:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer
sudo systemctl list-timers # View all active timers
```

### Task 2: Systemd Targets (Runlevels)

Targets group units together to represent system states (like old init runlevels).

1. **View available targets:**
```bash
systemctl list-units --type=target
```

2. **Change the default target (e.g., to boot without GUI):**
```bash
# Check current
systemctl get-default

# Set to multi-user (CLI only) instead of graphical
sudo systemctl set-default multi-user.target
```

### Task 3: Resource Limits with Cgroups

You can restrict a service's CPU and Memory usage directly in its unit file.

1. **Add Limits to a Service:**
```ini
[Service]
ExecStart=/usr/bin/my-heavy-app
# Limit CPU to 50% of one core
CPUQuota=50%
# Limit Memory to 500MB
MemoryMax=500M
```

2. **Verify Cgroup Resource Usage:**
```bash
systemd-cgtop
```

---

## ✅ Verification
1. Run `systemctl list-timers` and confirm your `backup.timer` is scheduled.
2. Run `systemctl get-default` and verify the output.
3. Check resource usage of your services using `systemd-cgtop`.
