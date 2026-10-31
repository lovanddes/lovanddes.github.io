#!/bin/bash
# taide-srv(單位 G9 上的 Ubuntu VM,跑台灣主權 AI)一次性設定:往主機 B 撥反向通道 127.0.0.1:2226。2026-10-30。
# 2026-10-19。先生在 VM 上以 sudo 跑一次;最後印出的那行公鑰貼給 Claude,Claude 加進 B 才會通。
# 秘密不經手:撥號私鑰在 VM 上現場產生,只有公鑰往外傳。
set -e
B_HOST=5.189.157.144
B_HOSTKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0bdnYedPv02P4aJr0itF84Rb/mRwfuGI01wv8+rNlt"
PORT=2226
CLAUDE_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGCi3Ba8VmzytGSGwJoIVMRbrZozbqVJToyeRqoRuoht B->taide-srv"
U=claude

# 1. 讓 Claude 用金鑰登入 claude 帳號
install -d -m 700 -o $U -g $U /home/$U/.ssh
grep -qF "$CLAUDE_PUB" /home/$U/.ssh/authorized_keys 2>/dev/null || echo "$CLAUDE_PUB" >> /home/$U/.ssh/authorized_keys
chown $U:$U /home/$U/.ssh/authorized_keys; chmod 600 /home/$U/.ssh/authorized_keys

# 2. sudo 免密碼(Claude 用金鑰進來沒有密碼可打)
echo "$U ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-claude; chmod 440 /etc/sudoers.d/90-claude
visudo -cf /etc/sudoers.d/90-claude

# 3. 撥號鑰匙與 B 的身分
install -d -m 700 /etc/claude-tunnel
[ -f /etc/claude-tunnel/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -C "taide-tunnel" -f /etc/claude-tunnel/id_ed25519
echo "$B_HOST $B_HOSTKEY" > /etc/claude-tunnel/known_hosts

# 4. 開機自動撥號、斷線 10 秒重撥
cat > /etc/systemd/system/claude-tunnel.service <<EOF
[Unit]
Description=Reverse SSH tunnel to Claude host B (127.0.0.1:$PORT)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/ssh -N -i /etc/claude-tunnel/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=/etc/claude-tunnel/known_hosts -o StrictHostKeyChecking=yes -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R 127.0.0.1:$PORT:127.0.0.1:22 winbridge@$B_HOST
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now claude-tunnel.service

echo
echo "===== 設定完成。請把下面這一行整行複製貼給 Claude ====="
cat /etc/claude-tunnel/id_ed25519.pub
