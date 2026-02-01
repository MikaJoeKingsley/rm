#!/bin/bash

# =====================================
# ONE-TIME SSH PORT CHANGER (AUTO DELETE)
# Usage: bash change_port.sh 7392
# =====================================

NEW_PORT=$1

if [ -z "$NEW_PORT" ]; then
    echo "Usage: bash change_port.sh <new_port>"
    exit 1
fi

if [ "$NEW_PORT" -lt 1024 ]; then
    echo "Port must be > 1024"
    exit 1
fi

echo "Changing SSH port to $NEW_PORT..."

CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak.$(date +%s)"
SCRIPT_PATH="$(readlink -f "$0")"   # full path of this script

# ===== BACKUP =====
cp "$CONFIG" "$BACKUP"

# ===== UPDATE PORT =====
if grep -q "^Port " "$CONFIG"; then
    sed -i "s/^Port .*/Port $NEW_PORT/" "$CONFIG"
else
    echo "Port $NEW_PORT" >> "$CONFIG"
fi

# ===== FIREWALL =====
if command -v ufw >/dev/null 2>&1; then
    ufw allow "$NEW_PORT"/tcp >/dev/null 2>&1
fi

iptables -I INPUT -p tcp --dport "$NEW_PORT" -j ACCEPT 2>/dev/null

# ===== RESTART SSH =====
systemctl restart ssh 2>/dev/null || systemctl restart sshd

sleep 2

# ===== VERIFY =====
if ss -tln | grep ":$NEW_PORT " >/dev/null; then
    echo ""
    echo "✅ SUCCESS!"
    echo "SSH running on port $NEW_PORT"
    echo "Use: ssh root@SERVER_IP -p $NEW_PORT"

    # ===== DELETE SCRIPT AFTER SUCCESS =====
    rm -f "$SCRIPT_PATH"

else
    echo "❌ FAILED — restoring backup"
    mv "$BACKUP" "$CONFIG"
    systemctl restart ssh 2>/dev/null || systemctl restart sshd
fi
