# Networking Security Best Practices — Architecture & Hardening

A guide to architecting secure networks for cloud environments.

---

## 🛑 1. Zero Trust Architecture Basics

"Zero Trust" means never trusting a connection just because it originates from inside your private network. 

### The Old Way (Castle and Moat)
- The database trusts the web server because they are both in the `10.0.0.0/16` VPC.
- **Flaw:** If an attacker breaches the web server, they have full access to the database.

### The Zero Trust Way
- The database drops ALL connections by default.
- It only accepts connections that present a cryptographically verified identity (e.g., a Mutual TLS certificate or a Cloud IAM token), regardless of what IP address they come from.
- **Implementation:** Use Service Meshes (like Istio or Linkerd) or Cloud-native identities (like GCP Workload Identity or AWS IAM Roles for Service Accounts).

---

## 🌐 2. Secure VPC Design

When designing your cloud network (AWS VPC, GCP VPC), follow the Public/Private subnet pattern.

### Public Subnets
- Have a direct route to an Internet Gateway.
- **What goes here:** Load Balancers, NAT Gateways, Bastion Hosts.
- **What NEVER goes here:** Databases, Application Servers, Caches.

### Private Subnets
- Have NO direct route to the Internet. They must route outbound traffic through a NAT Gateway in the Public Subnet.
- **What goes here:** Everything else (App servers, databases).
- **Benefit:** It is physically impossible for an external attacker to initiate a direct connection to a private subnet resource.

---

## 🛡️ 3. DDoS Mitigation Basics

Distributed Denial of Service (DDoS) attacks attempt to overwhelm your network or application.

### Layer 3/4 (Network/Transport) Attacks
- Attackers flood you with UDP or TCP SYN packets to exhaust server resources.
- **Mitigation:** Do not expose servers directly. Use Cloud Provider load balancers (AWS ALB, GCP HTTP(S) LB). Cloud providers automatically absorb massive volumetric attacks at their edge before they ever reach your VPC.

### Layer 7 (Application) Attacks
- Attackers send millions of legitimate-looking HTTP requests (e.g., `GET /login`) to exhaust your application's CPU or database.
- **Mitigation:** 
  1. Use a Web Application Firewall (WAF) to rate-limit requests per IP.
  2. Implement aggressive caching at the CDN level (Cloudflare, CloudFront) so the requests never hit your origin server.

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Architecture** | Place application servers and databases in Private Subnets | 🔴 Critical |
| **Access** | Never open port 22 (SSH) or 3389 (RDP) to `0.0.0.0/0`. Use Bastion hosts, VPNs, or Identity-Aware Proxies. | 🔴 Critical |
| **Trust** | Implement mTLS between internal microservices | 🟡 High |
| **Resilience** | Place a CDN and WAF in front of public endpoints | 🟡 High |
