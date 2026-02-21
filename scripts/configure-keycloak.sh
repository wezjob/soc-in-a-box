#!/bin/bash
# SOC-in-a-Box - Keycloak Configuration Script
# Creates realm and OAuth2 clients for SSO

KEYCLOAK_URL="http://localhost:8180"
ADMIN_USER="admin"
ADMIN_PASS="KeycloakAdmin2026!"
REALM_NAME="soc-in-a-box"

echo "🔐 Configuring Keycloak SSO..."

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak..."
until curl -s "$KEYCLOAK_URL/health/ready" 2>/dev/null | grep -q "UP"; do
    sleep 5
done
echo "✅ Keycloak is ready"

# Get admin token
echo "🔑 Getting admin token..."
TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$ADMIN_USER" \
    -d "password=$ADMIN_PASS" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "❌ Failed to get admin token"
    exit 1
fi
echo "✅ Token acquired"

# Create realm
echo "🏰 Creating realm: $REALM_NAME..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "realm": "'"$REALM_NAME"'",
        "enabled": true,
        "displayName": "SOC-in-a-Box",
        "registrationAllowed": true,
        "resetPasswordAllowed": true,
        "rememberMe": true,
        "loginWithEmailAllowed": true,
        "duplicateEmailsAllowed": false,
        "sslRequired": "external",
        "passwordPolicy": "length(8)",
        "accessTokenLifespan": 3600,
        "ssoSessionIdleTimeout": 1800
    }' 2>/dev/null

# Check if realm was created
if curl -s "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
    -H "Authorization: Bearer $TOKEN" | grep -q "$REALM_NAME"; then
    echo "✅ Realm created successfully"
else
    echo "⚠️ Realm may already exist or creation failed"
fi

# Create OAuth2 clients for SOC tools
create_client() {
    local client_id=$1
    local client_name=$2
    local redirect_uri=$3
    
    echo "📱 Creating client: $client_name..."
    curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "clientId": "'"$client_id"'",
            "name": "'"$client_name"'",
            "enabled": true,
            "clientAuthenticatorType": "client-secret",
            "redirectUris": ["'"$redirect_uri"'"],
            "webOrigins": ["*"],
            "publicClient": false,
            "protocol": "openid-connect",
            "standardFlowEnabled": true,
            "directAccessGrantsEnabled": true
        }' 2>/dev/null
}

# Create clients for main SOC tools
create_client "grafana" "Grafana" "http://localhost:3000/*"
create_client "kibana" "Kibana" "http://localhost:5601/*"
create_client "n8n" "n8n SOAR" "http://localhost:5678/*"
create_client "portainer" "Portainer" "https://localhost:9443/*"
create_client "homepage" "Homepage Dashboard" "http://localhost:3003/*"

# Create SOC admin user
echo "👤 Creating SOC admin user..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "soc-admin",
        "email": "soc-admin@soc-in-a-box.local",
        "enabled": true,
        "emailVerified": true,
        "firstName": "SOC",
        "lastName": "Admin",
        "credentials": [{
            "type": "password",
            "value": "SocAdmin2026!",
            "temporary": false
        }]
    }' 2>/dev/null

# Get user ID and assign admin role
USER_ID=$(curl -s "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users?username=soc-admin" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
    echo "✅ User soc-admin created"
else
    echo "⚠️ User creation may have failed"
fi

echo ""
echo "✅ Keycloak configuration complete!"
echo ""
echo "📋 Summary:"
echo "   Realm: $REALM_NAME"
echo "   URL: $KEYCLOAK_URL/realms/$REALM_NAME"
echo "   Admin Console: $KEYCLOAK_URL/admin/$REALM_NAME/console"
echo ""
echo "   OAuth2 Clients: grafana, kibana, n8n, portainer, homepage"
echo ""
echo "   SOC User: soc-admin / SocAdmin2026!"
echo ""
