---
description: Convert an English MuleSoft technical specification (produced by the create-mulesoft-technical-spec-doc skill) into a Hebrew (RTL) corporate technical specification document, in either ETL format or API format. Produces a styled HTML and a headless-rendered PDF that match the Shikun & Binui corporate template, with the company logo on the cover and a running header on every page.
argument-hint: [path-to-tech-spec-doc] [etl|api]
allowed-tools: [Read, Glob, Grep, Write, Bash]
---

# SB Technical Specification Document Generator

Convert a **source technical specification** — the English HTML/PDF produced by the `create-mulesoft-technical-spec-doc` skill — into a **Hebrew, right-to-left corporate technical specification document**, in one of two shapes:

- **ETL format** — a scheduled batch / ETL integration (incremental sync, source→target field mappings). Template modeled on `שיכון ובינוי - רישום נכסים`.
- **API format** — request-driven REST interfaces exposed via API Gateway. Template modeled on `שיכון ובינוי - אפיון ממשק זיגיט`.

The output is always Hebrew RTL prose with English technical identifiers (field names, entity names, connectors, URLs, JSON keys), and is rendered to both HTML and PDF using the same Chrome-headless pipeline as `create-mulesoft-technical-spec-doc`.

---

## Step 1 — Resolve the source document

1. If `$ARGUMENTS` contains a file path, use it. **Otherwise ask the user:**
   > "What is the path to the technical specification document (the one produced by the `create-mulesoft-technical-spec-doc` skill)?"
   Wait for the answer before continuing.

2. **Prefer the HTML over the PDF.** The `create-mulesoft-technical-spec-doc` skill always writes a matched pair `{Name}_Technical_Specification.html` + `{Name}_Technical_Specification.pdf` in the same folder. The HTML is far easier and more reliable to parse.
   - If the user gives a `.pdf`, look in the same folder (Glob) for the sibling `.html` with the same base name and read that instead.
   - If only a `.pdf` exists, extract its text with the bundled Poppler tool, then read the text file:
     ```
     & "C:\Users\ohadp\AppData\Local\Programs\Git\mingw64\bin\pdftotext.exe" -enc UTF-8 -layout "{pdf-path}" "{temp-txt-path}"
     ```
     (The `Read` tool cannot render PDFs in this environment — `pdftoppm` is unavailable — so always go through HTML or `pdftotext`.)

3. Read the full source document and extract everything the `create-mulesoft-technical-spec-doc` template produced: project name & Maven coordinates, runtime/port, connector dependencies, global configurations, every flow (trigger, ordered processing steps, responses), configuration properties, error-handling strategy, logging convention, external API reference, DataWeave transformations, sample requests/responses, and any design assumptions.

State the resolved source path before proceeding.

## Step 2 — Choose the target format (ETL or API)

If `$ARGUMENTS` already says `etl` or `api`, use it. **Otherwise ask the user:**
> "Should the document be generated in **ETL** format or **API** format?"

Wait for the answer. If the choice is unclear from the source, recommend one based on the source's triggers — a `scheduler`-triggered flow that bulk-reads a source and writes a target ⇒ **ETL**; an `http:listener`-triggered flow that exposes endpoints ⇒ **API** — but let the user decide.

State the chosen format before proceeding.

## Step 3 — Map the source content onto the chosen template

You are **re-shaping and translating**, not inventing. Every fact comes from the source spec; you translate the prose to Hebrew and arrange it into the corporate section structure below. Where the corporate template needs a detail the source did not state, make a reasonable, clearly-reasonable engineering inference consistent with the source (do not stall), and keep it consistent with the rest of the document.

**Translation rules (apply to both formats):**
- All section titles, table headers, descriptions, logic steps, and notes are written in **Hebrew**.
- **Keep in English (Latin):** field/column names, entity/object names, connector names, property keys, HTTP methods, URLs, JSON keys and JSON example bodies, DataWeave code, status/enum literal values (`Approved`, `Allowed`, `New`, etc.), and Maven coordinates.
- Use the system names as the source uses them; refer to the integration platform as `MuleSoft` / `ML`.
- Numbers, dates: use day-month-year and Hebrew month context where prose; keep ISO timestamps in examples as-is.

### 3A — Source → ETL template mapping

