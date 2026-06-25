---
description: Publish a MuleSoft Anypoint Studio application (or connector/API asset) to Anypoint Exchange using the mule-maven-plugin. Also supports publishing non-Mule assets (Python agents, HTTP APIs, external agents) to Exchange via the Exchange REST API. Sets the Exchange-required groupId (Org ID GUID), adds distributionManagement, wires settings.xml credentials, then builds and runs `mvn deploy` for Mule apps; generates and runs a Python registration script for non-Mule assets.
argument-hint: [path-to-project] [org-id-guid] [version]
allowed-tools: [Read, Glob, Grep, Edit, Write, Bash, PowerShell]
---

# MuleSoft — Publish to Anypoint Exchange

This skill handles **two distinct paths** depending on whether the project is a Mule application or a
non-Mule asset (Python agent, external HTTP API, etc.).

> Use the companion skill `mulesoft-deploy-to-cloudhub-skill` to deploy Mule apps to CloudHub.

## Toolchain on this machine
- JAVA_HOME: `C:\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1`
- Maven: `C:\maven\apache-maven-3.9.9\bin\mvn.cmd`
- Python: `C:\Users\ohadp\.local\bin\python3.14.exe` (managed by uv — do NOT pip install into it)
- uv: `C:\Users\ohadp\.local\bin\uv.exe` — use `uv run --with <pkg> <script>` to run scripts with dependencies
- Always set `JAVA_HOME` before invoking Maven.

---

## Step 0 — Detect the project type

Check whether the target path contains a `pom.xml` with `<packaging>mule-application</packaging>` and a
`src/main/mule/` directory.

- **Yes** → follow the **Mule Application path** (Steps 1–7 below).
- **No** → follow the **Non-Mule Asset path** (Steps A–E below).

---

# PATH 1 — Mule Application (Maven / mule-maven-plugin)

## Step 1 — Resolve the project

1. If `$ARGUMENTS` contains a path to a Mule project (a folder with `pom.xml` and `src/main/mule/`), use it.
   **Otherwise ask the user:** "What is the path to the Mule project to publish?" Wait for the answer.
2. Read the `pom.xml`. Capture the current `groupId`, `artifactId`, `version`, `packaging` (must be
   `mule-application`), and confirm the `mule-maven-plugin` is declared with `<extensions>true</extensions>`
   (required — add it if missing).
3. State the resolved project path and current Maven coordinates before proceeding.

## Step 2 — Gather the required values

Collect these. Use any present in `$ARGUMENTS`; otherwise **ask the user** (one concise prompt) and wait:

| Value | Purpose | Notes |
|---|---|---|
| **Org ID GUID** | becomes the `groupId` + Exchange URL | not secret; from Anypoint → Access Management → Business Groups → Settings tab → **Business Group ID** field. Do NOT take this from an existing pom.xml — it may belong to a different business group. |
| **Asset version** | the published version | recommend `-SNAPSHOT` (e.g. `1.0.0-SNAPSHOT`) so it can be re-published during iteration; a plain release version (`1.0.0`) cannot be published twice (Exchange returns 409) |
| **Anypoint credentials** | publish credentials | Connected App preferred (see Step 4); go into `settings.xml`, never the pom/repo |

Never echo the password or client secret back in plain text in your responses.

## Step 3 — Edit the pom.xml

1. **Change `<groupId>`** to the Org ID GUID. (Record the old groupId in your summary so the user knows it changed.)
2. **Set `<version>`** to the chosen asset version (e.g. `1.0.0-SNAPSHOT`).
3. **Add a project-level `<distributionManagement>`** (if not already present). The repository `id` must match
   the `settings.xml` server id `exchange`:
   ```xml
   <distributionManagement>
       <repository>
           <id>exchange</id>
           <name>Anypoint Exchange v3</name>
           <url>https://maven.anypoint.mulesoft.com/api/v3/organizations/ORG_ID_GUID/maven</url>
           <layout>default</layout>
       </repository>
   </distributionManagement>
   ```
   Substitute the literal Org ID GUID into the URL (the URL segment cannot be a Maven property reliably).
