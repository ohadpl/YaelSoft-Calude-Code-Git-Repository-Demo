# sb-landowner-sync

Shikun & Binui — **Land Owners Sync from Rainbow (OData) to Salesforce** (ADO task 5469).

A nightly, scheduler-driven batch that synchronises land-rights owners from the
Rainbow system (OData) into the Salesforce custom object `LandOwner__c` as **flat
records** (no Account creation, no Project creation — upsert only).

---

## Project coordinates

| Property | Value |
|---|---|
| groupId | `com.shikunbinui.integration` |
| artifactId | `sb-landowner-sync` |
| version | `1.0.0` |
| packaging | `mule-application` |
| Mule runtime | 4.6.x |
| Java | 17 |
| HTTP port | 8081 (health/ops only — no public API) |

### Toolchain on this machine
- Maven: `C:\maven\apache-maven-3.9.9\bin\mvn.cmd`
- JDK 17 (from Studio bundle): `C:\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1`
- Build with: set `JAVA_HOME` to the JDK above, then `mvn clean package`.

---

## Connectors

| Connector | groupId | version |
|---|---|---|
| `mule-http-connector` | `org.mule.connectors` | 1.10.6 |
| `mule-sockets-connector` | `org.mule.connectors` | 1.2.5 |
| `mule-salesforce-connector` | `com.mulesoft.connectors` | 11.4.0 |
| `mule-secure-configuration-property-module` | `com.mulesoft.modules` | 1.2.7 |

---

## File layout

```
src/main/mule/
  global-config.xml      - secure props, HTTP request configs, Salesforce config, health listener
  error-handling.xml     - global-error-handler (referenced by every flow)
  landowner-sync.xml     - all flows + sub-flows + health flow
src/main/resources/
  config.yaml            - non-secure properties
  secure-config.yaml     - secure properties (rainbow.password, salesforce.password, salesforce.securityToken)
  log4j2.xml             - RollingFile -> sb-landowner-sync.log (10 MB x 10)
  dwl/
    map-registrations.dwl   - registration -> slim shape
    build-landowner.dwl     - registration + owner + business partner -> flat LandOwner__c
    add-building-lookup.dwl  - conditional Building__r external-id relationship
src/test/munit/
  landowner-sync-test.xml  - MUnit suite (happy/error/branch per flow)
src/test/resources/log4j2-test.xml
```

---

## Flows (spec section 4)

1. **landowner-sync-scheduler-flow** — Scheduler (`${sync.cron}`, default `0 0 2 * * ?`, Asia/Jerusalem):
   log start → `delete-stale-landowners-subflow` → `fetch-registrations-subflow` →
   foreach registration → `build-landowners-for-registration-subflow` (accumulate) →
   filter empties → `upsert-landowners-subflow` → log summary.
2. **delete-stale-landowners-subflow** — query stale ids, choice-guard, delete.
3. **fetch-registrations-subflow** — GET `/registrations?$filter=isCurrentRegistration eq true`,
   follow `@odata.nextLink` paging, map to slim shape.
4. **build-landowners-for-registration-subflow** — GET `/owners?...`, skip if none, enrich each
   owner via `/businessPartners?...`, build flat records, add conditional Building lookup.
5. **upsert-landowners-subflow** — chunk by `${salesforce.batchSize}` (200), upsert on
   `External_Key__c`, collect results, log per-record failures.
6. **health-flow** — GET `/health` → 200 `OK`.

---

## Confirmed decisions (override anything ambiguous in the spec)

1. **Purge**: `ToDate__c` on `LandOwner__c` is mapped from `owners.toDate`. At the start of each run,
   delete `LandOwner__c` WHERE `ToDate__c < TODAY AND Lawyer__c = null`. Records with empty
   `ToDate__c` are never deleted; records with `Lawyer__c` filled (manually managed) are never deleted.
2. **Upsert key**: `External_Key__c` = the Rainbow owner record id (`owner.id`) as String.
3. **Rainbow auth**: HTTP Basic (`rainbow.username` / `rainbow.password` secure).
4. **`Project__c`** is a LOOKUP, written via external-id relationship
   `Project__r.Project_Code__c` = Rainbow `project_code`. Never write `Project__c` directly.

Other rules: tolerate missing ID numbers (ת.ז / ח.פ); filter out registrations with zero owners;
conditional `Building__r.BuildingCode__c` only when `buildingCode` present.

---

## Configuration properties (`config.yaml`)

| Key | Default | Secure? |
|---|---|---|
| `http.port` | 8081 | |
| `sync.cron` | `0 0 2 * * ?` | |
| `rainbow.analytics.host` | ziv-rainbow.net | |
| `rainbow.operation.host` | ziv-rainbow.net | |
| `rainbow.username` | CHANGE_ME | |
| `rainbow.password` | CHANGE_ME | **secure** |
| `rainbow.timeout.ms` | 30000 | |
| `salesforce.username` | CHANGE_ME | |
| `salesforce.password` | CHANGE_ME | **secure** |
| `salesforce.securityToken` | CHANGE_ME | **secure** |
| `salesforce.apiVersion` | 59.0 | |
| `salesforce.batchSize` | 200 | |

### Secrets
Secure values live in `secure-config.yaml` and are read via `${secure::<key>}`. They must be
**encrypted** with the Anypoint Studio "Mule Secure Properties Tool" (AES/CBC) before deployment,
and the runtime started with `-Dsecure.key=<aesKey>`. The committed `CHANGE_ME` placeholders are
NOT real secrets.

---

## Error handling (spec section 6)

| Error | Scope | Behaviour |
|---|---|---|
| `HTTP:CONNECTIVITY` / `HTTP:TIMEOUT` (Rainbow) | On Error Continue (per registration) | retry 3× w/ backoff, log failing `registrationKey`, continue |
| `SALESFORCE:CONNECTIVITY` | On Error Propagate (global) | abort run, log ERROR (next run retries — upsert is idempotent) |
| `SALESFORCE:INVALID_FIELD` / item failures | On Error Continue (upsert) | log per-record `External_Key__c`, keep going |
| ANY (uncaught) | Global default handler | log full error + correlationId at ERROR |

---

## Build & run

```powershell
$env:JAVA_HOME = "C:\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1"
& "C:\maven\apache-maven-3.9.9\bin\mvn.cmd" clean package          # full build incl. MUnit
& "C:\maven\apache-maven-3.9.9\bin\mvn.cmd" clean package -DskipTests   # skip MUnit
```

> Knowledge Hub search terms worth a look: "Salesforce upsert external id Mule 4",
> "OData nextLink paging Mule", "DataWeave divideBy chunk", "Secure Configuration Properties AES".
