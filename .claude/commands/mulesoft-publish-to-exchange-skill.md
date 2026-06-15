---
description: Publish a MuleSoft Anypoint Studio application (or connector/API asset) to Anypoint Exchange using the mule-maven-plugin. Sets the Exchange-required groupId (Org ID GUID), adds distributionManagement, wires settings.xml credentials, then builds and runs `mvn deploy`. Verifies the asset appears in Exchange.
argument-hint: [path-to-mule-project] [org-id-guid] [version]
allowed-tools: [Read, Glob, Grep, Edit, Write, Bash]
---

# MuleSoft — Publish to Anypoint Exchange

Publish a Mule 4 application to **Anypoint Exchange** as a reusable asset. Anypoint Exchange requires the
Maven **`groupId` to equal the Anypoint Organization ID (a GUID)**, so this skill changes the project's groupId,
adds the Exchange `distributionManagement`, ensures credentials are present in `settings.xml`, then publishes
with `mvn deploy`.

> Use the companion skill `mulesoft-deploy-to-cloudhub-skill` to deploy the same app to CloudHub.

## Toolchain on this machine
- JAVA_HOME: `C:\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1`
- Maven: `C:\maven\apache-maven-3.9.9\bin\mvn.cmd`
- Always set `JAVA_HOME` before invoking Maven.

---

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
| **Org ID GUID** | becomes the `groupId` + Exchange URL | not secret; from Anypoint → Access Management → Organization |
| **Asset version** | the published version | recommend `-SNAPSHOT` (e.g. `1.0.0-SNAPSHOT`) so it can be re-published during iteration; a plain release version (`1.0.0`) cannot be published twice (Exchange returns 409) |
| **Anypoint username + password** | publish credentials | go into `settings.xml`, never the pom/repo |

Never echo the password back in plain text in your responses.

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

1. Read it. If there is no `<server>` with `id=exchange`, add one inside `<servers>`:
   ```xml
   <server>
       <id>exchange</id>
       <username>ANYPOINT_USERNAME</username>
       <password>ANYPOINT_PASSWORD</password>
   </server>
   ```
   Replace placeholders with the supplied credentials. If `<servers>` is self-closed (`<servers/>`), expand it.
2. Optional hardening: suggest `mvn --encrypt-password` so the stored password is encrypted rather than plaintext.
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
