---
description: Diagnose a problem with a MuleSoft application/artifact already deployed in Anypoint Runtime Manager (CloudHub 2.0 by default, or CloudHub 1.0). Connects to the org with the Connected App in settings.xml, locates the app in the right environment, reads its deployment/replica status, pulls the runtime logs the right way, classifies the failure (app-down vs running-but-erroring), isolates downstream dependencies, and reports a root cause + fix. Read-only by default — never changes the org or any app without explicit approval. Use for runtime errors like 5xx/timeouts/connectivity/startup failures, NOT for analyzing a log file already downloaded to disk (use mulesoft-log-analyzer-agent for that).
argument-hint: [app-name] [environment] [ch2|ch1]
allowed-tools: [Read, Glob, Grep, Bash, Write]
---

# MuleSoft — Diagnose a Deployed Artifact in Runtime Manager

Diagnose why a **deployed** Mule app behaves badly at runtime (5xx errors, timeouts, connectivity failures,
crash-on-start, not reachable, etc.) by connecting to **Anypoint Platform** with a Connected App and querying
**Runtime Manager (Application Manager)** APIs. Defaults to **CloudHub 2.0** (`provider=MC`); supports CloudHub 1.0.

> This skill is **read-only by default**. Authenticate, inspect, read logs, probe dependencies — but do **not**
> redeploy, restart, edit config, or change anything in the org unless the user explicitly approves a specific
> change. Report the root cause and the recommended fix; let the user (or a DevOps agent) apply it.
>
> Companion: to analyze a `.log` file already downloaded to disk, use **`mulesoft-log-analyzer-agent`** instead.
> To apply a fix (redeploy/config), hand off to **`mulesoft-devops-engineer-agent`** / the deploy skill.

---

## Environment & toolchain on this machine (Windows 11)

- **Credentials** live in `C:\Users\ohadp\.m2\settings.xml` → profile `anypoint-connected-app`
  (`anypoint.connectedApp.clientId` / `anypoint.connectedApp.clientSecret`). The same client id/secret also appear
  in the `<server id="exchange">` block. **Never echo the secret; never hardcode it in any file.**
- **HTTP client:** `curl` is available via the Bash tool (git-bash).
- **JSON parsing gotcha:** git-bash here has **no `python`/`python3`/`node`/`jq`**. Do **not** rely on them.
  Parse JSON by either:
  - `grep -oE '"field":"[^"]*"'` for quick field extraction, or
  - save the response to a file and `grep`/`sed`, or
  - use the **PowerShell** tool: `(Invoke-RestMethod ...)` / `ConvertFrom-Json` when you need real JSON handling.
- **Anypoint base host:** `https://anypoint.mulesoft.com` (US control plane). EU would be `https://eu1.anypoint.mulesoft.com`.

---

## Step 0 — Resolve the target

From `` capture the **app name** (e.g. `iv-an-poc`), the **environment** (e.g. `Sandbox` / "non-prod"), the
**platform** (CH2 default, or `ch1`), and the **symptom** (the exact error the user sees, e.g.
`HTTP 503 Service Unavailable` from Postman, a timeout, a stack trace, "won't start"). If any is missing, ask once.
Capture the **time** the user reproduced the problem — you will need it to target the logs (Step 5).

## Step 1 — Get credentials & authenticate

Read the Connected App credentials from settings.xml, then mint a token (control-plane client-credentials):

```bash
# Read clientId/clientSecret from C:\Users\ohadp\.m2\settings.xml (profile anypoint-connected-app) — do not print the secret.
curl -s -X POST "https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token" \
  -H "Content-Type: application/json" \
  -d '{"client_id":"<CLIENT_ID>","client_secret":"<CLIENT_SECRET>","grant_type":"client_credentials"}'
# -> { "access_token":"...", "expires_in":3600, "token_type":"bearer" }
```
Export the token for reuse: `TOKEN=<access_token>`. Tokens last ~1h; re-mint if a call returns 401.

## Step 2 — Resolve org & environment

```bash
# Org context (org_id, name)
curl -s "https://anypoint.mulesoft.com/accounts/api/me" -H "Authorization: Bearer $TOKEN"
# Environments for the org (pick the non-prod / requested one by name; note isProduction)
curl -s "https://anypoint.mulesoft.com/accounts/api/organizations/<ORG_ID>/environments" -H "Authorization: Bearer $TOKEN"
```
Record `ORG_ID` and the target `ENV_ID`. "Non-prod" usually = the `sandbox` type environment.

## Step 3 — Find the deployment & read its top-line status

**CloudHub 2.0 (default):**
```bash
curl -s "https://anypoint.mulesoft.com/amc/application-manager/api/v2/organizations/<ORG_ID>/environments/<ENV_ID>/deployments" \
  -H "Authorization: Bearer $TOKEN"
# find the item whose "name" == <app-name>; capture its "id" (DEPLOYMENT_ID), target.targetId, status, application.status
```
Read `status` (deployment, e.g. `APPLIED`/`APPLYING`/`FAILED`) and `application.status`
(`RUNNING`/`NOT_RUNNING`/`STARTING`). **This is the first fork in the diagnosis:**
- `application.status` ≠ `RUNNING` → the app is **down / failing to start** → go to Step 4, then Step 5 startup logs.
- `application.status` == `RUNNING` → the app is **up but erroring at request time** → the fault is in request
  handling or a **downstream dependency** → Step 5 (request-time logs) + Step 6.

