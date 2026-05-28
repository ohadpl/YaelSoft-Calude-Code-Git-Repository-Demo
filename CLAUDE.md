# CLAUDE.md — ClaudeCode-SB-SMS-Services

## Project Purpose

MuleSoft integration service for Shikun & Binui SMS operations via the Telemesser SMS gateway. Fires Salesforce Platform Events on opt-out callbacks.

## Build & Run

```
# From project root using local Maven:
"C:\maven\apache-maven-3.9.11-bin\apache-maven-3.9.11\bin\mvn.cmd" clean package -DskipTests
```

App runs on **port 8081**.

## Endpoints

| Flow | Method | Path | Purpose |
|---|---|---|---|
| send-bulk-sms-flow | POST | `/sb-sms/send-bulk` | Send SMS to many recipients (batches of 1,000) |
| send-single-sms-flow | POST | `/sb-sms/send-single` | Send SMS to a single recipient |
| handle-returning-messages-flow | GET | `/sb-sms/callback` | Telemesser opt-out callback |

## Credentials

All credentials are in `src/main/resources/config.yaml`. Fill in before running:
- `telemesser.username` / `telemesser.encryptPassword`
- `salesforce.username` / `salesforce.password` / `salesforce.securityToken`

## Runtime & Connector Versions

| Item | Version |
|---|---|
| Mule Runtime | 4.9.0 (Server 4.9.13 EE) |
| mule-http-connector | 1.11.1 |
| mule-sockets-connector | 1.2.7 |
| mule-salesforce-connector | 11.4.0 |

## Flow Logging Convention

Every flow must have a Logger as first and last processor:
```
ClaudeCode-SB-SMS-Services - <flow-name> - START
ClaudeCode-SB-SMS-Services - <flow-name> - END
```

## Response Status Convention

All SMS flows return JSON:
- `{"status": "S", "message": ""}` — all sent successfully
- `{"status": "W", "message": "X recipients (out of Y unique) were invalid"}` — partial failure
- `{"status": "E", "message": "..."}` — total failure / exception

## Telemesser API

- Host: `telemesser.co.il` HTTPS port 443
- Path: `/api/SendSMS`
- Timeout: 30 seconds (`responseTimeout="30000"` on request config)
- Max batch size: 1,000 recipients per call

## Salesforce Platform Event

Event type: `SMSProviderEvent__e`  
Opt-out trigger: `Text == "1"` in callback query param  
Fields: `Type__c = "RemovalFromDistribution"`, `PhoneNumber__c = <Sender>`
