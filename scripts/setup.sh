#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to fetch metadata variables
get_metadata() {
    local var_name=$1
    curl -s -H "METADATA-TOKEN: vultr" "http://169.254.169.254/v1/internal/app-${var_name}"
}

# Fetch variables from metadata service
GATUS_PORT=$(get_metadata "port")
MONITORED_URLS=$(get_metadata "monitoring_url")
CHECK_INTERVAL=$(get_metadata "monitoring_int")
ALERT_EMAIL=$(get_metadata "alert_email")
GATUS_USERNAME=$(get_metadata "gatus_username")
GATUS_PASSWORD=$(get_metadata "gatus_password")

# Set defaults if metadata fetch fails
GATUS_PORT="${GATUS_PORT:-8080}"
CHECK_INTERVAL="${CHECK_INTERVAL:-1m}"
MONITORED_URLS="${MONITORED_URLS:-https://example.com}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
GATUS_USERNAME="${GATUS_USERNAME:-admin}"
GATUS_PASSWORD="${GATUS_PASSWORD:-$(openssl rand -base64 12)}"

# Install Docker if not installed
if ! command -v docker &>/dev/null; then
    echo -e "${GREEN}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
fi

# Create Gatus configuration file
mkdir -p ~/gatus-config
cat > ~/gatus-config/config.yaml << EOF
web:
  port: ${GATUS_PORT}

security:
  basic:
    username: "${GATUS_USERNAME}"
    password: "${GATUS_PASSWORD}"

endpoints:
EOF

# Convert comma-separated URLs into YAML configuration
IFS=',' read -ra URLS <<< "$MONITORED_URLS"
for URL in "${URLS[@]}"; do
    # Trim whitespace
    URL=$(echo "$URL" | xargs)
    cat >> $(pwd)/gatus-config/config.yaml << EOF
  - name: "Monitor-$(echo "$URL" | sed 's/[^a-zA-Z0-9]/-/g')"
    url: "${URL}"
    interval: ${CHECK_INTERVAL}
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 500"
EOF
done

# Add email alerting if provided
if [ ! -z "$ALERT_EMAIL" ]; then
    cat >> $(pwd)/gatus-config/config.yaml << EOF

alerting:
  email:
    from: "gatus@localhost"
    to: "${ALERT_EMAIL}"
EOF
fi

# Run Gatus in Docker
echo -e "${GREEN}Starting Gatus in Docker...${NC}"
docker run -d --name gatus \
    -v ~/gatus-config/config.yaml:/config/config.yaml \
    -p ${GATUS_PORT}:${GATUS_PORT} \
    twinproduction/gatus

# Fetch public IP
PUBLIC_IP=$(curl -4 ifconfig.me)

# Output access details
echo -e "${GREEN}Gatus is now running in Docker.${NC}"
echo -e "${GREEN}Access it at: http://${PUBLIC_IP}:${GATUS_PORT}${NC}"
echo -e "${GREEN}Username: ${GATUS_USERNAME}${NC}"
echo -e "${GREEN}Password: ${GATUS_PASSWORD}${NC}"
if [ ! -z "$ALERT_EMAIL" ]; then
    echo -e "${GREEN}Alerts will be sent to: ${ALERT_EMAIL}${NC}"
fi
