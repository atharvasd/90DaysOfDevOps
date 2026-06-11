# Lab 01: Advanced Routing and `iptables`

**Topic:** Advanced Networking

---

## Overview

Kubernetes, Docker, and Cloud VPCs all rely heavily on low-level Linux networking features like IP forwarding, NAT (Network Address Translation), and `iptables`. Understanding these is crucial for DevOps engineers.

---

## 🛠️ Hands-on Tasks

### Task 1: Enable IP Forwarding

By default, a Linux server drops packets that are not destined for its own IP address. To make a Linux server act like a router (which is what Docker and Kubernetes nodes do), you must enable IP forwarding.

1. **Check current status:**
```bash
sysctl net.ipv4.ip_forward
# Output: net.ipv4.ip_forward = 0
```

2. **Enable it temporarily:**
```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

3. **Enable it permanently:**
Edit `/etc/sysctl.conf`:
```ini
net.ipv4.ip_forward=1
```
Then run `sudo sysctl -p`.

### Task 2: Basic `iptables` NAT (Masquerading)

Imagine your server has two interfaces: `eth0` (Public Internet) and `eth1` (Private Network: 10.0.0.0/24). You want devices on the private network to access the internet through your server.

1. **Set up NAT (Masquerade):**
```bash
# Append a rule to the POSTROUTING chain of the nat table
# It says: Take packets leaving eth0, and change their source IP to eth0's IP
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

### Task 3: Port Forwarding with `iptables`

You want traffic hitting your server on port 80 to be automatically redirected to port 8080 (where your Node.js app is running without root privileges).

```bash
# Append a rule to the PREROUTING chain of the nat table
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
```

### Task 4: View and Save Rules

1. **List rules in the NAT table:**
```bash
sudo iptables -t nat -L -v -n
```

2. **Save rules so they survive a reboot:**
```bash
# On Ubuntu/Debian
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

---

## ✅ Verification
1. Run `sysctl net.ipv4.ip_forward` and verify it equals `1`.
2. Run `sudo iptables -t nat -L PREROUTING -n` to verify your port 80 redirect rule exists.
