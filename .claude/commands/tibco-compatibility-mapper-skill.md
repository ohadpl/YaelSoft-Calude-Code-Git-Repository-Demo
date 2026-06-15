---
name: tibco-compatibility-mapper-skill
description: Use when a customer asks what minimum operating system or database versions are required for a list of TIBCO products they are upgrading to, or when a task asks for a TIBCO compatibility matrix, platform requirements, or supported OS/DB versions for any TIBCO product. Fetches the official README for each product from docs.tibco.com and produces a formatted 3-sheet Excel workbook (OS Requirements, Database Requirements, README Sources). Use this skill — NOT tibco-bw6-developer-agent — whenever the task is about product compatibility, upgrade prerequisites, or platform support. tibco-bw6-developer-agent is only for developing BW6 application code.
argument-hint: "<product> <version> [, <product> <version> ...] [output=<xlsx-path>]"
allowed-tools: [Read, Write, Bash, WebFetch, WebSearch]
---

# TIBCO Compatibility Mapper

Given a list of TIBCO products and versions, fetch the official README for each from docs.tibco.com, extract minimum supported OS and database versions, and output a formatted Excel workbook.

---

## Step 1 — Parse arguments

`$ARGUMENTS` contains one or more product-version pairs (comma or newline separated) and an optional output path.

**Parsing rules:**

1. If `$ARGUMENTS` contains `output=`, extract the value after `output=` as `xlsx_output_path`. Remove that token from further processing.
2. If no `output=` token is present, default to: `C:\Users\ohadp\Downloads\TIBCO_Compatibility_Matrix.xlsx`
3. Split the remaining text on commas or newlines to get individual entries.
4. For each entry, identify the product name and version. The version is the last token that matches `\d+\.\d+[\.\d]*` (e.g. `9.0.0`, `10.5.0`, `5.16.1`). Everything before it is the product name.
5. Normalize product names to lowercase for matching (e.g. `TIBCO RV` → `tibco rv`, `rv`).

If `$ARGUMENTS` is empty, tell the user:
```
Usage: /tibco-compatibility-mapper-skill <product> <version> [, <product> <version> ...]  [output=<path>]

Examples:
  /tibco-compatibility-mapper-skill TIBCO RV 9.0.0, TIBCO EMS 10.5.0, TIBCO BW 5.16.1
  /tibco-compatibility-mapper-skill TIBCO Hawk 6.3.1 output=C:\Reports\hawk_matrix.xlsx
```
Then stop.

---

## Step 2 — Resolve README URL for each product

Use this lookup table to build the primary and fallback README URLs. Match on product name keywords (case-insensitive):

| Keywords | Primary URL pattern | Fallback URL pattern |
|---|---|---|
| `rv`, `rendezvous` | `https://docs.tibco.com/pub/rendezvous/{ver}/TIB_rv_{ver}_readme.txt` | `https://docs.tibco.com/pub/rv/{ver}/TIB_rv_{ver}_readme.txt` |
| `ems`, `enterprise message` | `https://docs.tibco.com/pub/ems/{ver}/TIB_ems_{ver}_readme.txt` | `https://docs.tibco.com/pub/enterprise-message-service/{ver}/TIB_ems_{ver}_readme.txt` |
| `tra`, `runtime agent` | `https://docs.tibco.com/pub/runtime_agent/{ver}/TIB_TRA_{ver}_readme.txt` | `https://docs.tibco.com/pub/tra/{ver}/TIB_TRA_{ver}_readme.txt` |
| `bw`, `businessworks` | `https://docs.tibco.com/pub/activematrix_businessworks/{ver}/TIB_BW_{ver}_readme.txt` | `https://docs.tibco.com/pub/bw/{ver}/TIB_BW_{ver}_readme.txt` |
| `admin`, `administrator` | `https://docs.tibco.com/pub/administrator/{ver}/TIB_TIBCOAdmin_{ver}_readme.txt` | `https://docs.tibco.com/pub/tibco-administrator/{ver}/TIB_tibco-administrator_{ver}_readme.txt` |
| `adb` | `https://docs.tibco.com/pub/adadb/{ver}/TIB_adadb_{ver}_readme.txt` | `https://docs.tibco.com/pub/adb/{ver}/TIB_adb_{ver}_readme.txt` |
| `sap` | `https://docs.tibco.com/pub/adr3/{ver}/TIB_adr3_{ver}_readme.txt` | `https://docs.tibco.com/pub/sap/{ver}/TIB_sap_{ver}_readme.txt` |
| `hawk` | `https://docs.tibco.com/pub/hawk/{ver}/TIB_hawk_{ver}_readme.txt` | `https://docs.tibco.com/pub/tibco-hawk/{ver}/TIB_hawk_{ver}_readme.txt` |

