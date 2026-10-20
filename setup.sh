cat > setup.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Paste your Termux public key (starts with ssh-ed25519):"
read -rp "> " PUBKEY

# 1. Install dependencies
if command -v apt >/dev/null; then 
    apt update -y >/dev/null && apt install -y openssh-server tmux curl >/dev/null
elif command -v dnf >/dev/null; then 
    dnf install -y openssh-server tmux curl >/dev/null
fi

# 2. Authorize key for root
mkdir -p /root/.ssh && chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
echo "$PUBKEY" >> /root/.ssh/authorized_keys

# 3. Authorize key for 'abc' user if it exists (fixes Railway permissions)
if id "abc" &>/dev/null; then
    mkdir -p /home/abc/.ssh
    echo "$PUBKEY" >> /home/abc/.ssh/authorized_keys
    chown -R abc:abc /home/abc/.ssh
    chmod 700 /home/abc/.ssh
    chmod 600 /home/abc/.ssh/authorized_keys
fi

# 4. Configure sshd
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
service ssh restart 2>/dev/null || systemctl restart ssh 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true

# 5. Start always-on tmux session for root
tmux new-session -d -s main_root 2>/dev/null || true

# 6. Print the ADD line
IP=$(curl -4 -s --max-time 6 ifconfig.me || hostname -I | awk '{print $1}')
NAME=$(hostname -s 2>/dev/null || echo vps)

echo ""
echo "============================================================"
echo "COPY THE LINE BELOW AND PASTE IT INTO YOUR TERMUX MENU:"
echo "ADD:$NAME|$IP|root|22"
echo "============================================================"
EOF

sudo bash setup.sh
