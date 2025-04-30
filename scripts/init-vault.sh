#!/bin/sh

# Start Vault server in the background
vault server -dev -dev-listen-address=0.0.0.0:8200 -dev-root-token-id=root &

# Store the PID
PID=$!

# Wait for Vault to be ready
sleep 2

# Set up environment
export VAULT_TOKEN=root

# Enable userpass auth method
vault auth enable userpass

# Create the secret policy
vault policy write secret-policy - << EOF
# Manage secrets
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Create child tokens
path "auth/token/create" {
  capabilities = ["create", "update"]
}

# Allow token lookup and renewal
path "auth/token/lookup" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Create user with the provided credentials and assign the policy
vault write auth/userpass/users/${VAULT_USERNAME} password=${VAULT_PASSWORD} policies=secret-policy

echo "Vault userpass authentication has been configured"
echo "Username: ${VAULT_USERNAME}"
echo "Password: ${VAULT_PASSWORD}"
echo "Policy: secret-policy"

# Keep the container running
wait $PID 