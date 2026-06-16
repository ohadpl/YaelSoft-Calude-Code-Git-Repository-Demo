---
description: Deploy a MuleSoft Anypoint Studio application to CloudHub (CloudHub 2.0 by default, or CloudHub 1.0) using the mule-maven-plugin. Adds the cloudhub2Deployment/cloudHubDeployment config, wires settings.xml credentials, passes secure.key and app properties, then builds and runs the deploy goal. Verifies the app in Runtime Manager.
argument-hint: [path-to-mule-project] [ch2|ch1] [environment] [app-name]
allowed-tools: [Read, Glob, Grep, Edit, Write, Bash]
---

# MuleSoft — Deploy to CloudHub

Deploy a Mule 4 application to **CloudHub** via the `mule-maven-plugin`. Defaults to **CloudHub 2.0** (shared
space, `provider=MC`); supports **CloudHub 1.0** if requested. Credentials live only in `settings.xml`, and
org/env/app-specific values are passed as Maven `-D` properties so nothing secret is hardcoded in the pom.

> Use the companion skill `mulesoft-publish-to-exchange-skill` to publish the same app to Anypoint Exchange.

## Toolchain on this machine
- JAVA_HOME: `C:\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1`
- Maven: `C:\maven\apache-maven-3.9.9\bin\mvn.cmd`
- Always set `JAVA_HOME` before invoking Maven.

---

## Step 1 — Resolve the project and target

1. If `$ARGUMENTS` contains a path to a Mule project (folder with `pom.xml` + `src/main/mule/`), use it.
   **Otherwise ask the user:** "What is the path to the Mule project to deploy?" Wait for the answer.
2. Read `pom.xml`: capture `artifactId`, `version`, the Mule runtime (`app.runtime`/`<muleVersion>`), and confirm
   `mule-maven-plugin` has `<extensions>true</extensions>` (add it if missing).
3. Read `mule-artifact.json` for `minMuleVersion` / `requiredProduct`, and `src/main/mule/global-config.xml` to
   detect whether the app uses the **secure-properties module** (`key="${secure.key}"`) — if so, `secure.key`
   **must** be supplied to the CloudHub runtime or the app fails to start (see Step 4).
4. Target: default **CloudHub 2.0** unless `$ARGUMENTS` says `ch1`. State the resolved project, runtime, and target.

## Step 2 — Gather the required values

Use any present in `$ARGUMENTS`; otherwise **ask the user** (one concise prompt) and wait. Never echo the password.

**CloudHub 2.0 (default):**
| Value | `-D` property | Notes |
|---|---|---|
| Environment name | `ch2.environment` | e.g. `Sandbox` |
| Business group GUID | `ch2.businessGroupId` | = Org ID GUID if no sub-group |
| Shared-space target | `ch2.target` | exact name from Runtime Manager, e.g. `Cloudhub-US-East-2` |
| Application name | `ch2.applicationName` | default = `artifactId`; must be unique in the env |
| Replica size (vCores) | (in pom) | recommend `0.1` |
| Replicas | (in pom) | recommend `1` |
| Anypoint username + password | settings.xml | stored in `settings.xml`, never the pom |
| secure.key (if app uses secure props) | `ch2.secure.key` | non-prod placeholder `localDevKey1234567890` is fine if secure-config.yaml holds only plaintext; production = real AES key |

**CloudHub 1.0 (if `ch1`):** environment, application name (globally unique), region (e.g. `us-east-2`),
worker type (e.g. `MICRO`), worker count (e.g. `1`), Mule runtime version, plus username/password.

## Step 3 — Add the deployment config to pom.xml

Add a `<configuration>` to the existing `mule-maven-plugin` element. **Never** put credential literals in the pom.
**Recommended auth = Connected App (client credentials)** — works with SSO/MFA; the client id/secret come from
properties defined in a `settings.xml` active profile (Step 5), so the secret is never in the pom or on the
command line. (Username/password via `<server>` is the alternative; never mix username/password with
`<connectedAppClientId>`.)

**CloudHub 2.0 (verified working with mule-maven-plugin 4.9.1):**
```xml
<configuration>
    <cloudhub2Deployment>
        <provider>MC</provider>
        <environment>${ch2.environment}</environment>
        <target>${ch2.target}</target>
        <businessGroupId>${ch2.businessGroupId}</businessGroupId>
        <applicationName>${ch2.applicationName}</applicationName>
        <muleVersion>${app.runtime}</muleVersion>
        <replicas>1</replicas>
        <vCores>0.1</vCores>
        <!-- Connected App auth; values resolved from settings.xml active profile -->
        <connectedAppClientId>${anypoint.connectedApp.clientId}</connectedAppClientId>
        <connectedAppClientSecret>${anypoint.connectedApp.clientSecret}</connectedAppClientSecret>
        <connectedAppGrantType>client_credentials</connectedAppGrantType>
        <deploymentSettings>
            <generateDefaultPublicUrl>true</generateDefaultPublicUrl>
        </deploymentSettings>
        <properties>
            <!-- resolves ${secure.key} on the CloudHub runtime; omit if the app has no secure props -->
            <secure.key>${ch2.secure.key}</secure.key>
        </properties>
    </cloudhub2Deployment>
</configuration>
```
> Notes: `businessGroupId` = the Org ID GUID for the root org. `target` must match the shared-space name in
> Runtime Manager exactly (e.g. `Cloudhub-US-East-2`). Valid `vCores`: 0.1, 0.2, 0.5, 1, … To hide `secure.key`
> in Runtime Manager, use `<secureProperties>` instead of `<properties>` (one, not both).

