<p align="center">
  <img src="https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=1200&q=80" alt="FP Remover Banner" width="100%">
</p>

<h1 align="center">🧹 FP-REMOVER</h1>
<h3 align="center">Advanced Digital Footprint Eraser — clearshadow.sh v2.1</h3>

<p align="center">
  <img src="https://img.shields.io/badge/version-2.1-red?style=flat-square">
  <img src="https://img.shields.io/badge/platform-Linux-blue?style=flat-square">
  <img src="https://img.shields.io/badge/requires-root%20(for%20full%20sweep)-orange?style=flat-square">
  <img src="https://img.shields.io/badge/author-archnexus__707-purple?style=flat-square">
</p>

---

## 🕵️ What Is It?

**FP-Remover** (Footprint Remover) is an advanced anti-forensics tool that securely erases digital traces from Linux systems. It handles shell histories, system logs, browser data, SSH traces, temp files, application artifacts, process memory, swap, core dumps, file timestamps, and SSD slack space — all with cryptographic shredding.

```
   ╔═══════════════════════════════════════════════════════════════╗
   ║     ░▒▓█  CLEARSHADOW v2.1 — DIGITAL FOOTPRINT ERASER  █▓▒░  ║
   ║        SSD-aware | Memory scrub | Slack wipe | Audit          ║
   ╚═══════════════════════════════════════════════════════════════╝
```

---

## 🚀 Quick Start

```bash
# 1. Clone and install
git clone https://github.com/archnexus707/FP-Remover.git
cd FP-Remover
chmod +x setup.sh && ./setup.sh

# 2. Preview (safe — no changes made)
./clearshadow.sh --dry-run

# 3. Full sweep (requires root)
sudo ./clearshadow.sh

# 4. Help
./clearshadow.sh --help
```

---

## ⚙️ Usage

```bash
./clearshadow.sh [flags]
```

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview what will be wiped — **no changes made** |
| `--passes N` | Number of shred passes (default: 3, DoD: 7) |
| `--shred-header` | Also destroy LUKS encryption headers |
| `--help` | Show full help |

### Examples

```bash
# Preview without touching anything
./clearshadow.sh --dry-run

# Standard 3-pass wipe (as user — partial sweep)
./clearshadow.sh

# Full anti-forensics sweep as root
sudo ./clearshadow.sh

# DoD 7-pass wipe with LUKS header destruction
sudo ./clearshadow.sh --passes 7 --shred-header
```

---

## 🧠 Features

### Sweep Modules

| Module | What It Erases |
|--------|---------------|
| **Shell Histories** | bash, zsh, fish, mysql, psql, python, node, less, wget |
| **System Logs** | auth.log, syslog, journald, audit, ufw, fail2ban, nginx, apache |
| **Temp & Caches** | /tmp, /var/tmp, thumbnails, clipboard, trash, pip cache, shader cache |
| **Browser Data** | Firefox places/cookies/history, Chromium/Brave/Edge History/Cookies/Cache |
| **SSH & Network** | known_hosts, DNS cache, ARP table, Wi-Fi profiles, NM secrets |
| **App Artifacts** | vim, nano, git credentials, docker config, msf, burp, john, hashcat |
| **Process Memory** | ssh-agent keys, gpg-agent, gnome-keyring (with secure shred) |
| **Memory & Swap** | Page cache, dentries, inodes, swap rotation (safely) |
| **Core Dumps** | systemd coredump, /var/crash, apport reports |
| **Connections** | Interactive TCP connections (safe — preserves system daemons) |
| **Timestamps** | Stochastic randomization of Desktop/Documents/Downloads file times |
| **SSD TRIM** | fstrim on ext4/xfs/btrfs to reclaim wiped blocks |
| **LUKS Headers** | Optional cryptographic destruction of encryption headers |

### Safety Features

- **Dry-run mode** — preview everything before committing
- **User mode** — partial sweep when run without root (safe for non-root use)
- **Root confirmation** — "Type ERASE to confirm" before ANY destructive action
- **System daemon protection** — connection teardown skips systemd, sshd, dbus, etc.
- **Swap safety** — if swapoff fails, original swap is preserved
- **Audit log** — every action logged to `/tmp/clearshadow_audit_*.log`

---

## 📊 Forensic Audit

Before wiping, the script scans for:

- Shell history entries (count)
- Browser history URLs (count)
- SSH known hosts (count)

```
Forensic footprint before wipe:
├─ Shell history entries: 4,832
├─ Browser URLs: 12,401
├─ SSH known hosts: 47
└─ Total trackable artifacts: 17,280
```

After the sweep, it verifies nothing remains.

---

## 📂 Directory Structure

```
FP-Remover/
├── clearshadow.sh    ← Main anti-forensics script
├── setup.sh          ← One-shot dependency installer
├── README.md         ← This file
└── .gitignore
```

---

## 📋 Requirements

| Package | Purpose |
|---------|---------|
| `coreutils` | shred, cat, stat, touch |
| `util-linux` | fallocate, fstrim, findmnt |
| `sqlite3` | Browser history audit |
| `wipe` (optional) | Additional secure deletion |

All installed automatically by `setup.sh`.

---

## 👤 Author

**archnexus_707** — privacy advocate, terminal toolsmith.

> 💰 **Donations welcome:** `archnexus_707`

---

## 📜 License

Ethical use only. Authorized privacy protection and security testing. Not for illegal activity.

<p align="center">
  <sub>Made with ❤️ on Kali Linux</sub>
</p>
