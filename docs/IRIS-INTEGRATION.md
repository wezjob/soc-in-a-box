# IRIS DFIR Integration Guide

## Overview

This guide covers the integration between IRIS DFIR and the LabSOC Home SOC platform.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Suricata  │────▶│    ELK      │────▶│    n8n      │
│    Zeek     │     │   Stack     │     │    SOAR     │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  IRIS DFIR  │
                                        │   Platform  │
                                        └─────────────┘
```

## Installation

### 1. Install IRIS DFIR

```bash
./scripts/install-iris.sh
```

Or manually:

```bash
cd iris
docker network create labsoc-network 2>/dev/null || true
docker compose up -d
```

### 2. Access IRIS

- **URL**: https://localhost:8443
- **Username**: administrator
- **Password**: IrisAdmin2026!

### 3. Generate API Key

1. Login to IRIS
2. Go to **Settings** → **API Keys**
3. Create a new API key with name: `n8n-integration`
4. Copy the API key

### 4. Configure n8n Credentials

1. Access n8n: http://localhost:5678
2. Go to **Settings** → **Credentials**
3. Add new **Header Auth** credential:
   - Name: `IRIS API Key`
   - Header Name: `Authorization`
   - Header Value: `Bearer <your-api-key>`

### 5. Import Workflows

Import these workflows in n8n:

1. `n8n/workflows/elk-iris-integration.json` - Webhook receiver for ELK alerts
2. `n8n/workflows/elk-iris-scheduler.json` - Automatic polling of ELK alerts

## Data Flow

### ELK Alert → IRIS Case

1. **Trigger**: New critical/high severity alert in ELK
2. **n8n Processing**:
   - Receives alert via webhook or scheduled poll
   - Creates case in IRIS with alert details
   - Extracts IOCs (IPs, domains, hashes)
   - Adds IOCs to the case
3. **IRIS**: Case created with full context for investigation

### IOC Types Mapping

| ELK Field | IRIS IOC Type | Type ID |
|-----------|---------------|---------|
| src_ip/dest_ip | IPv4 Address | 76 |
| dns.query | Domain | 9 |
| file.hash.md5 | MD5 | 34 |
| file.hash.sha256 | SHA256 | 35 |

## n8n Workflows

### elk-iris-integration.json

**Purpose**: Receive alerts via webhook and create IRIS cases

**Webhook Endpoint**: `POST /webhook/elk-to-iris`

**Expected Payload**:
```json
{
  "severity": "critical",
  "rule_name": "ET TROJAN CobaltStrike Beacon",
  "src_ip": "192.168.1.100",
  "dest_ip": "45.33.32.156",
  "mitre": {
    "tactic": "Command and Control",
    "technique": "T1071.001"
  }
}
```

### elk-iris-scheduler.json

**Purpose**: Poll ELK every 5 minutes for new critical alerts

**Automatic Processing**:
1. Queries `suricata-*` and `labsoc-alerts*` indices
2. Filters for critical/high severity alerts not yet synced
3. Creates cases in IRIS for each alert
4. Marks alerts as synced in ELK

## Elasticsearch Watcher Integration

### Create ELK Watcher to Send to n8n

```json
PUT _watcher/watch/critical-alert-to-iris
{
  "trigger": {
    "schedule": {
      "interval": "1m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["suricata-*"],
        "body": {
          "query": {
            "bool": {
              "must": [
                { "range": { "@timestamp": { "gte": "now-1m" } } },
                { "term": { "alert.severity": 1 } }
              ],
              "must_not": [
                { "exists": { "field": "iris_synced" } }
              ]
            }
          }
        }
      }
    }
  },
  "condition": {
    "compare": {
      "ctx.payload.hits.total.value": { "gt": 0 }
    }
  },
  "actions": {
    "send_to_n8n": {
      "webhook": {
        "method": "POST",
        "host": "labsoc-n8n",
        "port": 5678,
        "path": "/webhook/elk-to-iris",
        "body": "{{#toJson}}ctx.payload{{/toJson}}"
      }
    }
  }
}
```

## IRIS API Reference

### Create Case

```bash
curl -X POST https://localhost:8443/case/add \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "case_name": "[CRITICAL] Suspected C2 Activity",
    "case_description": "Automated case from ELK alert",
    "case_customer": 1,
    "case_soc_id": "ELK-2024-001"
  }'
```

### Add IOC to Case

```bash
curl -X POST https://localhost:8443/case/ioc/add/<case_id> \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "ioc_type_id": 76,
    "ioc_value": "192.168.1.100",
    "ioc_description": "Source IP from alert",
    "ioc_tlp_id": 2,
    "ioc_tags": "elk,auto-import"
  }'
```

### Add Timeline Event

```bash
curl -X POST https://localhost:8443/case/timeline/events/add/<case_id> \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -k \
  -d '{
    "event_title": "Initial Alert Detection",
    "event_date": "2024-02-17T14:30:00Z",
    "event_content": "Suricata detected suspicious traffic",
    "event_category_id": 1
  }'
```

## Troubleshooting

### IRIS Connection Issues

```bash
# Check IRIS containers
docker compose -f iris/docker-compose.yml ps

# View IRIS logs
docker logs iris-web -f

# Test API connectivity
curl -k https://localhost:8443/api/ping
```

### n8n Workflow Issues

1. Check n8n execution history
2. Verify credentials are correctly configured
3. Test webhook manually:
   ```bash
   curl -X POST http://localhost:5678/webhook-test/elk-to-iris \
     -H "Content-Type: application/json" \
     -d '{"severity":"critical","rule_name":"Test"}'
   ```

### ELK to IRIS Sync Issues

```bash
# Check sync log index
curl -u elastic:LabSoc2026! \
  "http://localhost:9200/labsoc-iris-sync/_search?pretty"
```

## Security Considerations

1. **API Keys**: Rotate IRIS API keys regularly
2. **TLS**: Use proper certificates in production
3. **Network**: Restrict access to IRIS to SOC analysts only
4. **Credentials**: Store all credentials securely in n8n

## Useful Commands

```bash
# Start IRIS
cd iris && docker compose up -d

# Stop IRIS
cd iris && docker compose down

# Restart IRIS
cd iris && docker compose restart

# View all IRIS logs
cd iris && docker compose logs -f

# Backup IRIS PostgreSQL
docker exec iris-db pg_dump -U iris iris_db > backup.sql
```
