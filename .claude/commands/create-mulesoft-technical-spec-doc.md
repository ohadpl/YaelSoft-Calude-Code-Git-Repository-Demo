---
description: Generate a PDF technical specification document for a MuleSoft Anypoint Studio project — either reverse-engineered from existing project code, or designed forward from a business requirements / business specification document. Matches the corporate HTML/PDF style template.
argument-hint: [project-path | business-requirements-doc-path]
allowed-tools: [Read, Glob, Grep, Write, Bash]
---

# Create MuleSoft Technical Specification Document

Generate a styled HTML and PDF technical specification for a MuleSoft integration. This skill works in **two modes**, both producing the *same* styled output:

- **Mode A — Reverse-engineer from code:** `$ARGUMENTS` points at (or the cwd is) an existing MuleSoft Anypoint Studio project. Extract real values from the project files. *(Original behavior.)*
- **Mode B — Forward design from a document:** `$ARGUMENTS` points at a business requirements document or business specification document. No code exists yet — read the requirements and **design** the MuleSoft technical solution (flows, connectors, endpoints, transformations), then document it.

## Step 1 — Resolve input and select mode

Look at `$ARGUMENTS`:

1. **If it is a file** (extension `.pdf`, `.docx`, `.doc`, `.txt`, `.md`, `.rtf`, `.html`) → **Mode B (forward design)**. This is a business requirements / specification document.
2. **If it is a directory** (or empty, meaning the cwd) → check for a `pom.xml` or `src/main/mule/` folder:
   - Found → **Mode A (reverse-engineer)**.
   - Not found, but the directory contains a requirements/spec document (e.g. a single `.pdf`/`.docx`/`.md`) → **Mode B**, using that document.
3. If ambiguous (e.g. both a project and a doc are present, or neither), state what you found and ask the user which mode they want before continuing.

State the selected mode and the resolved input path before proceeding.

---

## Step 2 (Mode A) — Discover and read all project files

Use Glob and Read to collect:

| File(s) | What to extract |
|---|---|
| `{root}/pom.xml` | `groupId`, `artifactId`, `version`, `packaging`; every `<dependency>` where `<classifier>` is `mule-plugin` (capture `artifactId`, `groupId`, `version`); the Mule Maven plugin version; `<mule.version>` or `<app.runtime>` property value |
| `{root}/mule-artifact.json` | `minMuleVersion`, `javaSpecificationVersions` |
| `{root}/src/main/mule/**/*.xml` | Every global config element (`http:listener-config`, `http:request-config`, `salesforce:sfdc-config`, `configuration-properties`, etc.); every `<flow>` and `<sub-flow>` with its name, doc:id, trigger element (listener path + method, scheduler expression, etc.), all processors in order, error-handler blocks |
| `{root}/src/main/resources/config.yaml` or `*.properties` | All property keys and their values, grouped by namespace |
| `{root}/src/main/resources/log4j2.xml` | Log file name, root log level, roll-over size and file count |
| `{root}/CLAUDE.md` | Any stated conventions (ports, naming patterns, response status codes, etc.) |

## Step 2 (Mode B) — Read the document and design the solution

### 2B.1 — Read the business document

Read the full document with the Read tool:
- `.pdf` → Read directly (use the `pages` parameter for long PDFs).
- `.md`, `.txt`, `.html`, `.rtf` → Read directly.
- `.docx` / `.doc` → extract the text first, then read it. Use Bash, e.g.:
  ```
  pandoc "{doc-path}" -t plain -o "{temp-txt-path}"
  ```
  If `pandoc` is unavailable, try a PowerShell Word COM extraction or `python-docx`; if no extraction is possible, tell the user and ask them to supply a PDF/TXT export.

### 2B.2 — Extract the requirements

From the document, capture:

| Capture | Notes |
|---|---|
| **Project / integration name** | Use it for the display name and Maven coordinates. |
| **Business goal & scope** | One-paragraph summary for the overview. |
| **Source system(s)** | What data comes from where (DB, SaaS, file, queue, API). Note protocol/auth if stated. |
| **Target system(s)** | Where data is written/sent (Salesforce, SAP, DB, API, queue). |
| **Trigger / cadence** | HTTP request, scheduled poll (interval/cron), event/queue listener, file watcher. |
| **Data entities & field mappings** | Source-to-target field mappings; these drive the DataWeave design. |
| **Business rules** | Filtering, validation, deduplication, batching, ordering, idempotency. |
| **Volume & performance** | Record counts, frequency, SLAs — drives batching/paging decisions. |
| **Error handling expectations** | Retries, dead-letter, notifications, partial-failure behavior. |
| **Security / compliance** | Auth schemes, PII handling, encryption-in-transit. |

