#!/bin/bash
# Usage:
# linux-run.sh PASSWORD TOKEN USERNAME HOSTNAME

set -e

LINUX_USER_PASSWORD=$1
NGROK_AUTH_TOKEN=$2
LINUX_USERNAME=$3
LINUX_MACHINE_NAME=$4

# -----------------------------
# Validate inputs
# -----------------------------
if [[ -z "$NGROK_AUTH_TOKEN" ]]; then
  echo "❌ NGROK_AUTH_TOKEN is required"
  exit 2
fi

if [[ -z "$LINUX_USER_PASSWORD" ]]; then
  echo "❌ LINUX_USER_PASSWORD is required"
  exit 3
fi

if [[ -z "$LINUX_USERNAME" ]]; then
  echo "❌ LINUX_USERNAME is required"
  exit 4
fi

if [[ -z "$LINUX_MACHINE_NAME" ]]; then
  echo "❌ LINUX_MACHINE_NAME is required"
  exit 5
fi

# -----------------------------
# Create user
# -----------------------------
echo "### Creating user: $LINUX_USERNAME ###"

if id "$LINUX_USERNAME" &>/dev/null; then
  echo "User exists"
else
  sudo useradd -m -s /bin/bash "$LINUX_USERNAME"
  sudo usermod -aG sudo "$LINUX_USERNAME"
fi

echo "$LINUX_USERNAME:$LINUX_USER_PASSWORD" | sudo chpasswd

# -----------------------------
# Set hostname
# -----------------------------
sudo hostnamectl set-hostname "$LINUX_MACHINE_NAME"

# -----------------------------
# Enable password SSH (so you can login)
# -----------------------------
echo "### Configuring SSH ###"

sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

sudo systemctl restart ssh || sudo service ssh restart

# -----------------------------
# Install ngrok v3
# -----------------------------
echo "### Installing ngrok ###"

rm -f ngrok ngrok.tgz

wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar -xzf ngrok-v3-stable-linux-amd64.tgz

chmod +x ngrok

# -----------------------------
# Start ngrok
# -----------------------------
echo "### Starting ngrok ###"

rm -f .ngrok.log

./ngrok config add-authtoken "$NGROK_AUTH_TOKEN"

./ngrok tcp 22 --log=stdout > .ngrok.log 2>&1 &

sleep 8

# -----------------------------
# Extract connection info
# -----------------------------
TUNNEL=$(grep -oE 'tcp://[0-9a-zA-Z.:]+' .ngrok.log | head -n 1)

if [[ -z "$TUNNEL" ]]; then
  echo "❌ ngrok failed"
  cat .ngrok.log
  exit 6
fi

HOST=$(echo "$TUNNEL" | sed 's/tcp:\/\///' | cut -d':' -f1)
PORT=$(echo "$TUNNEL" | sed 's/tcp:\/\///' | cut -d':' -f2)

# -----------------------------
# Output
# -----------------------------
echo ""
echo "=========================================="
echo "✅ SSH READY"
echo ""
echo "ssh $LINUX_USERNAME@$HOST -p $PORT"
echo ""
echo "Password: $LINUX_USER_PASSWORD"
echo "=========================================="