| ETL section | Fill from the source spec |
|---|---|
| Cover — interface name | Project / integration display name. Title: `אפיון ממשק ל{name}` |
| 1.1 מטרת המסמך | Business goal / overview paragraph |
| 1.2 מסמכים קשורים | "מסמך אפיון על עסקי", "מסמך אפיון מפורט עסקי", "אפיון טיוטת ארכיטקטורה" (standard list; adjust if the source names specific docs) |
| 2 דרישה | One-line "כללי" goal + bullet "מאפייני על": יזום פעילות (who initiates), סוג העברה (incremental/full), לוגיקת העברה (add/update detection), תדירות (from the scheduler expression) |
| 3.1 ארכיטקטורת הממשק | State it is an `ETL` interface: Bulk read from source, scheduled Batch run, incremental sync (timestamp/since-last-run). Derive cadence from the scheduler config |
| 3.2 הערכת נפח פעילות | Volumes from the source if stated; otherwise note as an open figure to confirm |
| 3.3 מודל הנתונים | Source-system and target-system entity model implied by the flows/mappings |
| 3.4 הנחיות כלליות | Table `# \| נושא \| פירוט`: environments, install notes, failure reporting (log + email) — from the source's error-handling/logging sections |
| 3.5 פרמטרי מערכת | Table `# \| פרמטר \| סוג \| תאור`: each configuration property → a row. Mark type `YAML` for config-file props, `ObjectStore` for run-state (e.g. last-run timestamp) |
| 4.1 לוגיקת תהליך MuleSoft | Table `# \| שלב בתהליך \| פירוט`: the main batch flow's ordered processing steps (init, fetch list, per-record processing, entity linking, save results, general guidelines) + per-step "טיפול בכשלים" (retry counts, stop-on-fail) from the error handlers |
| 4.2 … 4.N (one per sub-interface) | Each external interaction in the flows → one numbered interface. For each: a `# \| נושא \| פירוט` table with rows **1.שם ממשק 2.תאור כללי 3.מקור** (for reads) **/ יעד** (for writes) **4.לוגיקת הממשק 5.מפרט גישה 6.קלט 7.פלט**. For HTTP reads use the External API Reference (Base URL, method, query/path params, full example URL). For Salesforce/DB ops, give entity + operation (`insert`/`update`/`upsert`/query) and key fields. Output: status values + result JSON structure with a short example |
| 5 מיפוי שדות | One sub-section per entity. Wide table — **מערכת מקור (ריינבו/source): טבלה \| שדה \| שדה (עברית)** ‖ **מערכת יעד (SF/target): ישות \| שדה \| DataType** ‖ **הערות**. Source the rows from the DataWeave transformations and any field-mapping detail in the source spec. Include Lookup/Reference notes where the transform resolves a related record |

### 3B — Source → API template mapping

| API section | Fill from the source spec |
|---|---|
| Cover — interface name | Project / integration display name. Title: `אפיון ממשק {name}` |
| 1.1 (context) | One paragraph: what the calling system is and what it needs from the platform |
| 1.2 מטרת המסמך | What interfaces this document defines |
| 1.3 מסמכים נלווים | Related docs list (adjust to any named in the source) |
| 2 דרישה | "כללי" goal + "מאפייני על" bullets (payload shape, attachment limits, identification rule, etc. where stated) |
| 3.1–3.3 עקרונות מימוש | Relationship principles between the caller and the platform; that REST interfaces are exposed via `MuleSoft Flex Gateway` (API Gateway) and ML performs the work against the target (e.g. `SF`). Include an existing-state subsection only if the source describes one |
| 3.4 שמירת … ב-SF | How records are stored in the target (entity type, record types, linked entities, file storage) — where the source describes it |
| 4.1 ארכיטקטורת הממשקים | Principles + an **interface list table** `# \| שם ממשק \| מקור \| יעד \| תאור`, one row per exposed endpoint / sub-interface |
| 4.X (one chapter per main interface) | For each `http:listener` flow create a chapter with sub-sections: |
| · 4.X.1 לוגיקת תהליך ML | Table `# \| שלב בתהליך \| פירוט`: ordered processing steps of the flow + "טיפול בכשלים" (technical retry ×N, applicative stop) + logging notes |
| · 4.X.2 ממשק POST/GET ל… | Table `# \| נושא \| פירוט` with rows **1.שם ממשק 2.תאור כללי 3.מקור 4.יעד 5.מפרט גישה** (Type `HTTP POST`/`GET`, Host=config param, Port=config param, Base URL, relative URL/path, auth header) **6.קלט** (JSON body structure + UTF-8) **7.לוגיקת הממשק** (gateway checks: api-key header, CORS, schema validation; then ML logic) **8.פלט** |
| · 4.X.3 … מול SF | The target-side logic: input/output JSON examples; an **input-fields table** `# \| שדה \| סוג \| חובה \| תאור`; an **output/mapping table** `# \| שדה בממשק \| שדה SF \| סוג \| חובה \| תאור`; plus validation rules and any sub-interface sections (file scan/download, attachment, etc.) where present in the source |