If the document leaves a required technical detail unspecified, make a **reasonable, clearly-labeled engineering assumption** rather than stalling — record every assumption in the new **Design Assumptions** section (see generation rules).

### 2B.3 — Design the MuleSoft solution

Translate the requirements into a concrete Mule 4 design. Decide and document:

- **Maven coordinates** — propose `groupId` (e.g. `com.{company}.integration`), `artifactId` (kebab-case of the project name), `version` `1.0.0`, packaging `mule-application`.
- **Runtime** — default to a current supported Mule runtime (e.g. `4.6.x`), `minMuleVersion` accordingly, Java 17.
- **Connectors** — choose the connectors implied by the systems (HTTP, DB, Salesforce, SAP, Anypoint MQ, File, etc.) and propose a recent stable version for each.
- **Flows & sub-flows** — design the flow(s): trigger, processing steps in order, error handlers. Use the same flow modeling the spec documents in Section 4 (endpoint, numbered processing steps, response).
- **Global configurations** — listener/request configs, connection configs for each system, a `configuration-properties` file, secure properties for credentials.
- **DataWeave transformations** — design the key transforms from the field mappings (Section 9).
- **Endpoints & contracts** — for API-triggered flows, define method/path/payload; for scheduled/event flows, define the trigger.
- **Error handling, logging, configuration properties** — design these to satisfy the stated expectations.

Everything produced in Mode B is a **proposed design**, not extracted fact — mark proposed/assumed values per the generation rules so the reader knows what is a design decision versus a hard requirement.

---

## Step 3 — Determine output filenames

Convert `artifactId` (Mode A) or the designed `artifactId` (Mode B) to display name by capitalizing each word and keeping hyphens:
- `claudecode-sb-sms-services` → `ClaudeCode-SB-SMS-Services`
- `demo` → `DEMO`

Output location:
- **Mode A:** write into the project root, `{root}/...`.
- **Mode B:** write next to the source document, in its parent folder.

Outputs:
- HTML: `{out-dir}/{DisplayName}_Technical_Specification.html`
- PDF: `{out-dir}/{DisplayName}_Technical_Specification.pdf`

## Step 4 — Generate the HTML file

Write a complete `<!DOCTYPE html>` document. Use **exactly** this CSS inside `<style>`:

```css
body { font-family: Calibri, Arial, sans-serif; font-size: 13px; color: #222; margin: 60px 80px; line-height: 1.7; }
h1 { font-size: 26px; color: #1a3a5c; border-bottom: 3px solid #1a3a5c; padding-bottom: 8px; margin-bottom: 4px; }
h2 { font-size: 17px; color: #1a3a5c; margin-top: 32px; border-left: 4px solid #1a3a5c; padding-left: 10px; }
h3 { font-size: 14px; color: #333; margin-top: 20px; }
.meta { color: #666; font-size: 12px; margin-bottom: 32px; }
table { border-collapse: collapse; width: 100%; margin-top: 12px; }
th { background: #1a3a5c; color: #fff; padding: 8px 12px; text-align: left; font-size: 12px; }
td { border: 1px solid #ccc; padding: 8px 12px; vertical-align: top; font-size: 12px; }
tr:nth-child(even) td { background: #f5f7fa; }
code { background: #f0f0f0; border: 1px solid #ddd; border-radius: 3px; padding: 1px 5px; font-family: Consolas, monospace; font-size: 11px; color: #c0392b; }
pre { background: #1e1e1e; color: #d4d4d4; border-radius: 6px; padding: 16px 20px; font-family: Consolas, monospace; font-size: 11px; overflow-x: auto; line-height: 1.5; }
.keyword { color: #569cd6; } .string { color: #ce9178; } .comment { color: #6a9955; } .attr { color: #9cdcfe; } .tag { color: #4ec9b0; }
.section-box { background: #f5f7fa; border: 1px solid #dde3ec; border-radius: 6px; padding: 16px 20px; margin-top: 12px; }
.flow-step { display: flex; align-items: flex-start; margin: 10px 0; }
.step-num { background: #1a3a5c; color: #fff; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: bold; flex-shrink: 0; margin-right: 12px; margin-top: 2px; }
ul { margin: 8px 0 8px 20px; } li { margin-bottom: 4px; }
.badge { display: inline-block; background: #e8f0fe; color: #1a3a5c; border-radius: 4px; padding: 2px 8px; font-size: 11px; font-weight: bold; }
.badge-green { background: #e6f4ea; color: #1e6e34; } .badge-orange { background: #fff3e0; color: #b45309; }
.footer { margin-top: 60px; font-size: 11px; color: #999; border-top: 1px solid #ddd; padding-top: 10px; }
```

