#!/bin/bash
# =============================================================================
# SOC-in-a-Box - Vaultwarden Credentials Import Script
# =============================================================================

set -e

export NODE_TLS_REJECT_UNAUTHORIZED=0

VW_EMAIL="${1:-wezjob4@gmail.com}"
VW_PASSWORD="${2:-nUH@acCsAdmxpmRfZY5j}"

echo "================================================================="
echo "SOC-in-a-Box - Vaultwarden Credentials Import"
echo "================================================================="
echo ""

# Check if logged in
if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
    echo "🔑 Logging in to Vaultwarden..."
    bw logout 2>/dev/null || true
    export BW_SESSION=$(bw login "$VW_EMAIL" "$VW_PASSWORD" --raw 2>/dev/null)
    if [ -z "$BW_SESSION" ]; then
        echo "❌ Login failed"
        exit 1
    fi
    echo "✅ Login successful"
fi

# Sync vault
echo "🔄 Syncing vault..."
bw sync 2>/dev/null

# Helper function to create login item
create_login() {
    local name="$1"
    local username="$2"
    local password="$3"
    local uri="$4"
    local folder_id="$5"
    local notes="$6"
    
    # Check if item already exists
    if bw list items --search "$name" 2>/dev/null | jq -e '.[] | select(.name == "'"$name"'")' >/dev/null 2>&1; then
        echo "  ⏭️  $name (exists)"
        return 0
    fi
    
    local json=$(bw get template item 2>/dev/null | jq \
        --arg name "$name" \
        --arg username "$username" \
        --arg password "$password" \
        --arg uri "$uri" \
        --arg folder "$folder_id" \
        --arg notes "$notes" \
        '.type = 1 | .name = $name | .login = {"username": $username, "password": $password, "uris": [{"uri": $uri}]} | .folderId = $folder | .notes = $notes')
    
    if echo "$json" | bw encode | bw create item >/dev/null 2>&1; then
        echo "  ✅ $name"
    else
        echo "  ❌ $name (failed)"
    fi
}

# Helper function to create secure note
create_note() {
    local name="$1"
    local content="$2"
    local folder_id="$3"
    
    if bw list items --search "$name" 2>/dev/null | jq -e '.[] | select(.name == "'"$name"'")' >/dev/null 2>&1; then
        echo "  ⏭️  $name (exists)"
        return 0
    fi
    
    local json=$(bw get template item 2>/dev/null | jq \
        --arg name "$name" \
        --arg content "$content" \
        --arg folder "$folder_id" \
        '.type = 2 | .name = $name | .secureNote = {"type": 0} | .notes = $content | .folderId = $folder')
    
    if echo "$json" | bw encode | bw create item >/dev/null 2>&1; then
        echo "  ✅ $name"
    else
        echo "  ❌ $name (failed)"
    fi
}

# Create folders
echo ""
echo "📁 Creating folders..."

create_folder() {
    local name="$1"
    local existing=$(bw list folders 2>/dev/null | jq -r '.[] | select(.name == "'"$name"'") | .id')
    if [ -n "$existing" ]; then
        echo "$existing"
        return
    fi
    local json=$(bw get template folder 2>/dev/null | jq --arg name "$name" '.name = $name')
    echo "$json" | bw encode | bw create folder 2>/dev/null | jq -r '.id'
}

INFRA=$(create_folder "Infrastructure")
echo "  ✅ Infrastructure ($INFRA)"

SECURITY=$(create_folder "Sécurité")
echo "  ✅ Sécurité ($SECURITY)"

MONITORING=$(create_folder "Monitoring")
echo "  ✅ Monitoring ($MONITORING)"

ADMIN=$(create_folder "Administration")
echo "  ✅ Administration ($ADMIN)"

OAUTH=$(create_folder "OAuth Secrets")
echo "  ✅ OAuth Secrets ($OAUTH)"