4. Confirm `<extensions>true</extensions>` is set on the `mule-maven-plugin` — it is what binds the Exchange
   publish to the Maven `deploy` phase.

## Step 4 — Ensure credentials in settings.xml

Settings file: `C:\Users\ohadp\.m2\settings.xml` (user-global; **outside any git repo** — safe for credentials).

1. Read it. If there is no `<server>` with `id=exchange`, add one inside `<servers>` (expand `<servers/>` if self-closed). Use whichever auth the user chose:

   **Connected App (client credentials — recommended; required for SSO/MFA orgs).** The Exchange Maven facade
   takes a connected app as a special username/password pair — username is the literal `~~~Client~~~` and the
   password is `<clientId>~?~<clientSecret>`:
   ```xml
   <server>
       <id>exchange</id>
       <username>~~~Client~~~</username>
       <password>CLIENT_ID~?~CLIENT_SECRET</password>
   </server>
   ```
   The connected app needs the **Exchange Contributor** scope on the target org/business group.

   **CRITICAL — add TWO server entries with the same credentials.** The publish *upload* uses the
   `distributionManagement` repo id (`exchange`), but the Exchange pre-deploy *status check* re-resolves the
   publication status (`preConditions.json`) through the pom `<repository>` whose id is `anypoint-exchange-v3`.
   If only `exchange` is credentialed, the status check fails with **`401 Unauthorized` → "Artifact could not be
   resolved"** even though the upload succeeded (a `runId` is returned). So add BOTH:
   ```xml
   <server>
       <id>exchange</id>
       <username>~~~Client~~~</username>
       <password>CLIENT_ID~?~CLIENT_SECRET</password>
   </server>
   <server>
       <id>anypoint-exchange-v3</id>   <!-- must match the pom <repository> id used for resolution -->
       <username>~~~Client~~~</username>
       <password>CLIENT_ID~?~CLIENT_SECRET</password>
   </server>
   ```

   **Username / password (only if the org does not enforce SSO/MFA):**
   ```xml
   <server>
       <id>exchange</id>
       <username>ANYPOINT_USERNAME</username>
       <password>ANYPOINT_PASSWORD</password>
   </server>
   ```
2. Optional hardening: suggest `mvn --encrypt-password` so the stored secret is encrypted rather than plaintext.
3. **Never** write credentials into the project's `pom.xml` or any file under the project folder.

## Step 5 — Build and publish

Run from PowerShell:
```powershell
$env:JAVA_HOME = "C:\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1"
$mvn = "C:\maven\apache-maven-3.9.9\bin\mvn.cmd"
$proj = "<PROJECT_PATH>"

# Build the deployable artifact (skip MUnit for speed; drop -DskipTests to run tests)
& $mvn -f "$proj\pom.xml" clean package -DskipTests

# Publish to Anypoint Exchange (Maven deploy phase -> Exchange facade via the 'exchange' server)
& $mvn -f "$proj\pom.xml" deploy -DskipTests
```
Capture the output. A successful publish ends with `BUILD SUCCESS` and an upload log line to
`maven.anypoint.mulesoft.com/.../organizations/<orgId>/maven`.

## Step 6 — Handle common failures
- **401/403 Unauthorized** → wrong credentials or the user lacks the *Exchange Contributor* permission in that org.
- **409 Conflict / "version already exists"** → the version is a non-SNAPSHOT already published; bump the version
  or switch to `-SNAPSHOT` (Step 2/3) and re-run.
- **"groupId must match organization id"** → the `groupId` (Step 3.1) does not equal the Org ID GUID; fix it.
- **Could not resolve dependencies** → ensure Maven Central + the MuleSoft/Anypoint repos are in the pom
  `<repositories>` (they normally are).

## Step 7 — Verify and report
1. In **Anypoint Exchange**, search for the `artifactId` — the asset should appear as a **Mule application**,
   with the published version, under the org.
2. Report to the user: resolved project, old→new groupId, published version, the Exchange asset URL/coordinates,
   and that credentials were stored only in `settings.xml` (not committed).
3. Remind the user that the pom now carries the Org-ID groupId + distributionManagement — they may want to commit
   that, and that publishing is independent of CloudHub deployment (`mulesoft-deploy-to-cloudhub-skill`).