### Document structure

The section structure below is identical for both modes. In **Mode A** every value is extracted from code. In **Mode B** the values are your design — present the *same* sections, but mark proposed/assumed values per the generation rules, and add the **Design Assumptions** section described there. A few sections are sourced differently in Mode B:

- **Section 1 (Project Overview):** use the proposed Maven coordinates, runtime, and port from Step 2B.3.
- **Section 2 (Connector Dependencies):** list the connectors you selected, with proposed versions and the *Proposed* badge.
- **Sections 3–4 (Global Configs, Flows):** describe the designed configs and flows.
- **Section 9 (Data Transformation Detail):** write the DataWeave you designed from the field mappings; if a mapping is illustrative, say so.
- **Section 11 (Sample Request & Response):** use representative example payloads consistent with the designed contract.

**Title and meta line:**
```html
<h1>{DisplayName} Project — Technical Specification</h1>
<div class="meta">
  Document type: Technical Specification &nbsp;|&nbsp;
  Project: {DisplayName} &nbsp;|&nbsp;
  Version: {version} &nbsp;|&nbsp;
  Date: {Month YYYY} &nbsp;|&nbsp;
  Platform: MuleSoft Anypoint Platform {minMuleVersion}
</div>
```

In **Mode B**, append to the meta line: `&nbsp;|&nbsp; <span class="badge badge-orange">Proposed Design</span> &nbsp;|&nbsp; Source: {business-document-filename}` so the reader knows this is a forward design derived from a requirements document.

**Section 1 — Project Overview**
Table with rows: Maven Group ID (`<code>`), Maven Artifact ID (`<code>`), Version (`<code>`), Packaging (`<code>`), Mule Runtime (plain), Mule Maven Plugin (plain), HTTP Port (plain), Flow definition file(s) (`<code>`).

**Section 2 — Connector Dependencies**
Table columns: Connector | Group ID | Version | Purpose. One row per mule-plugin dependency. Infer Purpose from connector name:
- `mule-http-connector` → Inbound HTTP listener & outbound HTTP requests
- `mule-sockets-connector` → Low-level socket support (runtime dependency)
- `mule-salesforce-connector` → Salesforce integration (platform events, records)
- `mule-db-connector` → Database operations
- Other: describe from name

**Section 3 — Global Configurations**
One `<h3>` per named global config element, numbered 3.1, 3.2, etc. Format: `3.N {Type} — <code>{name}</code>`. Property table below each:
- HTTP Listener: Host, Port, doc:id
- HTTP Request: Host, Protocol, Port, Connection Timeout (if set), doc:id
- Salesforce: Auth type, Username property ref, Password property ref, Security Token property ref, doc:id
- Configuration Properties: file name

**Section 4 — Flows**
One `<h3>` per flow, numbered 4.1, 4.2, etc. Format: `4.N Flow: <code>{flow-name}</code>`.

Below the heading:
```html
<p><span class="badge">doc:id: {doc:id}</span></p>
```

Then an **Endpoint** table. Adapt columns to flow type:
- HTTP GET: Method | Path | Query Parameter | Format | Required
- HTTP POST: Method | Path | Content-Type | Request Body Description
- Scheduler: Trigger | Expression | Description
- No trigger (sub-flow): note it is a sub-flow called by other flows

Then a **Processing Steps** section using `.flow-step` divs:
```html
<div class="flow-step">
  <div class="step-num">1</div>
  <div><strong>{Step Name}</strong> — {description with <code> for technical values}</div>
</div>
```
Number every processor step. For `<foreach>`, indent sub-steps with `<ul>`. For `<choice>`, describe each branch as a sub-step.

Then a **Response** table: HTTP Status | Content-Type | Body. Include all success and error responses.

**Section 5 — Configuration Properties**
Table: Property Key | Default / Placeholder | Description. Extract all keys from config.yaml. For `CHANGE_ME` values, add to Description: *(replace before running)*.