If the source has only one HTTP flow, produce one 4.X chapter. If it has several, produce one chapter each, numbered 4.2, 4.3, …

## Step 4 — Determine output filenames

Reuse the source's display name. Outputs go **in the same folder as the source document**:
- HTML: `{out-dir}/{DisplayName}_Tech_Spec_{ETL|API}_HE.html`
- PDF:  `{out-dir}/{DisplayName}_Tech_Spec_{ETL|API}_HE.pdf`

## Step 5 — Generate the Hebrew HTML

Write a complete `<!DOCTYPE html>` document with `<html lang="he" dir="rtl">`. Use **exactly** this CSS inside `<style>` (it reproduces the corporate RTL look — navy headings, bordered tables, a cover page, and a contents list):

```css
@page { size: A4; margin: 16mm 18mm 16mm; }
* { box-sizing: border-box; }
body { font-family: 'David Libre','David','Times New Roman',Arial,sans-serif; direction: rtl; text-align: right;
       font-size: 13px; color: #1d1d1d; line-height: 1.75; margin: 0; }
.page-break { page-break-before: always; }

/* Running header logo — position:fixed repeats on EVERY page and (unlike a thead <img>) actually paints.
   It is hidden on the cover by the cover's opaque, higher z-index background. */
.running-header { position: fixed; top: 0; left: 0; right: 0; height: 11mm; z-index: 1;
                 border-bottom: 1.5px solid #c9d3db; padding-bottom: 4px; text-align: left; }
.running-header img { height: 9mm; }
.header-spacer { height: 15mm; }   /* empty thead spacer reserves room at the top of every table page */

/* Layout table — its empty <thead> repeats the spacer on every page so body text never slides under the fixed header */
table.layout { width: 100%; border-collapse: collapse; }
table.layout > thead > tr > th { padding: 0; border: none; background: transparent; }
table.layout > tbody > tr > td { padding: 0; border: none; background: transparent; vertical-align: top; }

/* Cover — opaque white + z-index:2 so it hides the fixed running header on page 1 only */
.cover { text-align: center; padding-top: 70px; min-height: 92vh; page-break-after: always;
         position: relative; z-index: 2; background: #fff; }
.cover .cover-logo { width: 340px; max-width: 72%; margin: 0 auto 54px; display: block; }
.cover .company { font-size: 15px; color: #14506b; letter-spacing: 1px; margin-bottom: 56px; font-weight: bold; }
.cover h1 { font-size: 30px; color: #14506b; border: none; margin: 0 0 6px; }
.cover .subtitle { font-size: 16px; color: #b45309; margin-bottom: 64px; }
.cover .doc-meta { display: inline-block; text-align: right; font-size: 13px; color: #333; line-height: 2.1; }
.cover .doc-meta b { color: #14506b; }

/* Headings */
h1 { font-size: 22px; color: #14506b; border-bottom: 3px solid #14506b; padding-bottom: 6px; margin: 30px 0 4px; }
h2 { font-size: 17px; color: #14506b; margin-top: 26px; border-right: 4px solid #14506b; padding-right: 10px; }
h3 { font-size: 14.5px; color: #1f3a4d; margin-top: 20px; }
h4 { font-size: 13.5px; color: #333; margin-top: 16px; }

/* Content tables — table-layout:fixed + explicit column widths so wide Hebrew/code content WRAPS instead of
   overflowing the page. Always give every content table class="data" (or "detail-table" for 2-col interface tables). */
table.data, table.detail-table { border-collapse: collapse; width: 100%; margin: 12px 0; direction: rtl; table-layout: fixed; }
table.data th, table.detail-table th { background: #14506b; color: #fff; padding: 7px 10px; text-align: right; font-size: 12px; border: 1px solid #0e3d52; }
table.data td, table.detail-table td { border: 1px solid #c4ccd4; padding: 7px 10px; vertical-align: top; font-size: 12px; overflow-wrap: anywhere; word-break: break-word; }
table.data tr:nth-child(even) td { background: #f3f7fa; }
td.num, th.num { width: 34px; text-align: center; }
.detail-table td:first-child { width: 150px; font-weight: bold; background: #eef3f7; }

/* Inline code / blocks — kept LTR for technical content; wrap so long URLs/identifiers never overflow in print */
code { direction: ltr; unicode-bidi: embed; background: #eef1f3; border: 1px solid #dfe4e8; border-radius: 3px;
       padding: 1px 5px; font-family: Consolas, monospace; font-size: 11px; color: #b3261e;
       overflow-wrap: anywhere; word-break: break-word; }
pre { direction: ltr; text-align: left; background: #1e1e1e; color: #d4d4d4; border-radius: 6px; padding: 14px 18px;
      font-family: Consolas, monospace; font-size: 11px; line-height: 1.5; white-space: pre-wrap; overflow-wrap: anywhere; }
.json { direction: ltr; text-align: left; background: #f7f8fa; color: #1d1d1d; border: 1px solid #dfe4e8;
        border-radius: 6px; padding: 12px 16px; font-family: Consolas, monospace; font-size: 11px;
        white-space: pre-wrap; overflow-wrap: anywhere; }

/* Contents */
.toc { font-size: 13px; }
.toc div { padding: 3px 0; border-bottom: 1px dotted #cfd6dd; }
.toc .l1 { font-weight: bold; color: #14506b; }
.toc .l2 { padding-right: 22px; }
.toc .l3 { padding-right: 44px; color: #555; }

/* Lists */
ul, ol { margin: 6px 24px 6px 0; padding: 0; }
li { margin-bottom: 4px; }

.badge { display: inline-block; background: #e8f0fe; color: #14506b; border-radius: 4px; padding: 1px 8px; font-size: 11px; font-weight: bold; }
.badge-orange { background: #fff3e0; color: #b45309; }
.note { background: #f3f7fa; border: 1px solid #d6dee5; border-radius: 6px; padding: 10px 14px; margin: 10px 0; }
.footer { margin-top: 40px; font-size: 10.5px; color: #888; border-top: 1px solid #ddd; padding-top: 8px; }
```