For any product that does not match any keyword, attempt a WebSearch for:
`site:docs.tibco.com "{product name}" "{version}" readme.txt`
and use the first `.txt` URL found.

Replace `{ver}` with the actual version string (e.g., `9.0.0`).

---

## Step 3 — Fetch each README

For each product:
1. Fetch the **primary URL** using WebFetch.
2. If the fetch returns a 404 or empty body, fetch the **fallback URL**.
3. If both fail, record the product as `"README not found"` and continue with the next product.
4. Store: `{ product, version, readme_url_used, readme_text }`.

---

## Step 4 — Extract OS and DB requirements from each README

For each fetched README, scan for sections with headings like:
- "Supported Platforms", "Certified Platforms", "System Requirements", "Prerequisites", "Supported Operating Systems"

Within those sections, extract:

### OS — Windows
- Look for lines mentioning "Windows". Record every distinct Windows version mentioned.
- Minimum Windows Desktop: the lowest Windows desktop version listed (Windows 10 < Windows 11).
- Minimum Windows Server: the lowest Windows Server year listed (2016 < 2019 < 2022 < 2025).
- If no Windows is mentioned, record `—`.

### OS — Linux
- Look for lines mentioning "Red Hat" / "RHEL", "SUSE" / "SLES", "Oracle Linux", "Ubuntu", "Amazon Linux", "Debian".
- For each distro, record the lowest version number mentioned.
- If not mentioned, record `—`.

### Database
- **Oracle**: look for "Oracle Database", "Oracle DB", "Oracle 19c", etc. Record the lowest version.
- **SQL Server**: look for "Microsoft SQL Server", "SQL Server 2016/2017/2019/2022/2025". Record the lowest year.
- **IBM DB2**: look for "DB2", "IBM DB2". Record the lowest version.
- **MySQL / MariaDB**: record lowest version of each.
- **PostgreSQL**: record lowest version.
- **Sybase / SAP ASE**: record lowest version.
- **Other**: any other database technology mentioned (Teradata, H2, Apache Ignite, cloud databases, etc.).
- If a product has no database section (e.g. RV, EMS are messaging-only), record `—` for all DB columns and add note: `messaging only — no DB`.

### SAP adapter special case
If the product is the SAP adapter, record `—` for all database columns and instead capture the SAP system versions (e.g., "ECC 6.0, S/4HANA 2025") in the "Other" column.

---

## Step 5 — Build the Excel workbook

Use PowerShell COM automation via Bash to create the Excel file. Use the PowerShell script template below, substituting the `$data` arrays with the extracted values.

**Important:** Run this as a single PowerShell script block passed to `powershell.exe -NonInteractive -Command`. Construct the full script as a string in your reasoning, write it to a temp `.ps1` file using the Write tool, then execute it with Bash.

### PowerShell script template

