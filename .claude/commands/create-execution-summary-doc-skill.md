---
description: Generate a brand-neutral as-built EXECUTION SUMMARY document — a "what was actually done" report for any delivery or task (e.g. a full SDLC, a migration, a multi-step automation). Produces a styled, self-contained HTML and a headless-rendered PDF, in English (LTR) by default or any RTL language, with optional custom branding (company name + logo). This is NOT a technical/design spec — it summarizes the work performed, the artifacts produced, results/links, issues found & fixed, and open items. For Shikun & Binui projects use sb-create-execution-summary-doc-skill (S&B corporate template) instead.
argument-hint: [task-id-or-name] [deliverables-folder] [en|he|<lang>] [company-name] [logo-path]
allowed-tools: [Read, Glob, Grep, Bash, PowerShell, Write, Edit]
---

# Create Execution Summary Document (general)

Generate a clean, professional **execution summary** (as-built report) describing **what was actually performed** for a delivery — a task, an SDLC, a migration, an automation run, etc. The output is brand-neutral by default and can carry an optional company name + logo. Rendered to both HTML and PDF.

> **Use this for any project.** For Shikun & Binui deliverables, use `sb-create-execution-summary-doc-skill` (S&B logo + corporate template, Hebrew default).
>
> **Scope — what this is and is not.** This summarizes *the work that was done*: steps executed, agents/skills/tools used, artifacts produced (with paths), results & links, issues found & fixed, and open items. It is **not** a technical/design specification — pair it with a spec document if a design reference is also needed.

---

## Step 1 — Resolve inputs

Resolve from `$ARGUMENTS`; otherwise ask the user **one** concise prompt for whatever is missing, then proceed:

| Input | Purpose | Default |
|---|---|---|
| **Task id / name** | document title + cover | ask if absent |
| **Deliverables folder** | where artifacts live and where output is written | the cwd |
| **Language** | `en` (English LTR, default), `he`, or any language; set `dir=rtl` for RTL languages | `en` |
| **Company name** | optional cover/footer branding | none (omit) |
| **Logo path** | optional logo image (png/jpg) for the cover + running header | none (text-only cover) |
| **Work summary** | the facts to summarize (see Step 2) | gather per Step 2 |

State the resolved title, output folder, language, and whether a logo/company was supplied before proceeding.

## Step 2 — Gather the as-built facts (do NOT invent)

This document is **faithful** — only report what actually happened. Collect facts from, in priority order:

1. **The caller / conversation context.** If invoked at the end of a multi-step task (by an orchestrator or another agent), the steps performed, tools used, and outcomes are already known — use them directly.
2. **The deliverables folder.** `Glob`/`Read` to enumerate the real artifacts produced, with their actual filenames.
3. **Git** (if a repo is involved). `git log --oneline` for the commits made; capture SHAs/URLs.
4. **Deployment / external state** (if anything was published/deployed/run). Use the real, verified status — query the platform/API where possible rather than assuming.