**Logo:** put the literal token `@@LOGO@@` wherever the logo image source is needed (the cover hero `<img>` and the running-header `<img>`); Step 6 replaces every `@@LOGO@@` with the base64 data-URI before rendering. Do **not** paste the base64 into the HTML yourself.

### Document skeleton (both formats share the front matter)

The overall structure is: **cover (page 1)** → a single **fixed running-header** element → a **layout table** whose empty `<thead>` reserves the header space and whose `<tbody>` holds all the front matter + body sections. This ordering is what makes the logo appear large on the cover and small at the top of every following page.

```html
<body>

<!-- Running header: repeats on every page; hidden on the cover by the cover's opaque background -->
<div class="running-header"><img src="@@LOGO@@" alt="שיכון ובינוי"></div>

<!-- COVER (page 1) -->
<div class="cover">
  <img class="cover-logo" src="@@LOGO@@" alt="שיכון ובינוי">
  <div class="company">שיכון ובינוי</div>
  <h1>{כותרת המסמך}</h1>
  <div class="subtitle">- טיוטה לאישור -</div>
  <div class="doc-meta">
    <b>גרסת מסמך:</b> 0.1<br>
    <b>תאריך גרסה:</b> {DD/MM/YYYY}<br>
    <b>שם הקובץ:</b> {שם הקובץ}<br>
    <b>מחבר מסמך:</b> {מחבר / ריק}
  </div>
</div>

<!-- BODY: empty thead spacer reserves top room for the fixed header on every page -->
<table class="layout">
<thead><tr><th><div class="header-spacer"></div></th></tr></thead>
<tbody><tr><td>

  ... front matter + all body sections go here ...

</td></tr></tbody>
</table>
</body>
```

Inside the `<tbody><td>`, emit in order:

1. **ניהול גרסאות מסמך** — `table class="data"` `# | תאריך | מבצע | גרסה | תאור`, one seed row (`1 | {today} | {author} | 0.1 | טיוטה ראשונה`).
2. **סקירה ואישורים** — `table class="data"` `# | שם ותפקיד | תהליך | סקירה ואישורים | חתימה | תאריך`, two empty rows.
3. **תוכן עניינים** — a `.toc` block listing every section/sub-section you will generate (l1/l2/l3). Build it from the actual sections.
4. **משימות והערות** — `table class="data"` `# | משימה | תאריך לביצוע | אחראי | תאריך ביצוע | מיקום`, a few empty rows.
5. `<div class="page-break"></div>` then the **body sections** per Step 3A (ETL) or 3B (API).
6. **Footer** at the end: `<div class="footer">שיכון ובינוי &nbsp;|&nbsp; {כותרת} &nbsp;|&nbsp; גרסה 0.1 &nbsp;|&nbsp; {Month YYYY}</div>`

