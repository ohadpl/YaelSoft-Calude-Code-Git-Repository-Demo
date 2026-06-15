---
description: Read a specification document and generate integration/flow test scenarios as a CSV file (Excel / Google Sheets compatible).
argument-hint: <spec-path> [output-csv-path]
allowed-tools: [Read, Write, Bash]
---

Generate test scenarios from a specification document and save them as a CSV file.

## Step 1: Parse arguments

`$ARGUMENTS` contains one or two paths separated by a space.

- `spec_path` = the first path token in `$ARGUMENTS`
- `output_path` = the second path token if present. If absent, derive it from `spec_path`: take the full path, strip the file extension, append `_TestScenarios.csv`. Example: `C:\specs\MyApp.pdf` → `C:\specs\MyApp_TestScenarios.csv`

If `$ARGUMENTS` is empty, tell the user: "Usage: /write-test-scenarios <spec-path> [output-csv-path]" and stop.

## Step 2: Read the specification document

Detect the file extension of `spec_path` and read it as follows:

- **`.pdf`** — Use the Read tool. For PDFs longer than 20 pages, read in chunks of 20 pages at a time until the entire document is read. Pass `pages: "1-20"`, then `"21-40"`, etc.
- **`.md`, `.txt`, `.html`, `.xml`, `.json`** — Use the Read tool directly.
- **`.docx`** — Use Bash with PowerShell to extract the text:
  ```powershell
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $doc = $word.Documents.Open("SPEC_PATH_HERE")
  $text = $doc.Content.Text
  $doc.Close($false)
  $word.Quit()
  $text
  ```
  If this fails (no Word installed), tell the user: "Word is not available. Please export the document to PDF or plain text and re-run the command."

Read the **entire document** before proceeding to analysis.

## Step 3: Analyse the specification

Carefully read the full document content. Extract and internally record:

| Category | What to look for |
|---|---|
| **System / app name** | Title page, document header, or first H1 heading |
| **Features and modules** | Top-level sections, numbered features, bullet lists of capabilities |
| **Flows and processes** | Any described workflow, sequence of steps, or process description |
| **API endpoints / triggers** | URL paths, HTTP methods, trigger events, queue names |
| **Inputs** | Request parameters, query strings, request bodies, form fields, file formats |
| **Outputs** | Response bodies, status codes, written files, database records, messages sent |
| **Business rules** | Conditions ("if X then Y"), validations ("must be", "required"), calculations, data transformations |
| **Integration points** | External systems, third-party APIs, databases, message queues, connectors |
| **Error and exception conditions** | "if X fails", "when invalid", "in case of error", "exception", "fault" language |
| **Pre-conditions and setup** | "requires", "assumes", "must be configured", "before running" language |

## Step 4: Generate test scenarios

For **each** identified feature, flow, endpoint, and error condition, produce one or more test scenarios. Cover:

1. **Happy path** — the main flow succeeds end-to-end with valid, representative data
2. **Each integration point** — the external call completes successfully and the result is used correctly
3. **Each error condition** — the described error is triggered and handled as specified
4. **Business rule validation** — each stated rule is exercised (valid case + at least one violation where the spec describes one)
5. **Data transformation** — output matches spec for each described mapping/transformation

For every scenario assign:
- A sequential **Test ID**: `TC-001`, `TC-002`, … (zero-padded to 3 digits, globally sequential across all suites)
- A **Test Suite** name based on the feature/flow/section it belongs to (e.g., `Order Processing`, `Authentication`, `Error Handling`, `SMS Sending`)
- A **Priority**: `High` for core flows and critical error paths; `Medium` for business rules and integrations; `Low` for edge cases and non-critical paths

## Step 5: Write the CSV file

Construct a CSV string with **exactly 10 columns**. The first row must be this header line:

```
Test ID,Test Suite,Test Name,Description,Pre-conditions,Test Steps,Input Data,Expected Result,Expected Status,Priority
```

**Column definitions:**

| Column | Rules |
|---|---|
| **Test ID** | `TC-001` through `TC-NNN` |
| **Test Suite** | Short feature/flow name; consistent within a group |
| **Test Name** | Concise title, max 80 characters |
| **Description** | One sentence: what behaviour is being verified |
| **Pre-conditions** | Semicolon-separated setup items (e.g., `Service is running; Test database is seeded`) — write `None` if no pre-conditions |
| **Test Steps** | Numbered steps separated by ` \| ` (e.g., `1. Send GET /api/orders?date=2026-01-01 \| 2. Receive HTTP response \| 3. Verify response body contains order list`) |
| **Input Data** | Concrete key=value pairs separated by `;` (e.g., `method=GET; path=/api/orders; date=2026-01-01`). Use realistic sample values. |
| **Expected Result** | Full English sentence describing what the system must do or return. For integrations, name the downstream system. |
| **Expected Status** | HTTP status code (e.g., `200`, `400`, `500`), a domain outcome code, or `N/A` for non-HTTP |
| **Priority** | `High`, `Medium`, or `Low` |

**CSV escaping rules:**
- Any field that contains a comma, double-quote, or newline MUST be wrapped in double-quotes
- Any double-quote character inside a quoted field must be escaped as `""`
- All other fields may be unquoted

Use the **Write tool** to save the CSV to `output_path`. Do not use Bash for the file write.

## Step 6: Confirm to user

After writing the file, print exactly:

```
Test scenarios generated: {N} scenarios across {M} test suites
Output: {output_path}

Open in Excel:         double-click the file, or use File → Open → browse to the CSV
Import to Google Sheets: File → Import → Upload → select the CSV file
```

Replace `{N}` with the total number of data rows, `{M}` with the number of distinct Test Suite values.

---

## Generation rules

- Every row must trace back to a specific section or statement in the spec — do not invent requirements not described in the document
- Aim for **complete coverage**: every described feature, endpoint, flow, business rule, and error condition must have at least one scenario
- Test Steps must be written in plain imperative language that a human tester can follow without technical knowledge of the implementation
- Input Data must contain concrete, realistic sample values — not just field name placeholders
- For integration scenarios, Expected Result must name the downstream system and describe what it should receive or return
- If the spec is ambiguous on a point, write the scenario based on the most reasonable interpretation and append `(spec ambiguous — verify with author)` to the Description field
- Prioritise breadth over depth: better to cover every area with one scenario each than to generate many scenarios for one area and miss others