```powershell
$outputPath = "XLSX_OUTPUT_PATH_HERE"

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Add()

# ── Colour constants (BGR format for Excel) ──────────────────────
$headerBg  = 0x2A5F8F   # dark blue
$headerFg  = 0xFFFFFF   # white
$subHdrBg  = 0x4472C4   # medium blue
$lightBlue = 0xDCE6F1   # alternating row
$naColor   = 0xD9D9D9   # grey for N/A cells
$greenBg   = 0xC6EFCE   # green fill
$greenFg   = 0x276221   # green font

function Style-Title($ws, $row, $cols, $text) {
    $r = $ws.Range($ws.Cells($row,1), $ws.Cells($row,$cols))
    $r.Merge()
    $r.Value2 = $text
    $r.Font.Bold = $true; $r.Font.Size = 13; $r.Font.Color = $headerBg
    $r.Interior.Color = 0xF2F2F2; $r.RowHeight = 28; $r.HorizontalAlignment = -4108
}
function Style-SectionHeader($ws, $row, $cols, $text) {
    $r = $ws.Range($ws.Cells($row,1), $ws.Cells($row,$cols))
    $r.Merge()
    $r.Value2 = $text
    $r.Interior.Color = $headerBg; $r.Font.Color = $headerFg
    $r.Font.Bold = $true; $r.Font.Size = 11; $r.HorizontalAlignment = -4108; $r.RowHeight = 20
}
function Style-ColHeaders($ws, $row, $headers) {
    for ($c=1; $c -le $headers.Count; $c++) {
        $cell = $ws.Cells($row,$c)
        $cell.Value2 = $headers[$c-1]
        $cell.Interior.Color = $subHdrBg; $cell.Font.Color = $headerFg
        $cell.Font.Bold = $true; $cell.Font.Size = 10; $cell.HorizontalAlignment = -4108
    }
    $ws.Rows($row).RowHeight = 18
}
function Style-NA($cell) {
    $cell.Interior.Color = $naColor; $cell.Font.Color = 0x595959; $cell.HorizontalAlignment = -4108
}
function Style-Green($cell) {
    $cell.Interior.Color = $greenBg; $cell.Font.Color = $greenFg
    $cell.Font.Bold = $true; $cell.HorizontalAlignment = -4108
}
function Apply-AltRow($ws, $row, $maxCol) {
    for ($c=1; $c -le $maxCol; $c++) {
        if ($ws.Cells($row,$c).Interior.Color -notin @($naColor,$greenBg)) {
            $ws.Cells($row,$c).Interior.Color = $lightBlue
        }
    }
}

# ════════════════════════════════════════════════════════════════
# DATA ARRAYS — replace with extracted values
# Format: @( @(col1,col2,...), @(col1,col2,...), ... )
# ════════════════════════════════════════════════════════════════

# OS data: #, Product, Version, MinWinDesktop, MinWinServer, MinRHEL, MinSLES, MinOL, OtherLinux, Notes
$osData = @(
    # INSERT_OS_DATA_HERE
)

# DB data: #, Product, Version, MinOracle, MinSQLServer, DB2, MySQL_MariaDB, PostgreSQL, SybaseOther
$dbData = @(
    # INSERT_DB_DATA_HERE
)

# Source data: Product, Version, README URL
$srcData = @(
    # INSERT_SRC_DATA_HERE
)

# ════════════════════════════════════════════════════════════════
# SHEET 1 — OS Requirements
# ════════════════════════════════════════════════════════════════
$ws1 = $wb.Worksheets.Item(1)
$ws1.Name = "OS Requirements"

Style-Title $ws1 1 9 "TIBCO Product Suite — Operating System Compatibility Matrix"
Style-SectionHeader $ws1 3 9 "WINDOWS SUPPORT"
Style-ColHeaders $ws1 4 @("#","Product","Version","Min Windows Desktop","Min Windows Server","Notes")

$row = 5
foreach ($d in $osData) {
    $ws1.Cells($row,1).Value2 = $d[0]
    $ws1.Cells($row,2).Value2 = $d[1]
    $ws1.Cells($row,3).Value2 = $d[2]
    $ws1.Cells($row,4).Value2 = $d[3]
    $ws1.Cells($row,5).Value2 = $d[4]
    $ws1.Cells($row,6).Value2 = $d[8]
    if ($d[3] -eq "—") { Style-NA $ws1.Cells($row,4) }
    if ($d[4] -eq "—") { Style-NA $ws1.Cells($row,5) }
    if ($row % 2 -eq 0) { Apply-AltRow $ws1 $row 6 }
    $row++
}

$linStartRow = $row + 1
Style-SectionHeader $ws1 $linStartRow 9 "LINUX SUPPORT"
Style-ColHeaders $ws1 ($linStartRow+1) @("#","Product","Version","Min RHEL","Min SLES","Min Oracle Linux","Other Linux","Notes")

$row = $linStartRow + 2
$idx = 0
foreach ($d in $osData) {
    $idx++
    $ws1.Cells($row,1).Value2 = $d[0]
    $ws1.Cells($row,2).Value2 = $d[1]
    $ws1.Cells($row,3).Value2 = $d[2]
    $ws1.Cells($row,4).Value2 = $d[5]
    $ws1.Cells($row,5).Value2 = $d[6]
    $ws1.Cells($row,6).Value2 = $d[7]
    $ws1.Cells($row,7).Value2 = $d[9]  # other linux
    $ws1.Cells($row,8).Value2 = $d[8]
    foreach ($c in @(4,5,6,7)) { if ($ws1.Cells($row,$c).Value2 -eq "—") { Style-NA $ws1.Cells($row,$c) } }
    if ($row % 2 -eq 0) { Apply-AltRow $ws1 $row 8 }
    $row++
}

$ws1.Columns("A").ColumnWidth = 4;  $ws1.Columns("B").ColumnWidth = 16
$ws1.Columns("C").ColumnWidth = 10; $ws1.Columns("D").ColumnWidth = 22
$ws1.Columns("E").ColumnWidth = 22; $ws1.Columns("F").ColumnWidth = 20
$ws1.Columns("G").ColumnWidth = 22; $ws1.Columns("H").ColumnWidth = 32
$ws1.Columns("I").ColumnWidth = 32

# ════════════════════════════════════════════════════════════════
# SHEET 2 — Database Requirements
# ════════════════════════════════════════════════════════════════
$ws2 = $wb.Worksheets.Add()
$ws2.Name = "Database Requirements"
$wb.Worksheets("Database Requirements").Move([System.Reflection.Missing]::Value, $wb.Worksheets("OS Requirements"))

Style-Title $ws2 1 9 "TIBCO Product Suite — Database Compatibility Matrix"
Style-ColHeaders $ws2 3 @("#","Product","Version","Min Oracle","Min SQL Server","DB2 / IBM","MySQL / MariaDB","PostgreSQL","Sybase / Other")

$row = 4
foreach ($d in $dbData) {
    for ($c=0; $c -lt $d.Count; $c++) {
        $ws2.Cells($row,$c+1).Value2 = $d[$c]
        if ($d[$c] -like "—*") { Style-NA $ws2.Cells($row,$c+1) }
    }
    # Green highlight for Oracle and SQL Server when supported
    if ($d[3] -ne "—") { Style-Green $ws2.Cells($row,4) }
    if ($d[4] -ne "—") { Style-Green $ws2.Cells($row,5) }
    if ($row % 2 -eq 1) {
        for ($c=1; $c -le 9; $c++) {
            if ($ws2.Cells($row,$c).Interior.Color -notin @($naColor,$greenBg)) {
                $ws2.Cells($row,$c).Interior.Color = $lightBlue
            }
        }
    }
    $row++
}

$ws2.Columns("A").ColumnWidth = 4;  $ws2.Columns("B").ColumnWidth = 16
$ws2.Columns("C").ColumnWidth = 10; $ws2.Columns("D").ColumnWidth = 16
$ws2.Columns("E").ColumnWidth = 18; $ws2.Columns("F").ColumnWidth = 28
$ws2.Columns("G").ColumnWidth = 28; $ws2.Columns("H").ColumnWidth = 16
$ws2.Columns("I").ColumnWidth = 32

# ════════════════════════════════════════════════════════════════
# SHEET 3 — README Sources
# ════════════════════════════════════════════════════════════════
$ws3 = $wb.Worksheets.Add()
$ws3.Name = "README Sources"
$wb.Worksheets("README Sources").Move([System.Reflection.Missing]::Value, $wb.Worksheets("Database Requirements"))

Style-Title $ws3 1 3 "TIBCO Product README Sources"
Style-ColHeaders $ws3 3 @("Product","Version","Official README URL")

$row = 4
foreach ($s in $srcData) {
    $ws3.Cells($row,1).Value2 = $s[0]
    $ws3.Cells($row,2).Value2 = $s[1]
    if ($s[2] -ne "README not found") {
        $ws3.Hyperlinks.Add($ws3.Cells($row,3), $s[2], "", "", $s[2]) | Out-Null
    } else {
        $ws3.Cells($row,3).Value2 = $s[2]; Style-NA $ws3.Cells($row,3)
    }
    if ($row % 2 -eq 1) { $ws3.Range("A$row:C$row").Interior.Color = $lightBlue }
    $row++
}

$ws3.Columns("A").ColumnWidth = 18; $ws3.Columns("B").ColumnWidth = 12
$ws3.Columns("C").ColumnWidth = 90

# ── Save and close ────────────────────────────────────────────
$wb.Worksheets("OS Requirements").Activate()
$wb.SaveAs($outputPath, 51)   # 51 = xlOpenXMLWorkbook
$wb.Close($false)
$excel.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
Write-Output "DONE:$outputPath"
```