---

# PATH 2 — Non-Mule Asset (Exchange REST API)

Use this path for **Python agents, Node.js services, external HTTP APIs, A2A agents**, or any asset that is
not a Mule application and therefore has no `pom.xml` / Maven build.

The Exchange REST API (`POST /exchange/api/v2/assets`) accepts `multipart/form-data` and registers the asset
as an `http-api` (external HTTP endpoint). No file upload or spec is required.

## Step A — Gather required values

| Value | How to obtain |
|---|---|
| **Org ID GUID** | Anypoint Platform → Access Management → Business Groups → click the target group → **Settings** tab → **Business Group ID** field. NEVER take this from a pom.xml — it may belong to a different business group and will cause a silent 403. |
| **Connected App Client ID + Secret** | Already in `C:\Users\ohadp\.m2\settings.xml` between `~~~Client~~~` and `~?~`. Extract from there. |
| **Asset definitions** | For each asset: display name, asset ID (lowercase + hyphens only), description (max 256 chars), base URL |

**Reading credentials from settings.xml:** Parse the `<password>` field of the `<server id="exchange">` entry.
The format is `CLIENT_ID~?~CLIENT_SECRET` — split on `~?~` to get both values.

## Step B — Write the registration script

Write a Python script `register_in_exchange.py` (in the project directory) using this exact pattern.
All Exchange API knowledge from production use is encoded here — do not deviate:

```python
"""
register_in_exchange.py — Register assets in Anypoint Exchange via REST API.
Run with: uv run --with httpx register_in_exchange.py
"""
import os, sys
import httpx

ANYPOINT_BASE = "https://anypoint.mulesoft.com"
ASSET_VERSION = "1.0.0"

CLIENT_ID     = os.getenv("ANYPOINT_CLIENT_ID",     "")
CLIENT_SECRET = os.getenv("ANYPOINT_CLIENT_SECRET", "")
ORG_ID        = os.getenv("ANYPOINT_ORG_ID",        "")

# Define each asset to register
ASSET_DEFS = [
    {
        "asset_id":    "my-asset-id",          # lowercase + hyphens only
        "name":        "My Asset Name",         # display name shown in Exchange
        "description": "One-line description.", # hard limit: 256 characters
        "url":         os.getenv("MY_ASSET_URL", "http://localhost:8001"),
    },
    # ... add more assets here
]


def get_token(client: httpx.Client) -> str:
    resp = client.post(
        f"{ANYPOINT_BASE}/accounts/api/v2/oauth2/token",
        data={
            "grant_type":    "client_credentials",
            "client_id":     CLIENT_ID,
            "client_secret": CLIENT_SECRET,
        },
        timeout=15.0,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]
    # NOTE: the Anypoint token is an OPAQUE token, not a JWT — do not attempt to decode it.


def fetch_agent_card(base_url: str) -> dict | None:
    try:
        r = httpx.get(f"{base_url}/.well-known/agent.json", timeout=3.0)
        r.raise_for_status()
        return r.json()
    except Exception:
        return None


def register_asset(client: httpx.Client, token: str, asset: dict) -> None:
    description = asset["description"][:256]   # hard Exchange limit

    # Exchange REST API requires multipart/form-data — do NOT send JSON.
    # Required fields for type=http-api + classifier=http (no spec file needed):
    #   organizationId, groupId, assetId, version, name, description,
    #   type, classifier, apiVersion
    # groupId must equal organizationId (the Business Group ID GUID).
    fields = [
        ("organizationId", (None, ORG_ID)),
        ("groupId",        (None, ORG_ID)),
        ("assetId",        (None, asset["asset_id"])),
        ("version",        (None, ASSET_VERSION)),
        ("name",           (None, asset["name"])),
        ("description",    (None, description)),
        ("type",           (None, "http-api")),
        ("classifier",     (None, "http")),     # "http" = no spec file required
        ("apiVersion",     (None, "v1")),        # required when classifier=http
    ]

    resp = client.post(
        f"{ANYPOINT_BASE}/exchange/api/v2/assets",
        files=fields,                            # httpx sends as multipart/form-data
        headers={"Authorization": f"Bearer {token}"},
        timeout=30.0,
    )

    ref = f"{ORG_ID}/{asset['asset_id']}/{ASSET_VERSION}"
    if resp.status_code in (200, 201):
        print(f"  OK  {asset['name']}")
        print(f"      {ANYPOINT_BASE}/exchange/{ref}")
    elif resp.status_code == 409:
        print(f"  --  {asset['name']} already exists ({ASSET_VERSION}) — skipped")
    else:
        print(f"  FAIL  {asset['name']} — HTTP {resp.status_code}: {resp.text}")


def main():
    if not ORG_ID:
        print("ERROR: ANYPOINT_ORG_ID is required.")
        print("  Find it: Anypoint Platform → Access Management → Business Groups → Settings → Business Group ID")
        sys.exit(1)

    localhost_assets = [a for a in ASSET_DEFS if "localhost" in a["url"]]
    if localhost_assets:
        names = ", ".join(a["name"] for a in localhost_assets)
        print(f"WARNING: {names} still point to localhost — register now but update URLs before Agent Broker use.\n")

    with httpx.Client() as client:
        print("Authenticating...")
        token = get_token(client)
        print("Authenticated.\n")
        for asset in ASSET_DEFS:
            register_asset(client, token, asset)

    print(f"\nExchange: {ANYPOINT_BASE}/exchange/{ORG_ID}/")


if __name__ == "__main__":
    main()
```