# Create credentials
echo ""
echo "🔐 Creating Infrastructure credentials..."
create_login "Elasticsearch" "elastic" "LabSoc2026!" "http://localhost:9200" "$INFRA" "SOC-in-a-Box Elasticsearch cluster"
create_login "PostgreSQL (IRIS)" "labsoc" "LabSocDB2026!" "postgresql://localhost:5432/iris_db" "$INFRA" "IRIS DFIR database"
create_login "PostgreSQL (Keycloak)" "keycloak" "KeycloakDB2026!" "postgresql://localhost:5433/keycloak" "$INFRA" "Keycloak database"

echo ""
echo "🛡️ Creating Security credentials..."
create_login "Kibana" "elastic" "LabSoc2026!" "http://localhost:5601" "$SECURITY" "ELK Stack - SIEM interface"
create_login "IRIS DFIR" "admin" "d++X\$mX!J6';{ONU" "https://localhost:8443" "$SECURITY" "Incident Response & Forensics Platform"
create_login "Keycloak Admin" "admin" "KeycloakAdmin2026!" "http://localhost:8180" "$SECURITY" "SSO / Identity Provider"
create_login "Keycloak SSO User" "soc-admin" "SocAdmin2026!" "http://localhost:8180/realms/soc-in-a-box" "$SECURITY" "SOC User for SSO login"
create_login "Vaultwarden Admin" "admin" "VaultwardenAdmin2026!" "https://localhost:8085/admin" "$SECURITY" "Vaultwarden Admin Panel Token"

echo ""
echo "📊 Creating Monitoring credentials..."
create_login "Grafana" "admin" "GrafanaAdmin2026!" "http://localhost:3000" "$MONITORING" "Metrics visualization"
create_login "Uptime Kuma" "admin" "LabSoc2026!" "http://localhost:3001" "$MONITORING" "Service availability monitoring"

echo ""
echo "🔧 Creating Administration credentials..."
create_login "Nginx Proxy Manager" "admin@example.com" "changeme" "http://localhost:81" "$ADMIN" "Reverse proxy - Change password on first login!"
create_login "Portainer" "admin" "[CREATE ON FIRST LOGIN]" "http://localhost:9000" "$ADMIN" "Docker management"
create_login "n8n" "admin" "[CREATE ON FIRST LOGIN]" "http://localhost:5678" "$ADMIN" "Workflow automation / SOAR"

echo ""
echo "🔑 Creating OAuth Secrets..."
create_note "Grafana OAuth" "Client ID: grafana
Client Secret: I2q9h9hb2bdKDxYXKcdKN1nrlKjhpJaQ
Issuer: http://localhost:8180/realms/soc-in-a-box" "$OAUTH"

create_note "Kibana OAuth" "Client ID: kibana
Client Secret: ZOCUF6wi7VLZuzrXT7mOxbR506FZxhls
Issuer: http://localhost:8180/realms/soc-in-a-box" "$OAUTH"

create_note "n8n OAuth" "Client ID: n8n
Client Secret: Z5JZk2FXQFawYozDo3zO3pyiehisOdgA
Issuer: http://localhost:8180/realms/soc-in-a-box" "$OAUTH"

create_note "Portainer OAuth" "Client ID: portainer
Client Secret: r5afqtZBrl4QapT2qmMOhraCRCikUbel
Issuer: http://localhost:8180/realms/soc-in-a-box" "$OAUTH"

create_note "IRIS OAuth" "Client ID: iris
Client Secret: XcWeKt4vy1t5Nl1sp96mWZ6jy15Gsmut
Issuer: http://localhost:8180/realms/soc-in-a-box" "$OAUTH"

# Sync again
bw sync 2>/dev/null

echo ""
echo "================================================================="
echo "✅ Import complete!"
echo "================================================================="
echo ""
echo "Open Vaultwarden: https://localhost:8085"
echo "Email: $VW_EMAIL"
echo ""
echo "Folders created:"
echo "  📁 Infrastructure - Elasticsearch, PostgreSQL"
echo "  📁 Sécurité - IRIS, Keycloak, Kibana"
echo "  📁 Monitoring - Grafana, Uptime Kuma"
echo "  📁 Administration - NPM, Portainer, n8n"
echo "  📁 OAuth Secrets - Keycloak client secrets"
echo ""
