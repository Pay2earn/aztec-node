#!/usr/bin/env bash
set -euo pipefail

CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "-----------------------------------------------------"
echo "   One Click Setup Aztec Sequencer - Pay2earn"
echo "-----------------------------------------------------"
echo ""

# ====================================================
# Aztec alpha-testnet Sequencer node setup script (v0.87.8)
# For Debian/Ubuntu only. Requires sudo privileges
# ====================================================

if [ "$(id -u)" -ne 0 ]; then
  echo "⚠️  Please run this script with sudo or as root."
  exit 1
fi

echo "🔧 Updating system & installing base packages..."
apt update && apt upgrade -y
apt install -y screen ca-certificates curl gnupg lsb-release

echo "📦 Installing Docker & Docker Compose..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
apt install -y docker-compose

echo "🧠 Installing Aztec CLI..."
bash -i <(curl -sL https://install.aztec.network)

echo 'export PATH=$PATH:/root/.aztec/bin' >> ~/.bashrc
source ~/.bashrc

echo "⚙️ Setting up alpha-testnet..."
aztec-up alpha-testnet

echo ""
echo "🧠 Please enter the following configuration details:"
read -p "▶️ L1 Execution Client (EL) RPC URL: " ETH_RPC
read -p "▶️ L1 Consensus (CL) RPC URL: " CONS_RPC
read -p "▶️ Validator Private Key: " VALIDATOR_PRIVATE_KEY

mkdir -p /root/aztec-node/node/data
chmod -R 777 /root/aztec-node

echo "📄 Creating docker-compose.yml..."
cat > /root/aztec-node/docker-compose.yml <<EOF
services:
  node:
    image: aztecprotocol/aztec:0.87.8
    environment:
      ETHEREUM_HOSTS: ${ETH_RPC}
      L1_CONSENSUS_HOST_URLS: ${CONS_RPC}
      DATA_DIRECTORY: /data
      VALIDATOR_PRIVATE_KEY: ${VALIDATOR_PRIVATE_KEY}
      P2P_QUERY_FOR_IP: true
      LOG_LEVEL: info
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet start --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - /root/aztec-node/node/data:/data
    restart: unless-stopped
EOF

cd /root/aztec-node
echo "🚀 Starting Aztec full node..."
docker compose up -d

echo -e "\n✅ ${BOLD}Aztec Node is running!${RESET}"
echo "   - Check logs: docker compose logs -f"
echo "   - Data path:  /root/aztec-node/node/data"
