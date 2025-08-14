#!/usr/bin/env bash
set -euo pipefail

# Guard rails: need sudo/root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo bash scripts/users-lab-setup.sh"
  exit 1
fi

echo "[*] Creating groups: devs, ops, auditors"
groupadd -f devs
groupadd -f ops
groupadd -f auditors

echo "[*] Creating users with home directories and shells"
# Developer: normal shell, devs group
id -u alice >/dev/null 2>&1 || useradd -m -s /bin/bash -G devs alice
# Ops: normal shell, ops group
id -u bob   >/dev/null 2>&1 || useradd -m -s /bin/bash -G ops bob
# Auditor: normal shell, auditors group
id -u carol >/dev/null 2>&1 || useradd -m -s /bin/bash -G auditors carol
# Service account: no interactive login, owns app files
id -u dave  >/dev/null 2>&1 || useradd -M -s /usr/sbin/nologin dave

echo "[*] Setting simple passwords (change in real life!)"
echo 'alice:alice' | chpasswd
echo 'bob:bob'     | chpasswd
echo 'carol:carol' | chpasswd
# dave has no password; nologin anyway

echo "[*] Give carol read-only access to logs via 'adm' group (Ubuntu/Debian)"
# 'adm' is allowed to read many logs under /var/log
usermod -aG adm carol || true

echo "[*] Create shared project area for devs with setgid so files inherit group"
install -d -m 2775 -o root -g devs /srv/projects
# 2 (setgid) makes new files inherit 'devs' group; 775 allows group rwx.

echo "[*] Create a sandbox app folder owned by service account"
install -d -m 0750 -o dave -g dave /srv/app

echo "[*] Create a harmless command we can delegate via sudo"
cat >/usr/local/bin/saydate <<'EOCMD'
#!/usr/bin/env bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
EOCMD
chmod 0755 /usr/local/bin/saydate

echo "[*] Configure sudo rules (using visudo-safe includes)"
# Alice (dev) — full sudo (password required)
cat >/etc/sudoers.d/99-alice <<'EOS'
alice ALL=(ALL:ALL) ALL
EOS
chmod 0440 /etc/sudoers.d/99-alice

# Bob (ops) — may run only saydate and journalctl without password
# journalctl might not exist in some containers; if missing, rule is harmless.
cat >/etc/sudoers.d/50-bob-ops <<'EOS'
bob ALL=(root) NOPASSWD: /usr/local/bin/saydate, /usr/bin/journalctl
EOS
chmod 0440 /etc/sudoers.d/50-bob-ops

# Carol (auditor) — no sudo; explicit deny example (optional)
cat >/etc/sudoers.d/10-carol-deny <<'EOS'
carol ALL=(ALL:ALL) !ALL
EOS
chmod 0440 /etc/sudoers.d/10-carol-deny

echo "[*] Verifying sudoers syntax"
visudo -c

echo
echo "[✓] Setup complete."
echo "Users: alice(devs), bob(ops), carol(auditors,adm), dave(nologin)"
echo "Shared: /srv/projects (group=devs,setgid), Service dir: /srv/app (owner dave)"
echo "Sudo: alice=ALL; bob=NOPASSWD for saydate & journalctl; carol=NO"