Capture these content blocks (omit any that genuinely don't apply):

- **Background & goal** — one short paragraph: what the task was and why.
- **Executive summary** — a table of each deliverable/action → status (Done / Running / Blocked) → short detail.
- **Per-step detail** — what was actually done at each step, and **which agent/skill/tool produced it**.
- **Artifacts list** — real filenames in the deliverables folder + where source code / repos live.
- **Results & links** — git commit URLs, published-asset coordinates, deployed app + status, any public URL.
- **Issues found & fixed** — notable problems and how they were resolved.
- **Open items** — what remains before production / sign-off.

If a fact is genuinely unknown, mark it `TBD` — never fabricate a status, URL, or version.

## Step 3 — Output filenames

Derive a display name from the task id/name. Write into the deliverables folder:

- HTML: `{out-dir}/{DisplayName}_Execution_Summary.html`
- PDF:  `{out-dir}/{DisplayName}_Execution_Summary.pdf`

## Step 4 — Generate the HTML

Write a complete `<!DOCTYPE html>` document. Default `<html lang="en" dir="ltr">`; for an RTL language use `dir="rtl"` and the RTL overrides noted below. Use **exactly** this brand-neutral CSS:

```css
@page { size: A4; margin: 16mm 18mm 16mm; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', Calibri, Arial, sans-serif; direction: ltr; text-align: left;
       font-size: 13px; color: #1d1d1d; line-height: 1.7; margin: 0; }
.page-break { page-break-before: always; }
.running-header { position: fixed; top: 0; left: 0; right: 0; height: 11mm; z-index: 1;
                 border-bottom: 1.5px solid #cfd6dd; padding-bottom: 4px; text-align: right; }
.running-header img { height: 9mm; }
.running-header .rh-title { font-size: 10px; color: #6b7785; }
.header-spacer { height: 15mm; }
table.layout { width: 100%; border-collapse: collapse; }
table.layout > thead > tr > th { padding: 0; border: none; background: transparent; }
table.layout > tbody > tr > td { padding: 0; border: none; background: transparent; vertical-align: top; }
.cover { text-align: center; padding-top: 80px; min-height: 92vh; page-break-after: always;
         position: relative; z-index: 2; background: #fff; }
.cover .cover-logo { max-width: 60%; max-height: 120px; margin: 0 auto 48px; display: block; }
.cover .company { font-size: 15px; color: #2a4d69; letter-spacing: 1px; margin-bottom: 48px; font-weight: bold; }
.cover h1 { font-size: 28px; color: #2a4d69; border: none; margin: 0 0 6px; }
.cover .subtitle { font-size: 16px; color: #b45309; margin-bottom: 60px; }
.cover .doc-meta { display: inline-block; text-align: left; font-size: 13px; color: #333; line-height: 2.1; }
.cover .doc-meta b { color: #2a4d69; }
h1 { font-size: 22px; color: #2a4d69; border-bottom: 3px solid #2a4d69; padding-bottom: 6px; margin: 30px 0 4px; }
h2 { font-size: 17px; color: #2a4d69; margin-top: 26px; border-left: 4px solid #2a4d69; padding-left: 10px; }
h3 { font-size: 14.5px; color: #243b4a; margin-top: 20px; }
table.data, table.detail-table { border-collapse: collapse; width: 100%; margin: 12px 0; table-layout: fixed; }
table.data th, table.detail-table th { background: #2a4d69; color: #fff; padding: 7px 10px; text-align: left; font-size: 12px; border: 1px solid #1f3a4d; }
table.data td, table.detail-table td { border: 1px solid #c4ccd4; padding: 7px 10px; vertical-align: top; font-size: 12px; overflow-wrap: anywhere; word-break: break-word; }
table.data tr:nth-child(even) td { background: #f4f7fa; }
td.num, th.num { width: 34px; text-align: center; }
.detail-table td:first-child { width: 170px; font-weight: bold; background: #eef3f7; }
code { background: #eef1f3; border: 1px solid #dfe4e8; border-radius: 3px; padding: 1px 5px;
       font-family: Consolas, monospace; font-size: 11px; color: #b3261e; overflow-wrap: anywhere; word-break: break-word; }
.json { background: #f7f8fa; color: #1d1d1d; border: 1px solid #dfe4e8; border-radius: 6px; padding: 12px 16px;
        font-family: Consolas, monospace; font-size: 11px; white-space: pre-wrap; overflow-wrap: anywhere; }
ul, ol { margin: 6px 0 6px 24px; padding: 0; }
li { margin-bottom: 4px; }
.badge { display: inline-block; background: #e8f0fe; color: #2a4d69; border-radius: 4px; padding: 1px 8px; font-size: 11px; font-weight: bold; }
.badge-green { background: #e6f4ea; color: #1e6e34; }
.badge-orange { background: #fff3e0; color: #b45309; }
.note { background: #f4f7fa; border: 1px solid #d6dee5; border-radius: 6px; padding: 10px 14px; margin: 10px 0; }
.footer { margin-top: 40px; font-size: 10.5px; color: #888; border-top: 1px solid #ddd; padding-top: 8px; }
```

> For an **RTL language**, add a second `<style>` after the block above: `body{direction:rtl;text-align:right} h2{border-left:none;border-right:4px solid #2a4d69;padding-left:0;padding-right:10px} table.data th{text-align:right} .cover .doc-meta{text-align:right} ul,ol{margin:6px 24px 6px 0}` and set `dir="rtl"` on `<html>`.

**Branding tokens:**
- If a **logo** was supplied, put the literal token `@@LOGO@@` where the logo `<img src>` goes (cover hero + running header). Step 5 replaces it with the base64 data-URI. If **no logo** was supplied, omit the `<img>` elements entirely (do not leave `@@LOGO@@` in the output).
- If a **company name** was supplied, use it in the `.cover .company` div and the footer; otherwise omit those.

### Document skeleton

Cover (page 1) → one fixed running-header → a layout table whose empty `<thead>` reserves header space and whose `<tbody>` holds the body. (Drop the two `<img>` lines if no logo.)

```html
<body>
<div class="running-header"><img src="@@LOGO@@" alt="logo"><span class="rh-title">{title}</span></div>
<div class="cover">
  <img class="cover-logo" src="@@LOGO@@" alt="logo">
  <div class="company">{company name, if any}</div>
  <h1>Execution Summary<br>{project / interface name}</h1>
  <div class="subtitle">{task id — e.g. ADO #5492}</div>
  <div class="doc-meta">
    <b>Document version:</b> 1.0<br>
    <b>Date:</b> {YYYY-MM-DD}<br>
    <b>Source task:</b> {task id}<br>
    <b>Author:</b> {author / team}
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

Inside `<tbody><td>`, emit these sections:

1. **`1. Background & Goal`** — background & goal paragraph; a `.note` for scope caveats if relevant.
2. **`2. Executive Summary`** — `table class="data"`: `Deliverable / Action | Status | Detail`, one row each; status via `.badge-green` (Done/Running) / `.badge-orange` (Blocked/Pending).
3. **`3. What Was Done`** — one `h2`/`h3` per step describing the work and **which agent/skill/tool produced it**; use `detail-table` for per-step key/value detail.
4. **(optional) `4. Architecture`** — a short `.json` ASCII diagram if it aids understanding.
5. **`Artifacts`** — `table class="data"` of real filenames + descriptions; note where source/repos live.
6. **`Results & Links`** — commit URLs, published assets, deployed app + status, public URLs.
7. **`Open Items`** — `table class="data"` of remaining items before production / sign-off.

Add a `<div class="footer">{company name, if any} &nbsp;|&nbsp; {title} &nbsp;|&nbsp; v1.0 &nbsp;|&nbsp; {Month YYYY}</div>` at the end.

### Table conventions
- Every content table gets `class="data"` (multi-column) or `class="detail-table"` (2-column key/value). Set explicit `<th>` widths inline (`table-layout:fixed` is on). The numbering column uses `class="num"`.
- Wrap every identifier, path, filename, version, URL in `<code>`. JSON/diagrams go in `.json`.
- Status badges: Done/Running → `.badge-green`; Blocked/Pending/Proposed → `.badge-orange`.

## Step 5 — Embed the logo (if any), then render the PDF

Self-contained HTML is required for headless print (no external/relative image refs). Render with a Chromium browser — **prefer Microsoft Edge**: on some Windows setups Chrome's `--headless` exits 0 but silently writes nothing, whereas Edge (same engine/flags) works. Run this PowerShell block (substitute the paths; set `$logoSrc` to the supplied logo path, or leave empty to skip logo embedding):

```powershell
$html = "{html-output-path}"; $pdf = "{pdf-output-path}"; $logoSrc = "{logo-path-or-empty}"
if ($logoSrc -and (Test-Path $logoSrc)) {
  $ext = [IO.Path]::GetExtension($logoSrc).TrimStart('.').ToLower(); if ($ext -eq 'jpg') { $ext = 'jpeg' }
  $uri = "data:image/$ext;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($logoSrc))
  $content = [IO.File]::ReadAllText($html).Replace('@@LOGO@@', $uri)
  [IO.File]::WriteAllText($html, $content, (New-Object System.Text.UTF8Encoding($false)))
}
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
- If no logo was supplied, ensure no `@@LOGO@@` token and no logo `<img>` remain in the HTML.

## Step 6 — Confirm output

After both files are written, print:

```
Execution summary generated:
  Language: {lang}
  HTML: {html-output-path}
  PDF:  {pdf-output-path}
  Task: {task id/name}
```

Then list briefly any section left as `TBD` or any fact you could not verify, so the user can review before finalizing.

## Generation rules

- **Faithful, not invented.** Report only what actually happened — real filenames, statuses, versions, URLs, commit SHAs. Mark unknowns `TBD`; never fabricate.
- **Attribute the work.** For each step, name the agent/skill/tool that produced it (this is an execution record).
- **Never show credentials** — reference only placeholders (`${...}` / `CHANGE_ME`).
- **Self-contained HTML** — embed any logo as base64; no external/relative image refs (they don't render in headless print).
- **Brand-neutral by default** — only add a company name/logo when supplied.