**CloudHub 1.0 (if `ch1`):**
```bash
curl -s "https://anypoint.mulesoft.com/cloudhub/api/v2/applications" \
  -H "Authorization: Bearer $TOKEN" -H "X-ANYPNT-ENV-ID: <ENV_ID>" -H "X-ANYPNT-ORG-ID: <ORG_ID>"
# status field per app; logs via .../applications/{domain}/deployments/{id}/logs
```

## Step 4 — Read the deployment detail (replicas, config, URLs)

```bash
curl -s "https://anypoint.mulesoft.com/amc/application-manager/api/v2/organizations/<ORG_ID>/environments/<ENV_ID>/deployments/<DEPLOYMENT_ID>" \
  -H "Authorization: Bearer $TOKEN"
```
Extract and reason about:
- `replicas[].state` + `reason` — `STARTED` vs `PENDING`/`CRASHED`/`OOM`; the `reason` often names the failure.
- `target.deploymentSettings.http.inbound.publicUrl` vs `internalUrl`, and `generateDefaultPublicUrl`.
  **A blank `publicUrl` + `generateDefaultPublicUrl:false` means the app has NO public endpoint** — only an
  internal URL (`...internal-<space>...`). Calling it from the public internet (Postman) will not route. Note which
  **private space** it lives in (the `<space>` token in the host, e.g. `rwlukm`, `ccnh06`).
- `application.configuration...properties` and `secureProperties` — the app's **downstream URLs**, connection
  names, feature flags, and which secrets are set (values masked as `******`). This map tells you what the app
  talks to (other apps, gateways, SaaS, DBs, OpenAI, etc.).
- `vCores` / `instanceType` (e.g. `0.1` / `mule.micro.mem`) — under-sizing can cause OOM/`503`s under load.
- `application.ref` (artifactId/version) and `currentRuntimeVersion`.

To list spec versions (you need the current spec `version` to pull logs):
```bash
curl -s ".../deployments/<DEPLOYMENT_ID>/specs" -H "Authorization: Bearer $TOKEN"
# the active one matches the deployment's "desiredVersion"; call it SPEC_ID
```

## Step 5 — Pull the logs the RIGHT way (critical gotcha)

The CH2 logs endpoint is **`/specs/{SPEC_ID}/logs`** (there is no `/logs/download` on this base — that 404s):
```bash
curl -s ".../deployments/<DEPLOYMENT_ID>/specs/<SPEC_ID>/logs" -H "Authorization: Bearer $TOKEN"
```
**Gotcha that wastes time:** the default response returns only a handful of the **oldest startup INFO lines** and
hides the recent errors. To see the actual failure, request **descending order with an explicit recent time
window** (epoch **milliseconds**) around when the user reproduced the issue:
```bash
curl -s ".../deployments/<DEPLOYMENT_ID>/specs/<SPEC_ID>/logs?limit=500&descending=true&startTime=<MS>&endTime=<MS>" \
  -H "Authorization: Bearer $TOKEN" > logs.json
grep -oE '"logLevel":"[A-Z]*"' logs.json | sort | uniq -c          # level histogram
grep -nE 'ERROR|WARN|[0-9]{3} (Service Unavailable|Internal|Forbidden|Bad)' logs.json
```
Each entry has `timestamp` (ms), `logLevel`, `message`, `replicaId`, and `context.logger`/`class`. The
`message` of an `ERROR` from `DefaultExceptionListener` contains the Mule error block: **`Error type`**,
**`Element` / file:line**, and the **flow stack** — read those, they name the failing processor.

## Step 6 — Isolate: is it the app, or a downstream dependency?