---

## Step 6 — Assemble and run the script

1. Build the three data arrays (`$osData`, `$dbData`, `$srcData`) from the values extracted in Step 4. Use `—` for any field that has no data.

   **`$osData` row format** (10 fields):
   `@( "#", "ProductName", "Version", "MinWinDesktop", "MinWinServer", "MinRHEL", "MinSLES", "MinOracleLinux", "Notes", "OtherLinux" )`

   **`$dbData` row format** (9 fields):
   `@( "#", "ProductName", "Version", "MinOracle", "MinSQLServer", "DB2", "MySQL/MariaDB", "PostgreSQL", "SybaseOther" )`

   **`$srcData` row format** (3 fields):
   `@( "ProductName", "Version", "ReadmeURL" )`

2. Write the complete PowerShell script (with data substituted) to:
   `$env:TEMP\tibco_matrix_builder.ps1`
   Use the Write tool for this.

3. Execute via Bash:
   ```
   powershell.exe -NonInteractive -ExecutionPolicy Bypass -File "$env:TEMP\tibco_matrix_builder.ps1"
   ```

4. Check that the output contains `DONE:` — if not, report the PowerShell error to the user.

5. Delete the temp script file after successful execution.

---

## Step 7 — Confirm output

After the Excel file is created, print:

```
TIBCO Compatibility Matrix generated:
  Products: {N} products processed
  Output:   {xlsx_output_path}

Sheets:
  • OS Requirements    — Windows and Linux minimum versions
  • Database Requirements — Oracle, SQL Server, and other DB minimums
  • README Sources     — clickable links to each official TIBCO README
```

If any product's README was not found, list them explicitly with a note:
```
⚠ README not found for:
  - {ProductName} {Version} — add manually or check https://docs.tibco.com/pub/
```

---

## Generation rules

- Always use `—` (em dash) for unsupported/not-applicable fields, not `N/A` or blank.
- Record the **minimum** (lowest/oldest) version found in the README, not the latest.
- For Windows Server, the ordering is: 2016 < 2019 < 2022 < 2025.
- For RHEL, the ordering is: 6.x < 7.x < 8.x < 9.x < 10.x.
- If a README lists "8.x, 9.x" for RHEL, the minimum is `8.x`.
- If a README lists only desktop Windows (no Server), record `—` for Min Windows Server.
- Never guess or hallucinate version numbers — only record what is explicitly stated in the fetched README text.
- If you cannot determine a value with certainty from the README, record `—` and add a note.
