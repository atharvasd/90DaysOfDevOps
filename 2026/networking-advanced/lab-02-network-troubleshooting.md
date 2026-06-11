# Lab 02: Network Troubleshooting (`tcpdump`, `mtr`, `tshark`)

**Topic:** Advanced Networking

---

## Overview

When the application team says "The network is down" or "The API is slow," it is your job to prove where the problem lies. These tools allow you to look inside the network packets.

---

## 🛠️ Hands-on Tasks

### Task 1: Advanced Ping with `mtr`

`mtr` combines the functionality of `ping` and `traceroute`. It continuously sends packets and tracks the latency and packet loss at every single router hop between you and the destination.

1. **Install mtr:**
```bash
sudo apt update && sudo apt install mtr -y
```

2. **Run mtr:**
```bash
# Press 'q' to quit when done
mtr google.com
```
*Look for hops that show high "Loss%" — that indicates a failing router.*

### Task 2: Packet Sniffing with `tcpdump`

`tcpdump` captures raw network packets as they enter or leave your server's network interfaces.

1. **Capture all packets on port 80 (HTTP):**
```bash
# Open a second terminal and run: curl http://example.com
sudo tcpdump -i any port 80
```

2. **Capture packets from a specific IP:**
```bash
sudo tcpdump src 192.168.1.100
```

3. **Write packets to a file for later analysis (PCAP format):**
```bash
sudo tcpdump -w capture.pcap port 443
```
*You can open `capture.pcap` in Wireshark on your desktop.*

### Task 3: Deep Analysis with `tshark`

`tshark` is the terminal version of Wireshark. It can decode protocols (like HTTP, DNS) and format them beautifully.

1. **Install tshark:**
```bash
sudo apt install tshark -y
```

2. **Sniff DNS queries:**
```bash
# Watch what domains your server is trying to resolve
sudo tshark -i any -f "udp port 53" -O dns
```

---

## ✅ Verification
1. Run `mtr 8.8.8.8` and identify how many hops it takes your packets to reach Google's DNS servers.
2. Run a `tcpdump` capture on port 80, make an HTTP request, and verify you see the packet output.
