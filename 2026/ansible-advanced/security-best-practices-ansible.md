# Ansible Security Best Practices

A guide to securing your Ansible control nodes and preventing privilege escalation attacks.

---

## 🔐 1. Secure Secrets with Ansible Vault

Never store plaintext passwords, API keys, or certificates in your playbooks or Git repositories.

### The Fix: Ansible Vault
Ansible Vault encrypts files or individual variables using AES256.

```bash
# Encrypt an existing file
ansible-vault encrypt group_vars/all/secrets.yml

# Create a new encrypted file
ansible-vault create credentials.yml

# Edit an encrypted file
ansible-vault edit credentials.yml
```

### Passing Vault Passwords in CI/CD
Never type the vault password interactively in CI. Store the password in your CI/CD secrets (e.g., GitHub Secrets), write it to a temporary file, and use `--vault-password-file`.

```bash
echo "$ANSIBLE_VAULT_PASS" > /tmp/vault.pass
ansible-playbook playbook.yml --vault-password-file /tmp/vault.pass
rm /tmp/vault.pass
```

---

## 🛑 2. Principle of Least Privilege (`become`)

By default, SSH connections should use a standard, non-root user. If a task requires root, use Ansible's privilege escalation (`become: yes`).

### The Rule: Scope `become` as tightly as possible
Do not apply `become: yes` to the entire playbook if only one task needs it.

```yaml
# ❌ BAD: Everything runs as root
- name: Configure Webserver
  hosts: web
  become: yes
  tasks:
    - name: Download user data (doesn't need root)
      get_url:
        url: http://example.com/data.txt
        dest: /home/user/data.txt

# ✅ GOOD: Scoped privilege escalation
- name: Configure Webserver
  hosts: web
  tasks:
    - name: Download user data (runs as normal user)
      get_url:
        url: http://example.com/data.txt
        dest: /home/user/data.txt

    - name: Restart Nginx (Requires root)
      service:
        name: nginx
        state: restarted
      become: yes
```

---

## 🕵️ 3. Prevent Logging Sensitive Data

By default, if a task fails or you use the `debug` module, Ansible will log the output to the console. If a task involves a secret (like passing a password to an API), this will leak the secret into your CI/CD logs.

### The Fix: `no_log: true`
Always apply `no_log: true` to tasks that handle secrets.

```yaml
- name: Create database user
  community.mysql.mysql_user:
    name: admin
    password: "{{ db_secret_password }}"  # This variable comes from Vault
    priv: '*.*:ALL'
  no_log: true  # This prevents the password from being printed to the console
```

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Secrets** | Encrypt all sensitive files and variables with Ansible Vault | 🔴 Critical |
| **Logging** | Use `no_log: true` on any task passing a secret | 🔴 Critical |
| **Privilege** | Connect via SSH as a non-root user and use `become: yes` | 🔴 Critical |
| **Privilege** | Scope `become: yes` to individual tasks, not entire playbooks | 🟡 High |
| **Host Keys** | Avoid `host_key_checking = False` in production; explicitly accept SSH keys | 🟡 High |
