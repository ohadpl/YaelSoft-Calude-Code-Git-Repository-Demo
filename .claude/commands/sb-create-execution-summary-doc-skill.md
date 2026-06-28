---
description: Generate a Shikun & Binui as-built EXECUTION SUMMARY document — a "what was actually done" report for an S&B delivery or task (e.g. the full SDLC of an Azure DevOps work item). Produces a styled HTML and a headless-rendered PDF that match the Shikun & Binui corporate template (logo cover, running header on every page), in Hebrew (RTL) by default or English. This is NOT a technical/design spec (use create-mulesoft-technical-spec-doc for that) — it summarizes the work performed, the artifacts produced, deployment results, fixes, and open items. For non-S&B projects use the brand-neutral create-execution-summary-doc-skill instead.
argument-hint: [task-id-or-name] [deliverables-folder] [he|en]
allowed-tools: [Read, Glob, Grep, Bash, PowerShell, Write, Edit]
---

# Shikun & Binui — Create Execution Summary Document

Generate a **Shikun & Binui corporate execution summary** (as-built report) describing **what was actually performed** for a delivery — typically the full SDLC of a task (e.g. an Azure DevOps work item). The output mirrors the S&B corporate look used by `sb-tech-spec-doc-generator-skill` (navy headings, RTL bordered tables, S&B logo cover, running header) and is rendered to both HTML and PDF.

> **Use this skill for Shikun & Binui projects.** For any other client/project, use the brand-neutral `create-execution-summary-doc-skill` (no S&B logo or company name).
>
> **Scope — what this is and is not.** This document summarizes *the work that was done*: the steps executed, the agents/skills/tools used, the artifacts produced (with paths), deployment results and links, issues found & fixed, and open items. It is **not** a technical/design specification — for a design spec or a reverse-engineered as-built *spec* use `create-mulesoft-technical-spec-doc`. The two are complementary.

---

## Step 1 — Resolve inputs

Resolve from `$ARGUMENTS`; otherwise ask the user **one** concise prompt for whatever is missing, then proceed:

| Input | Purpose | Default |
|---|---|---|
| **Task id / name** | document title + cover (e.g. "ADO #5492 — REALS→Salesforce Leads API") | ask if absent |
| **Deliverables folder** | where the produced artifacts live and where output is written (e.g. `C:\Users\ohadp\ADO_Tasks\<id>`) | the cwd |
| **Language** | `he` (Hebrew RTL, default) or `en` (English LTR) | `he` |
| **Work summary** | the facts to summarize (see Step 2) | gather per Step 2 |

State the resolved title, output folder, and language before proceeding.

## Step 2 — Gather the as-built facts (do NOT invent)

This document is **faithful** — only report what actually happened. Collect the facts from, in priority order:

1. **The caller / conversation context.** If this skill is invoked at the end of a multi-step task (by an orchestrator or another agent), the steps performed, agents/skills used, and outcomes are already known — use them directly.
2. **The deliverables folder.** `Glob`/`Read` the folder to enumerate the actual artifacts produced (specs, RAML/ZIP, CSV, test reports, etc.) with their real filenames.
3. **Git** (if a repo is involved). `git log --oneline` for the commits made; capture commit SHAs/URLs.
4. **Deployment state** (if anything was published/deployed). Use the real, verified status (e.g. Exchange asset coordinates, CloudHub app name + RUNNING/NOT_RUNNING) — query the platform if a token is available rather than assuming.

