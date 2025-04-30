#!/bin/sh

# Start Vault server in the background
vault server -dev -dev-listen-address=0.0.0.0:8200 -dev-root-token-id=root &
VAULT_PID=$!

# Wait for Vault to be ready
until curl -s http://127.0.0.1:8200/v1/sys/health > /dev/null; do
    echo "Waiting for Vault to be ready..."
    sleep 1
done

# Set up environment
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN=root

# Enable userpass auth method
vault auth enable userpass

# Create user with the provided credentials
vault write auth/userpass/users/${VAULT_USERNAME} \
    password=${VAULT_PASSWORD} \
    policies=default

echo "Vault userpass authentication has been configured"
echo "Username: ${VAULT_USERNAME}"
echo "Password: ${VAULT_PASSWORD}"

# Keep the container running
wait $VAULT_PID 