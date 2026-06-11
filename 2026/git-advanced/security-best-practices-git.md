# Git and GitHub Security Best Practices

A guide to securing your source code repositories against unauthorized modifications, secret leaks, and supply chain attacks.

---

## 🔐 1. Commit Signing (GPG or SSH Keys)

When you make a Git commit, you configure your name and email using `git config user.email "you@example.com"`. There is no verification here. I can easily make a commit claiming to be Linus Torvalds.

If an attacker gains access to your repository, they can create malicious commits that look exactly like they came from a senior engineer.

### The Fix: Cryptographic Commit Signing
By signing your commits with a GPG or SSH key, GitHub displays a green **"Verified"** badge next to the commit. 

```bash
# Generate a new SSH key specifically for signing
ssh-keygen -t ed25519 -C "Git Signing Key" -f ~/.ssh/id_ed25519_signing

# Tell Git about the key
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_signing.pub

# Enable signing by default for all commits
git config --global commit.gpgsign true
```
*Note: You must then upload the public key to your GitHub account under "SSH and GPG keys" -> "Signing keys".*

---

## 🛑 2. Branch Protection Rules

Never allow anyone (even administrators) to push directly to the `main` or `production` branch.

### Configure GitHub Branch Protection
Go to Repository Settings -> **Branches** -> **Add branch protection rule**.
Target: `main`

Enable the following:
1. **Require a pull request before merging:** Forces all changes to go through a PR.
2. **Require approvals:** Set to at least 1 (or 2 for critical repos).
3. **Require status checks to pass before merging:** Ensure CI/CD (tests, security scans) passes before code can be merged.
4. **Require signed commits:** Rejects any commits that lack a verified GPG/SSH signature.
5. **Do not allow bypassing the above settings:** Ensure repository administrators are also bound by these rules.

---

## 🔍 3. Preventing Secret Leaks

The best way to handle leaked secrets is to never leak them in the first place.

### The Fix: Pre-commit Scanning
Use tools like **TruffleHog** or **git-secrets** or **gitleaks** as a `pre-commit` hook (or via GitHub Actions) to scan every commit for high-entropy strings and known API key patterns (e.g., AWS keys, Slack tokens) before allowing the push.

```bash
# Example running gitleaks locally
gitleaks detect --source . -v
```

### Enable GitHub Secret Scanning
In repository Settings -> **Code security and analysis**, enable **Secret scanning**. GitHub will automatically scan pushed commits and can even alert cloud providers (like AWS) to automatically revoke the leaked key. Enable **Push protection** to block the push entirely if a secret is detected.

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Identity** | Sign all commits with GPG/SSH keys | 🟡 High |
| **Integrity** | Enable strict Branch Protection rules on `main` | 🔴 Critical |
| **Integrity** | Require PR reviews and passing CI checks | 🔴 Critical |
| **Secrets** | Enable GitHub Secret Scanning with Push Protection | 🔴 Critical |
| **Secrets** | Never commit `.env` files; add them to `.gitignore` | 🔴 Critical |