**Section 6 — Error Handling Strategy**
Table: Error Type | HTTP Status | Response Format. One row per distinct error handler type found across all flows. Include both flow-level and global error handlers.

**Section 7 — Logging Convention**
Table: Event | Level | Message Pattern. Include START/END entries plus any significant mid-flow log events found. Below the table add a `<p>` noting the log file name and roll-over policy from log4j2.xml.

**Section 8 — External API Reference**
One `<h3>` per external system (one per `http:request-config` or cloud connector config). Property table: Base URL | Method | Key parameters | Response field(s) used | Authentication.

**Section 9 — Data Transformation Detail**
For each significant DataWeave transformation found in the flows (non-trivial ones — chunking, deduplication, format conversion, object building), create a `<div class="section-box">`. Format:
```html
<div class="section-box">
  <strong>Purpose:</strong> {description}<br/><br/>
  <strong>DataWeave:</strong>
  <pre>{actual DataWeave code, HTML-escaped}</pre>
</div>
```

**Section 10 — Build & Run**
```html
<pre><span class="comment"># Build</span>
mvn clean package

<span class="comment"># Build without tests</span>
mvn clean package -DskipTests

<span class="comment"># Deploy to local Mule runtime</span>
mvn clean package -DmuleDeploy</pre>
```

**Section 11 — Sample Request & Response**
For each HTTP flow, a `<pre>` block showing a realistic example request and the expected response. Use actual port numbers, paths, and example payloads.

**Section 12 (Mode B only) — Design Assumptions & Open Questions**
A `<div class="section-box">` followed by two tables:
- *Design Assumptions* — Assumption | Rationale | Impact if wrong. One row per engineering decision you made because the requirements were silent or ambiguous (e.g. chosen runtime version, batch size, retry count, auth scheme).
- *Open Questions* — Question | Why it matters | Suggested default. One row per item the user must confirm before development starts.

Place this section last (before the footer). Omit it entirely in Mode A.

**Footer:**
```html
<div class="footer">
  {DisplayName} &nbsp;|&nbsp; Technical Specification v{version} &nbsp;|&nbsp; MuleSoft Anypoint Platform {minMuleVersion} &nbsp;|&nbsp; {Month YYYY}
</div>
```

## Generation rules

- Use **real values** from the code — port numbers, hostnames, paths, connector versions.
- **Never show credentials** — show only the property placeholder (e.g., `${salesforce.password}`).
- Wrap all technical identifiers, connector names, config names, property keys, code values, and paths in `<code>` tags.
- Use `<pre>` with syntax highlighting spans (`.comment`, `.string`, `.keyword`, `.attr`) for code blocks.
- Skip a section entirely if there is no real content for it (e.g., skip Section 9 if there are no significant DataWeave transforms).
- Infer project purpose from flow names, endpoint paths, logger messages, and CLAUDE.md.

### Mode B (forward design) rules

- **Mark designed values.** Any value that is your design decision rather than a stated requirement gets `<span class="badge badge-orange">Proposed</span>` next to it (connector versions, runtime version, ports, batch sizes, etc.). Values that come straight from the requirements document need no badge.
- **Stay faithful to the requirements.** Field mappings, business rules, source/target systems, cadence, and volumes come directly from the document — do not invent business logic. Design only the *technical realization* of those requirements.
- **Make assumptions, don't stall.** When a needed technical detail is missing, pick a sensible default, proceed, and record it in Section 12 (Design Assumptions). Never leave a section blank waiting for input.
- **Keep credentials abstract.** Reference secure-property placeholders (e.g. `${salesforce.password}`) for every secret — there are no real values yet.
- **Be buildable.** The designed flows, connectors, and DataWeave must be internally consistent and realistic enough that `mulesoft-anypoint-developer-agent` could implement directly from this document.

## Step 5 — Convert HTML to PDF using Chrome headless

Run this command (Chrome is installed at the path shown):

```
"C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --print-to-pdf="{pdf-output-path}" --no-margins --run-all-compositor-stages-before-draw "{html-output-path}"
```

Replace `{html-output-path}` and `{pdf-output-path}` with the actual absolute paths from Step 3.

## Step 6 — Confirm output to user

After both files are written, print:

```
Technical specification generated:
  Mode: {A — reverse-engineered from project | B — designed from requirements doc}
  HTML: {html-output-path}
  PDF:  {pdf-output-path}
```

In **Mode B**, also list the key design assumptions and any open questions (from Section 12) inline in your reply so the user can confirm them before development starts.