If the app is `RUNNING` but throwing at request time, the error usually points **outward**. Use the downstream URLs
from Step 4's config map and **probe them directly** to separate "dependency is down" from "the app/gateway can't
reach a healthy dependency":
```bash
# Probe a dependency's health/endpoint directly (bypassing the app/gateway):
curl -s -o /dev/null -w "HTTP %{http_code}  %{time_total}s\n" --max-time 20 "<dependency-url>/<health-or-known-path>"
```
Reason about the **headers/body** of the failing call recorded in the logs:
- `server=Anypoint Flex Gateway` **+ empty body (`content-length:0`) + 503** = **Envoy "no healthy upstream"** — the
  gateway (API Manager / Agent Broker egress/ingress) cannot reach the backend behind that route. The backend may
  be up directly yet unreachable **from the gateway** (common when they sit in **different private spaces** so the
  `internal-<space>` DNS doesn't resolve across them).
- A 5xx/4xx carrying the **backend's** own `server`/body = the backend itself is failing — go diagnose it next.
- Cross-check which **private space** the app, the gateway, and each dependency live in (Step 4). Internal URLs
  (`...internal-<space>...`) only resolve **within the same space/VPC**.

Other quick checks (any tool the org enables): Object Store, Anypoint MQ, VPC/VPN, API Manager policies (a policy
can return 429/503), recent redeploys (`lastModifiedDate`), and replica `reason` for OOM/restart loops.

## Step 7 — Root-cause catalog (patterns seen in this org)

Match the evidence to a known pattern, then state the fix:

| Symptom in logs / status | Likely root cause | Fix direction |
|---|---|---|
| App `RUNNING`; ERROR `503 ... server=Anypoint Flex Gateway`, empty body, on a gateway/connection URL | Gateway has **no healthy upstream** for that route — backend unreachable from the gateway (often **cross-private-space** internal URL) | Repoint the connection/route to a **reachable** (public, or same-space) backend URL; or co-locate app+gateway+backend in one space; redeploy the gateway |
| A2A/Agent Broker: `AgentCardHelper` 503, `Error type A2A:CONNECTIVITY`, `agent-loop` fails | Broker can't fetch downstream **agent cards** through the egress gateway (same gateway/space issue) | As above; verify each agent reachable directly; fix the agent-network connections |
| Agent card advertises `"url":"http://localhost:800x"` | Agent's **advertised endpoint** is wrong (localhost) — breaks A2A message-send even once reachable | Set the agent's public `url`/host in its config and redeploy that agent |
| `Couldn't find configuration property value for key ${secure.key}` at startup; app `NOT_RUNNING` | `secure.key` not supplied to the runtime | Pass `secure.key` as a (secure) property; redeploy (see deploy skill Step 4) |
| App `NOT_RUNNING`; connector login error with `CHANGE_ME`/placeholder creds (e.g. Salesforce `sfdc-config`) | Eager-connecting connector fails to authenticate with placeholder secrets | Supply real (sandbox) connector creds as CloudHub secure properties |
| Caller gets 503/timeout; app `publicUrl` blank, `generateDefaultPublicUrl:false` | App has **no public endpoint** (internal-only) — public client can't reach it | Enable a public URL, or call it via the proper ingress, or front it with an API |
| Replica `reason` shows OOM / restart loop; `mule.micro.mem` 0.1 vCore | Under-sized for the workload | Increase vCores/replicas |
| 401/403 on the diagnostic API calls | Token expired or Connected App lacks Runtime Manager read scope on that env | Re-mint token; ensure the Connected App has RM read on the environment |

## Step 8 — Report (and optionally a styled artifact)

Summarize for the user:
1. **What's actually wrong** in one line (e.g. "app is healthy; it relays a 503 from the egress gateway because the
   downstream agents are unreachable from the gateway's private space").
2. **Evidence** — the key log lines (with timestamps), statuses, and direct-probe results that prove it.
3. **Root cause** — the specific factor(s) from Step 7.
4. **Fix** — concrete, ordered steps, naming who/what applies them (UI config, redeploy, etc.).
5. **Verification** — how to confirm after the fix (re-read logs, re-probe the route, re-invoke from the client).
6. State plainly that all actions were **read-only**; list anything that needs the user/DevOps to change.

If the user wants a deliverable, write a **self-contained HTML report** (dark, no external deps): TL;DR banner,
numbered investigation steps each with *reasoning → API call → result*, a request-flow diagram, a root-cause table,
the fix, and verification. (A headless Edge/Chrome print-to-PDF can follow if a PDF is requested.)

## Step 9 — API endpoint reference (CloudHub 2.0)

| Purpose | Method & path (host `https://anypoint.mulesoft.com`) |
|---|---|
| Token (client credentials) | `POST /accounts/api/v2/oauth2/token` (JSON body) |
| Org / user context | `GET /accounts/api/me` |
| Environments | `GET /accounts/api/organizations/{orgId}/environments` |
| List CH2 deployments | `GET /amc/application-manager/api/v2/organizations/{orgId}/environments/{envId}/deployments` |
| CH2 deployment detail | `GET /amc/application-manager/api/v2/.../deployments/{deploymentId}` |
| CH2 spec versions | `GET /amc/application-manager/api/v2/.../deployments/{deploymentId}/specs` |
| CH2 logs (use `?descending=true&startTime=&endTime=&limit=`) | `GET /amc/application-manager/api/v2/.../deployments/{deploymentId}/specs/{specId}/logs` |
| CH1 apps / logs | `GET /cloudhub/api/v2/applications` (+ `X-ANYPNT-ENV-ID`, `X-ANYPNT-ORG-ID` headers) |

> Many ARM endpoints also accept/require `X-ANYPNT-ORG-ID` and `X-ANYPNT-ENV-ID` headers in addition to the path
> parameters — add them if a call returns 404/403 unexpectedly.

---

### Guardrails
- **Read-only**: this skill never restarts, redeploys, scales, or edits config/secrets on its own. Diagnose and
  recommend; get explicit approval before any mutating action, then hand off to the deploy/DevOps skill.
- **Secrets**: read the Connected App secret from `settings.xml` only; never print it or write it into reports.
- **Verify before claiming**: quote the actual log lines/statuses you observed; if logs were empty for the window,
  say so and widen the window rather than guessing.