## Step C — Run the script

```powershell
$env:ANYPOINT_CLIENT_ID     = "CLIENT_ID_HERE"
$env:ANYPOINT_CLIENT_SECRET = "CLIENT_SECRET_HERE"
$env:ANYPOINT_ORG_ID        = "ORG_ID_GUID_HERE"
# Set per-asset URL env vars if assets are deployed (skip if still localhost)
# $env:MY_ASSET_URL = "https://my-agent.example.com"

& "C:\Users\ohadp\.local\bin\uv.exe" run --with httpx "<PROJECT_PATH>\register_in_exchange.py"
```

## Step D — Handle common failures

| Error | Cause | Fix |
|---|---|---|
| **403 Forbidden** (even with Exchange Contributor scope) | Wrong Org ID — the Business Group ID in the script does not match the org the Connected App's scope was granted on | Get the correct ID from Access Management → Business Groups → Settings → Business Group ID |
| **400 "Missing mandatory asset field: classifier"** | `classifier` field not included | Add `("classifier", (None, "http"))` to the fields list |
| **400 "Missing mandatory asset field: apiVersion"** | `apiVersion` field not included when `classifier=http` | Add `("apiVersion", (None, "v1"))` to the fields list |
| **400 "description must NOT have more than 256 characters"** | Description too long | Truncate to `description[:256]` |
| **415 Unsupported Media Type** | Sending `Content-Type: application/json` | Exchange requires `multipart/form-data` — use `files=` in httpx, never `json=` |
| **409 Conflict** | Asset + version already registered | Bump `ASSET_VERSION` or handle 409 as a skip |
| **500 "Invalid character in name"** | Field names with bracket syntax (`files[custom]`, `tags[]`) can trigger internal Exchange errors | Avoid bracket field names; use the minimal field set shown in Step B |

**Diagnosing a persistent 403:** A GET to `/exchange/api/v2/assets?organizationId=...` returning HTTP 200
does NOT confirm write access. Read and write permissions are checked separately. Always verify the Org ID
is the Business Group ID of the org where the Connected App's Exchange Contributor scope was granted.

**Token format:** The Anypoint Platform client_credentials token is an **opaque string, not a JWT**. It
cannot be base64-decoded to extract org information. To find the correct org ID, use the Anypoint Platform
UI (Access Management → Business Groups → Settings tab).

## Step E — Verify and report

1. Open `https://anypoint.mulesoft.com/exchange/{ORG_ID}/` — each registered asset should appear.
2. Confirm assets are visible in the Exchange UI with correct names, descriptions, and version.
3. Remind the user that the assets are registered with their current (possibly localhost) URLs. Once the
   services are deployed to production URLs, re-run the script with the `*_URL` env vars set to update
   the Exchange records.