Capture these content blocks (omit any that genuinely don't apply):

- **Background & goal** — one short paragraph: what the task was and why.
- **Executive summary** — a table of each deliverable/action → status (Done / Running / Blocked) → short detail.
- **Per-step detail** — what was actually done at each step, and **which agent/skill/tool produced it**.
- **Artifacts list** — real filenames in the deliverables folder + where source code / repos live.
- **Deployment & links** — git commit URLs, Exchange asset coordinates, CloudHub app + status, any public URL.
- **Issues found & fixed** — notable problems and how they were resolved (e.g. a runtime/version mismatch).
- **Open items** — what remains before production use (credentials, confirmations, follow-ups).

If a needed fact is genuinely unknown, mark it `להשלמה` (he) / `TBD` (en) — never fabricate a status, URL, or version.

## Step 3 — Output filenames

Derive a display name from the task id/name (kebab or the project's existing display name). Write into the deliverables folder:

- HTML: `{out-dir}/{DisplayName}_Summary_{HE|EN}.html`
- PDF:  `{out-dir}/{DisplayName}_Summary_{HE|EN}.pdf`

## Step 4 — Generate the HTML

Write a complete `<!DOCTYPE html>` document. For Hebrew use `<html lang="he" dir="rtl">`; for English use `<html lang="en" dir="ltr">` plus the LTR overrides noted below. Use **exactly** this CSS (the S&B corporate template):

```css
@page { size: A4; margin: 16mm 18mm 16mm; }
* { box-sizing: border-box; }
body { font-family: 'David Libre','David','Times New Roman',Arial,sans-serif; direction: rtl; text-align: right;
       font-size: 13px; color: #1d1d1d; line-height: 1.75; margin: 0; }
.page-break { page-break-before: always; }
.running-header { position: fixed; top: 0; left: 0; right: 0; height: 11mm; z-index: 1;
                 border-bottom: 1.5px solid #c9d3db; padding-bottom: 4px; text-align: left; }
.running-header img { height: 9mm; }
.header-spacer { height: 15mm; }
table.layout { width: 100%; border-collapse: collapse; }
table.layout > thead > tr > th { padding: 0; border: none; background: transparent; }
table.layout > tbody > tr > td { padding: 0; border: none; background: transparent; vertical-align: top; }
.cover { text-align: center; padding-top: 70px; min-height: 92vh; page-break-after: always;
         position: relative; z-index: 2; background: #fff; }
.cover .cover-logo { width: 340px; max-width: 72%; margin: 0 auto 54px; display: block; }
.cover .company { font-size: 15px; color: #14506b; letter-spacing: 1px; margin-bottom: 56px; font-weight: bold; }
.cover h1 { font-size: 27px; color: #14506b; border: none; margin: 0 0 6px; }
.cover .subtitle { font-size: 16px; color: #b45309; margin-bottom: 64px; }
.cover .doc-meta { display: inline-block; text-align: right; font-size: 13px; color: #333; line-height: 2.1; }
.cover .doc-meta b { color: #14506b; }
h1 { font-size: 22px; color: #14506b; border-bottom: 3px solid #14506b; padding-bottom: 6px; margin: 30px 0 4px; }
h2 { font-size: 17px; color: #14506b; margin-top: 26px; border-right: 4px solid #14506b; padding-right: 10px; }
h3 { font-size: 14.5px; color: #1f3a4d; margin-top: 20px; }
table.data, table.detail-table { border-collapse: collapse; width: 100%; margin: 12px 0; direction: rtl; table-layout: fixed; }
table.data th, table.detail-table th { background: #14506b; color: #fff; padding: 7px 10px; text-align: right; font-size: 12px; border: 1px solid #0e3d52; }
table.data td, table.detail-table td { border: 1px solid #c4ccd4; padding: 7px 10px; vertical-align: top; font-size: 12px; overflow-wrap: anywhere; word-break: break-word; }
table.data tr:nth-child(even) td { background: #f3f7fa; }
td.num, th.num { width: 34px; text-align: center; }
.detail-table td:first-child { width: 160px; font-weight: bold; background: #eef3f7; }
code { direction: ltr; unicode-bidi: embed; background: #eef1f3; border: 1px solid #dfe4e8; border-radius: 3px;
       padding: 1px 5px; font-family: Consolas, monospace; font-size: 11px; color: #b3261e;
       overflow-wrap: anywhere; word-break: break-word; }
.json { direction: ltr; text-align: left; background: #f7f8fa; color: #1d1d1d; border: 1px solid #dfe4e8;
        border-radius: 6px; padding: 12px 16px; font-family: Consolas, monospace; font-size: 11px;
        white-space: pre-wrap; overflow-wrap: anywhere; }
ul, ol { margin: 6px 24px 6px 0; padding: 0; }
li { margin-bottom: 4px; }
.badge { display: inline-block; background: #e8f0fe; color: #14506b; border-radius: 4px; padding: 1px 8px; font-size: 11px; font-weight: bold; }
.badge-green { background: #e6f4ea; color: #1e6e34; }
.badge-orange { background: #fff3e0; color: #b45309; }
.note { background: #f3f7fa; border: 1px solid #d6dee5; border-radius: 6px; padding: 10px 14px; margin: 10px 0; }
.footer { margin-top: 40px; font-size: 10.5px; color: #888; border-top: 1px solid #ddd; padding-top: 8px; }
```

> For **English (`en`)**, add a second `<style>` after the block above: `body{direction:ltr;text-align:left} h2{border-right:none;border-left:4px solid #14506b;padding-right:0;padding-left:10px} .running-header{text-align:right} table.data,table.detail-table{direction:ltr} table.data th{text-align:left} .cover .doc-meta{text-align:left} ul,ol{margin:6px 0 6px 24px}`.

**Logo:** put the literal token `@@LOGO@@` wherever the logo `<img src>` goes (cover hero + running header). Step 5 replaces it with the S&B base64 data-URI — do not paste base64 yourself.

### Document skeleton

Cover (page 1) → one fixed running-header → a layout table whose empty `<thead>` reserves header space and whose `<tbody>` holds the body.

```html
<body>
<div class="running-header"><img src="@@LOGO@@" alt="שיכון ובינוי"></div>
<div class="cover">
  <img class="cover-logo" src="@@LOGO@@" alt="שיכון ובינוי">
  <div class="company">שיכון ובינוי</div>
  <h1>מסמך סיכום ביצוע<br>{שם הממשק / הפרויקט}</h1>
  <div class="subtitle">{task id — e.g. ADO #5492}</div>
  <div class="doc-meta">
    <b>גרסת מסמך:</b> 1.0<br>
    <b>תאריך:</b> {DD/MM/YYYY}<br>
    <b>משימת מקור:</b> {task id}<br>
    <b>מבצע:</b> {author / team}
  </div>
</div>
<table class="layout">
<thead><tr><th><div class="header-spacer"></div></th></tr></thead>
<tbody><tr><td>
  ... body sections ...
</td></tr></tbody>
</table>
</body>
```

Inside `<tbody><td>`, emit these sections (Hebrew labels; use English equivalents for `en`):

1. **`1. רקע ומטרה`** — background & goal paragraph; a `.note` for scope caveats if relevant.
2. **`2. תמצית מנהלים — מצב סופי`** — `table class="data"`: `תוצר / פעולה | סטטוס | פרט`, one row per deliverable/action; status via `.badge-green` (Done/Running) / `.badge-orange` (Blocked/Pending).
3. **`3. פירוט הביצוע`** — one `h2`/`h3` per step describing what was done and **which agent/skill/tool** produced it; use `detail-table` for per-step key/value detail.
4. **(optional) `4. ארכיטקטורה`** — a short `.json` ASCII diagram if it aids understanding.
5. **`רשימת תוצרים`** — `table class="data"` of real filenames + descriptions; note where source/repos live.
6. **`פעולות פתוחות`** — `table class="data"` of remaining items before production.

Add a `<div class="footer">שיכון ובינוי &nbsp;|&nbsp; {title} &nbsp;|&nbsp; גרסה 1.0 &nbsp;|&nbsp; {Month YYYY}</div>` at the end.

### Table conventions
- Every content table gets `class="data"` (multi-column) or `class="detail-table"` (2-column key/value). Set explicit `<th>` widths inline (`table-layout:fixed` is on). The numbering column is right-most in RTL with `class="num"`.
- Wrap every English identifier, path, filename, version, URL in `<code>`. JSON/diagrams go in `.json` (LTR).

## Step 5 — Embed the logo, then render the PDF

The S&B logo is a skill asset. Embed it as a base64 data-URI (self-contained HTML is required for headless print) and render with **Microsoft Edge** — on this machine Chrome's `--headless` exits 0 but silently writes nothing, whereas Edge (same engine/flags) works. Run this single PowerShell block (substitute the two paths):

```powershell
$html = "{html-output-path}"; $pdf = "{pdf-output-path}"
$assets = "C:\Users\ohadp\.claude\commands\assets"
$b64file = Join-Path $assets "sb-logo.b64.txt"
if (-not (Test-Path $b64file)) {
  $png = Join-Path $assets "sb-logo.png"
  $uri = "data:image/png;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($png))
  Set-Content -Path $b64file -Value $uri -NoNewline -Encoding ascii
}
$dataUri = Get-Content $b64file -Raw
$content = [IO.File]::ReadAllText($html).Replace('@@LOGO@@', $dataUri)
[IO.File]::WriteAllText($html, $content, (New-Object System.Text.UTF8Encoding($false)))

$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$exe  = (Test-Path $edge) ? $edge : "C:\Program Files\Google\Chrome\Application\chrome.exe"
$tmp  = Join-Path $env:TEMP ("pdf_" + [guid]::NewGuid().ToString("N"))
$url  = "file:///" + ($html -replace '\\','/')
# Each path arg MUST be double-quoted (output folder names often contain a space).
$argline = "--headless=new --disable-gpu --no-sandbox --user-data-dir=`"$tmp`" --print-to-pdf=`"$pdf`" --no-pdf-header-footer --run-all-compositor-stages-before-draw `"$url`""
Start-Process -FilePath $exe -ArgumentList $argline -Wait
Start-Sleep -Seconds 2
if (Test-Path $pdf) { Get-Item $pdf | Select-Object Name, Length } else { Write-Output "PDF NOT WRITTEN — is it open/locked in a viewer? Close it and retry." }
```

Notes:
- A 0 exit code does **not** guarantee the file was written — always `Test-Path`. If the PDF doesn't update, it's almost always locked open in a viewer (render to a new name or ask the user to close it).
- The logo asset lives at `C:\Users\ohadp\.claude\commands\assets\sb-logo.png` (cached `sb-logo.b64.txt`). If missing, ask the user for the S&B logo and copy it there.

## Step 6 — Confirm output

After both files are written, print:

```
מסמך סיכום ביצוע (שיכון ובינוי) נוצר:
  שפה: {he | en}
  HTML: {html-output-path}
  PDF:  {pdf-output-path}
  משימה: {task id/name}
```

Then list briefly any section left as `להשלמה` / `TBD`, or any fact you could not verify, so the user can review before finalizing.

## Generation rules

- **Faithful, not invented.** Report only what actually happened — real filenames, statuses, versions, URLs, commit SHAs. Mark unknowns `להשלמה`/`TBD`; never fabricate.
- **Attribute the work.** For each step, name the agent/skill/tool that produced it (this is an execution record).
- **Never show credentials** — reference only placeholders (`${...}` / `CHANGE_ME`).
- **Hebrew prose, English identifiers** (for `he`): keep field names, paths, filenames, versions, URLs, JSON in Latin/`<code>`; prose in Hebrew.
- **Self-contained HTML** — embed the S&B logo as base64; no external/relative image refs (they don't render in headless print).