**CloudHub 1.0** (only if requested): use `<cloudHubDeployment>` with `<server>`, `<environment>`,
`<applicationName>`, `<muleVersion>`, `<region>`, `<workerType>`, `<workers>`, and a `<properties>` map for
`secure.key`.

If a `<configuration>` already exists on the plugin, merge into it rather than duplicating the element.

## Step 4 — secure.key requirement (critical)

If the app uses the secure-properties module, `${secure.key}` MUST reach the CloudHub runtime, or it fails at
init with `Couldn't find configuration property value for key ${secure.key}`. This skill sets it via the
`<properties>` map above, fed by `-Dch2.secure.key=...` at deploy time (NOT a local Maven `-Dsecure.key`, which
would only affect the local JVM). For a placeholder/POC deploy use `localDevKey1234567890`; for production pass
the real AES key as a CloudHub **secure** property.

## Step 5 — Ensure credentials in settings.xml

Settings file: `C:\Users\ohadp\.m2\settings.xml` (user-global; outside any repo).

**Connected App (recommended)** — the `<cloudhub2Deployment>` references `${anypoint.connectedApp.clientId}` /
`${anypoint.connectedApp.clientSecret}`, so define them in an **active profile** (keeps the secret out of the pom
and off the command line):
```xml
<profiles>
    <profile>
        <id>anypoint-connected-app</id>
        <properties>
            <anypoint.connectedApp.clientId>CLIENT_ID</anypoint.connectedApp.clientId>
            <anypoint.connectedApp.clientSecret>CLIENT_SECRET</anypoint.connectedApp.clientSecret>
        </properties>
    </profile>
</profiles>
<activeProfiles>
    <activeProfile>anypoint-connected-app</activeProfile>
</activeProfiles>
```
The connected app needs **Runtime Manager** scopes (Create/Read/Manage/Delete Applications) granted on the target
environment. (One pipeline-wide app can also carry the Exchange Contributor scope — same app for both skills.)

**Username/password (alternative, non-SSO orgs)** — instead use a `<server id=cloudhub2>` with
`<username>`/`<password>` and reference `<server>cloudhub2</server>` in the deployment block.

Never write credentials into the project folder. Optionally `mvn --encrypt-password`.

## Step 6 — Build and deploy

```powershell
$env:JAVA_HOME = "C:\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1"
$mvn = "C:\maven\apache-maven-3.9.9\bin\mvn.cmd"
$proj = "<PROJECT_PATH>"

# Build the deployable artifact
& $mvn -f "$proj\pom.xml" clean package -DskipTests

# Deploy to CloudHub 2.0 (mule:deploy goal reads <cloudhub2Deployment>; auth via the connected-app active profile)
# Note: use the `mule:deploy` GOAL (not `mvn deploy`) so this does NOT also trigger an Exchange distributionManagement upload.
& $mvn -f "$proj\pom.xml" mule:deploy -DskipTests `
    "-Dch2.environment=<ENV>" `
    "-Dch2.businessGroupId=<BG_OR_ORG_GUID>" `
    "-Dch2.target=<SHARED_SPACE_NAME>" `
    "-Dch2.applicationName=<APP_NAME>" `
    "-Dch2.secure.key=<SECURE_KEY>"
```
Capture the output; the plugin polls until the app reaches `STARTED`/`APPLIED` or the timeout. A non-zero exit
means the deploy failed.

## Step 7 — Handle common failures
- **401/403** → bad credentials or missing deploy permission in that environment/business group.
- **"target not found"** → `ch2.target` must match a shared space exactly as shown in Runtime Manager.
- **`${secure.key}` PropertyNotFoundException** → the `<properties>` secure.key wasn't set (Step 3/4).
- **App starts then fails / fails to start with placeholder secrets** → connectors that connect eagerly (e.g.
  Salesforce `sfdc-config` basic auth) will fail to log in with `CHANGE_ME` creds; HTTP request configs connect
  lazily and start fine. For a clean `STARTED` status, supply real (sandbox) connector creds as CloudHub
  secure properties. **Flag this to the user when deploying with placeholders.**

## Step 8 — Verify and report
1. In **Runtime Manager** → the target environment → Applications: the app should appear with the expected
   replicas/size; the **Properties** tab shows `secure.key`; **Logs** confirm a clean start (or shows the
   expected connector-credential error if deployed with placeholders).
2. Report: resolved project, target (CH2 shared space + region), app name, deploy status, and that credentials
   were stored only in `settings.xml`. Note the pom now carries the deployment config — the user may want to commit it.