Use `שיכון ובינוי` as the company name unless the source indicates another; derive the document title from the integration name.

### Table-building conventions
- **Every content table gets `class="data"`** (multi-column) or **`class="detail-table"`** (the 2-column interface tables). Plain `<table>` is unstyled — never use it. Do not put `class="data"` on the outer `table.layout`.
- Because `table-layout: fixed` is used, **set explicit column widths** with inline `style="width:NN%"` on the `<th>` cells of any table whose cells carry long text or `<code>` (otherwise columns split equally). Proven widths:
  - 3-col `# | נושא/שלב | פירוט`: num (class) · 22% · 73%
  - 4-col `# | פרמטר | סוג | תאור`: num · 24% · 12% · 58%
  - 7-col field-mapping `# | טבלה | שדה | ישות | שדה | DataType | הערות`: num · 13% · 16% · 13% · 16% · 11% · 26%
- The "#"/numbering column is the **right-most** column (first `<th>`/`<td>` in RTL source order). Give it `class="num"`.
- For per-interface detail tables (ETL 4.2+, API 4.X.2) use the 2-column **`detail-table`**: right column = topic (`נושא`), left = detail (`פירוט`). Number rows 1..7/8 inside the topic cell.
- JSON / DataWeave / example URLs go in `<pre>` (dark) or `<div class="json">` (light) — always LTR; they wrap automatically.
- Wrap every English identifier in `<code>`.
- Skip any section for which the source genuinely has no content; note real gaps in a `.note` block ("לאישור" / "להשלמה").

## Step 6 — Embed the logo, then render the PDF

The corporate logo is stored as a skill asset; embed it as a base64 data-URI (self-contained HTML is required — external/relative image refs do not render in headless print). Then render with a Chromium browser.

Run this single PowerShell block (substitute the three `{...}` paths). It (1) loads the logo data-URI, regenerating it from the PNG if the sidecar is missing; (2) replaces every `@@LOGO@@` in the generated HTML; (3) renders with **Microsoft Edge** — on this machine Chrome 139's `--headless` exits 0 but silently writes nothing, whereas Edge (same engine/flags) works; (4) verifies the PDF exists.

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
# Every path argument MUST be double-quoted — the output folder name often has a space,
# which otherwise becomes "Multiple targets are not supported in headless mode".
$argline = "--headless=new --disable-gpu --user-data-dir=`"$tmp`" --print-to-pdf=`"$pdf`" --no-pdf-header-footer --run-all-compositor-stages-before-draw `"$html`""
Start-Process -FilePath $exe -ArgumentList $argline -Wait
Start-Sleep -Seconds 2
if (Test-Path $pdf) { Get-Item $pdf | Select-Object Name, Length } else { Write-Output "PDF NOT WRITTEN — is it open/locked in a viewer? Close it and retry." }
```

Notes:
- If the PDF does not update, it is almost always **locked open in a PDF viewer** — render to a new filename or ask the user to close it. A 0 exit code does **not** guarantee the file was written; always `Test-Path`.
- The logo asset lives at `C:\Users\ohadp\.claude\commands\assets\sb-logo.png` (with a cached `sb-logo.b64.txt`). If it is ever missing, ask the user for the logo file and copy it there.
- To visually verify a specific page during development, rasterize it with the bundled helper (Windows PowerShell 5.1 + the `Windows.Data.Pdf` API):
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\ohadp\.claude\commands\assets\render-pdf-page.ps1" -Pdf "{pdf}" -Page {0-based} -Out "{png}"`

## Step 7 — Confirm output to the user

After both files are written, print:

```
מסמך אפיון טכני נוצר:
  פורמט: {ETL | API}
  שפה: עברית (RTL)
  HTML: {html-output-path}
  PDF:  {pdf-output-path}
  מקור: {source-spec-path}
```

Then list briefly, in your reply, any places where you inferred a detail the source did not state, or any section left as "להשלמה / לאישור", so the user can review before the document is finalized.

## Generation rules

- **Faithful conversion, not invention.** Re-shape and translate what the source spec says. Do not fabricate business rules, field mappings, volumes, or endpoints that the source does not support.
- **Hebrew prose, English identifiers** — per the translation rules in Step 3.
- **Never show credentials** — reference only property placeholders (e.g. `${salesforce.password}`).
- **ETL vs API shape is mandatory** — an ETL document must center on the scheduled batch process + field-mapping chapter; an API document must center on per-endpoint chapters (ML logic + interface spec + target-side logic). Do not mix the two structures.
- Keep JSON/DataWeave/URL blocks LTR and copy values verbatim from the source.
