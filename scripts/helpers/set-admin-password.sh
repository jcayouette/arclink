#!/bin/bash
# Script to set administrator password by directly updating the database
# This is REQUIRED on first deployment as OTS creates an admin user with no password
# Usage: ./set-admin-password.sh [new-password]

set -e

# Load configuration
if [ -f "config.env" ]; then
    source config.env
else
    # Defaults if no config.env
    NAMESPACE=${NAMESPACE:-tak}
    PRIMARY_NODE_IP=${PRIMARY_NODE_IP:-localhost}
    WEB_NODEPORT=${WEB_NODEPORT:-31080}
fi

NEW_PASSWORD="${1:-}"

# Interactive mode if no password provided
if [ -z "$NEW_PASSWORD" ]; then
    echo "======================================"
    echo "Set OpenTAKServer Administrator Password"
    echo "======================================"
    echo ""
    read -s -p "Enter new password: " NEW_PASSWORD
    echo
    read -s -p "Confirm password: " NEW_PASSWORD_CONFIRM
    echo
    
    if [ "$NEW_PASSWORD" != "$NEW_PASSWORD_CONFIRM" ]; then
        echo "Error: Passwords do not match"
        exit 1
    fi
    
    if [ -z "$NEW_PASSWORD" ]; then
        echo "Error: Password cannot be empty"
        exit 1
    fi
fi

echo ""
echo "Waiting for OpenTAKServer to be ready..."
kubectl -n ${NAMESPACE} wait --for=condition=ready pod -l app=opentakserver --timeout=300s

# Check if admin user exists
ADMIN_EXISTS=$(kubectl -n ${NAMESPACE} exec -i deployment/postgres -- psql -U ots -d ots -t -c "SELECT COUNT(*) FROM \"user\" WHERE username = 'administrator';" 2>/dev/null | tr -d ' ')

if [ "$ADMIN_EXISTS" = "0" ]; then
    echo "Warning: Administrator user does not exist yet. OpenTAKServer may still be initializing."
    echo "Please wait a moment and try again."
    exit 1
fi

echo "Generating secure password hash..."
PASSWORD_HASH=$(kubectl -n ${NAMESPACE} exec -i deploy/opentakserver -c ots -- python3 << EOF
from passlib.hash import argon2
print(argon2.hash("${NEW_PASSWORD}"))
EOF
)

if [ -z "$PASSWORD_HASH" ]; then
    echo "Error: Failed to generate password hash"
    exit 1
fi

echo "Updating password in database..."
ROWS_UPDATED=$(kubectl -n ${NAMESPACE} exec -i deployment/postgres -- psql -U ots -d ots -t -c "UPDATE \"user\" SET password = '${PASSWORD_HASH}' WHERE username = 'administrator'; SELECT 1;" 2>/dev/null | grep -c "1" || true)

if [ "$ROWS_UPDATED" != "1" ]; then
    echo "Error: Failed to update password"
    exit 1
fi

echo ""
echo "======================================"
echo "✅ Password Updated Successfully!"
echo "======================================"
echo ""
echo "Login credentials:"
echo "  Username: administrator"
echo "  Password: (the password you just set)"
echo ""
echo "Access OpenTAKServer at:"
echo "  http://${PRIMARY_NODE_IP}:${WEB_NODEPORT}"
echo ""
