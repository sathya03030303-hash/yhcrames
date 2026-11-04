# yhcrames — Complete End-to-End Manual Test Plan

Target: **https://yhcrames.aizzentec.ai** (Runtime app at `/`, Studio app at `/studio/`)
Scope: every user journey for all 13 roles, including model design, data source connections, file upload, the full certification pipeline (Ingest → Validate → Enrich → Match/Merge → Stewardship → Consolidate → Publish → Notify → Monitor), governance, and platform administration.

> **Creating objects:** for any "create / add / configure" step, open the form and fill *all required fields* per **`test-scenarios/FORM_FIELDS.md`** (required flags, defaults, dropdown options, and conditional fields that only appear after you pick a type). The list view doesn't show them.

> **Why the order matters (read first):** the platform fails silently or hard if phases run out of order.
> 1. The domain must be **deployed** (Validate → Build → Deploy) before any load — otherwise loads fail with *"Lifecycle table GD_… is not deployed."*
> 2. At least one **active match rule** must exist on the entity **before** you upload data — otherwise matching is skipped (`no_active_rules`) and the Duplicates page stays empty forever.
> 3. A **quality scorecard** must be created (New Scorecard button, admin/architect) before the Data Quality page has anything to show.
> 4. A **dashboard must be built and Published in Studio** before Runtime's dashboards page lists anything.
> Follow the parts in order; each produces the data the next one consumes.

---

## Part 0 — Prerequisites

### 0.1 Accounts
| # | Username | Role | App focus |
|---|----------|------|-----------|
| 0 | `admin` | Administrator (superuser) | everything — password is in `/home/ubuntu/yhcrames/.env` (`DEFAULT_ADMIN_PASSWORD`) |
| 1 | `architect1` | architect | Studio design |
| 2 | `steward1` | steward | Runtime stewardship |
| 3 | `integrator1` | integrator | ingestion/connectors |
| 4 | `viewer1` | viewer | read-only |
| 5 | `bsteward1` | business_steward | steward workbench |
| 6 | `tsteward1` | technical_steward | tech workbench |
| 7 | `downer1` | domain_owner | owner workbench |
| 8 | `dglead1` | dg_lead | DG lead workbench |
| 9 | `asteward1` | app_steward | loads/lineage |
| 10 | `ansteward1` | analytics_steward | quality/explorer |
| 11 | `exec1` | executive_steerco | KPI view |
| 12 | `council1` | dg_council | audit view |

Users 1–12 are created **by you** in Part 1 (that's the user-management test). Pick one shared password, e.g. `Verify-2026!`.

### 0.2 Sample files — create these on your machine

**`customers_good_and_bad.csv`** (15 rows: valid rows, 1 invalid email, 2 fuzzy-duplicate pairs, 1 exact-key duplicate):
```csv
customer_code,first_name,last_name,email,phone,city,segment
C001,John,Smith,john.smith@example.com,+1-555-0101,New York,Premium
C002,Jane,Doe,jane.doe@example.com,+1-555-0102,Chicago,Standard
C003,Robert,Johnson,robert.j@example.com,+1-555-0103,Houston,Premium
C004,Emily,Williams,emily.w@example.com,+1-555-0104,Phoenix,Standard
C005,Michael,Brown,not-an-email,+1-555-0105,Dallas,Standard
C006,Jon,Smith,jon.smith@example.com,+1-555-0101,New York,Premium
C007,Jane,Do,jane.do@example.com,+1-555-0102,Chicago,Standard
C008,Sarah,Davis,sarah.d@example.com,+1-555-0108,Austin,Enterprise
C009,David,Miller,david.m@example.com,+1-555-0109,Seattle,Premium
C010,Laura,Wilson,laura.w@example.com,+1-555-0110,Denver,Standard
C011,James,Moore,james.m@example.com,+1-555-0111,Boston,Enterprise
C012,Linda,Taylor,linda.t@example.com,+1-555-0112,Portland,Standard
C013,William,Anderson,will.a@example.com,+1-555-0113,San Diego,Premium
C001,John,Smyth,john.smith@example.com,+1-555-0101,New York,Premium
C015,Patricia,Thomas,patricia.t@example.com,+1-555-0115,San Francisco,Enterprise
```
Row C005 violates the email rule (validation test). C001/C006 and C002/C007 are fuzzy duplicates. Row 14 reuses business key C001 (exact-key consolidation test).

**`customers_update.csv`** (3 rows, for the second/incremental load):
```csv
customer_code,first_name,last_name,email,phone,city,segment
C002,Jane,Doe,jane.doe@newcorp.com,+1-555-0102,Chicago,Premium
C016,Kevin,Hart,kevin.h@example.com,+1-555-0116,Miami,Standard
C017,Nancy,White,nancy.w@example.com,+1-555-0117,Atlanta,Premium
```

### 0.3 Getting an API token (used in several steps)
```bash
TOKEN=$(curl -s -X POST https://yhcrames.aizzentec.ai/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<ADMIN_PASSWORD>"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['access_token'])")
```

### 0.4 Doing the `curl` / API steps entirely in the UI (no terminal, no token)

Every `curl` step in this plan can be performed in the browser. Each API-based row below carries a **🖱️ UI alternative**. There are two paths:

- **Dedicated UI** — a real page/button does the same thing (e.g. exporting goldens = *Export View* on Business Views). Use these where they exist.
- **API Playground** — Studio ships a built-in API client at **Studio → `</>` API Playground**, which runs any request the curl would, using your logged-in session (so you never paste a token, and role-based access control still applies — a viewer running a steward-only call correctly gets 403).

**Using the API Playground:** (1) **Method** = the `-X` verb (GET/POST/PUT/DELETE/PATCH). (2) **Path** = everything after `https://yhcrames.aizzentec.ai`, e.g. `/api/v1/sql/entities/<id>/query`. (3) **Headers** = any `-H` beyond Authorization (e.g. `X-API-Key`, `Content-Type`). (4) **Body** = the JSON from `-d`. (5) **Query Params** = anything after `?` (e.g. `processNow=true`). (6) **Execute** → status + JSON response appear below.

**Operation → dedicated-UI quick lookup**

| API operation | Dedicated UI |
|---|---|
| `sql/entities/{id}/bulk-insert` | Runtime → Data Loads → New Load → **Paste JSON** tab |
| `sql/entities/{id}/query` | Runtime → Business Views → **Filter builder** (Field/Operator/Value → Add) |
| `sql/entities/{id}/export-csv` | Runtime → Business Views → **Export View** |
| `sql/entities/{id}/import-csv` | Runtime → Data Loads → New Load → **Upload File** tab |
| `loads/{id}/submit?processNow=true` | Runtime → Data Loads → **Send** (paper-plane) icon |
| named queries (create/run/export) | Studio → Named Queries → New Query → **Run Preview** → publish |
| business views (create/apply/export) | Runtime → Business Views → **Save View** / Saved-view dropdown / **Export View** |
| `ingestion/webhook/{id}` (fire) | API Playground (POST + `X-API-Key`; copy key from the source's *Webhook Endpoint* card) |
| `ingestion/sources/{id}/flush` `/stats` `/events` | Studio → Ingestion Sources → source drawer → **Flush Buffer**, Statistic cards, Change Events table |
| `connectors` (DB) + `/test` + `/sync` | Studio → Warehouse Connectors → New Connection → **▶ Test** → Start Sync (REST/CSV connectors: API Playground) |
| `auth/me`, `me/change-password` | **API Playground only** (no profile page) |
| `consolidation/strategies` + group `/preview` | Runtime → Duplicates → group → **Preview Golden Record** |
| `workflows/.../workflow-instances` + task claim/action | Runtime → Workflow Admin + My Tasks (Claim → Approve/Reject) |
| `api-keys` + `/rotate` + `/revoke` | Studio → Security → API Keys → **Create Key** / rotate / revoke |
| `event-streaming` config + `/publish` | Studio → Integration → Event Streaming → Create → **Publish** icon |
| `validation/errors/{id}/correct` + reload | Runtime → Errors → **Correct** → Data Loads → Submit to reprocess |

Anything not listed: use the **API Playground** with the method/path/body shown in the step.

---

## Part 1 — Admin: authentication & user management (creates the 12 role accounts)

Login as **admin**.

| Step | Action | Expected |
|---|---|---|
| 1.1 | Open https://yhcrames.aizzentec.ai — you are redirected to `/login`. Enter wrong password once. | Error toast "Login failed"; no redirect. |
| 1.2 | Log in with correct admin credentials. | Redirect to `/dashboard`; menu bar renders. |
| 1.3 | Go to **https://yhcrames.aizzentec.ai/studio/admin** → "User Management" tab. | User table shows only `admin`. |
| 1.4 | Click **New User**. Create each of the 12 accounts from §0.1: username, email (e.g. `architect1@aizzentec.ai`), full name, password, **Role** from the dropdown. | Each user appears in the table with a color-coded role tag. The dropdown offers exactly the 13 backend roles (5 core + 8 governance); the phantom `author` role was removed in the fix round. |
| 1.5 | Edit `viewer1` → change full name → save. | Change persists after refresh. |
| 1.6 | Toggle `viewer1` **Active** off, attempt login as viewer1 in a private window. | Login rejected (account disabled). Toggle back on; login succeeds. |
| 1.7 | Use **Reset Password** on one user. | Temporary password generated; login works with it. |
| 1.8 | Profile APIs (real endpoints): `GET /api/v1/auth/me` (read own profile — note your `id`); `PATCH /api/v1/users/<your_id>` with `{"full_name":"New Name"}` (update name — admin, by id; there is no self-service `/me` update); `POST /api/v1/users/<your_id>/reset-password` (admin reset → returns a temporary password). <br>**🖱️ UI alternative (API Playground):** GET `/api/v1/auth/me` → copy `id`; PATCH `/api/v1/users/<id>` Body `{"full_name":"New Name"}` (re-run GET to confirm); POST `/api/v1/users/<id>/reset-password`. | 200 with profile; name update persists; reset-password returns a temporary password. ⚠️ No self-service change-password (verify-old→set-new) endpoint exists — only admin reset. |

---

## Part 2 — Architect: build & deploy the data model (Studio)

Login as **architect1** at **/studio/**.

| Step | Action | Expected |
|---|---|---|
| 2.1 | Go to `/studio/models` (Model Designer). Click **New Domain**: name `customer` (snake_case enforced), display name "Customer Domain", description. | Domain appears with status `draft`, version 0. |
| 2.2 | Click the domain row to open the Entity Designer. Under **Entities** click **Add**: name `Customer` (PascalCase enforced), display "Customer", table prefix `CUSTOMER` (UPPER_CASE), strategy `fuzzy_match`. | Entity appears in left panel with strategy tag. |
| 2.3 | Select the entity. Click **Add Attribute** for each: `customer_code` (string, **business_key ON**, required), `first_name` (string, required), `last_name` (string, required), `email` (string, searchable), `phone` (string), `city` (string), `segment` (string). | Attributes table lists all 7 with BK/required tags. |
| 2.4 | **Matching Rules tab** (⚠️ this is here in Entity Designer, NOT in Rule Builder): click **Add Rule**. Name "Name fuzzy match", source attributes `first_name,last_name`, comparison method `jaro_winkler`, threshold `0.85`. Add a second rule "Email exact", attribute `email`, method `exact`, threshold `1.0`. Ensure both are **active**. | Both rules listed with method/weight/threshold. **This must exist before any data load** or matching is silently skipped. |
| 2.5 | (Optional relationship test) Add a second entity `Address` and a relationship `customer_address` (one_to_many, Customer→Address). | Relationship appears in Relationships tab. |
| 2.6 | Run the **Delivery** workflow on the domain: **Validate** → **Build** → **Deploy**. | Validation passes (entity/attribute counts shown); Deploy reports "Deployed N entities". ⚠️ Skipping this makes every load fail with "Lifecycle table GD_CUSTOMER is not deployed". |
| 2.7 | Go to `/studio/rules` (Rule Builder). Select domain `customer`, entity `Customer`. **Validation Rules tab** → **New Rule**: name "Email format", type `regex`, attribute `email`, pattern `^[^@\s]+@[^@\s]+\.[^@\s]+$`, severity `error`, active ON. Add a second: "Segment allowed values", type `enum`, attribute `segment`, values `Premium,Standard,Enterprise`, severity `warning`. | Rules listed with severity badges and is_active toggles. |
| 2.8 | **Enrichers tab** → **New Enricher**: name "City normalizer", kind `Built-in` → `text_normalize` (or `uppercase`), target `city`, stage `pre`, active ON. | Enricher listed with kind tag. |
| 2.9 | Negative test: try to create a domain named `1bad` and an entity named `lowercase`. | Form validation rejects (regex patterns `^[a-z][a-z0-9_]*`, `^[A-Z][A-Za-z0-9_]*$`). |

---

## Part 3 — Admin/Architect: match policy thresholds (Runtime)

Login as **architect1** (or admin) at the Runtime app `/`.

| Step | Action | Expected |
|---|---|---|
| 3.1 | Go to `/match-policies`. Select domain `customer`, entity `Customer`. | Three sliders render: Auto Merge, Review Band High, Review Band Low. |
| 3.2 | Set auto_merge `0.95`, high `0.85`, low `0.60`. Toggle **Enable Policy** ON. Click **Save Policy**. | Save succeeds; values persist on refresh. |
| 3.3 | Note the **Live Preview** panel (will be empty now, populated after Part 4). | Empty state before data exists. |

---

## Part 4 — Integrator: data ingestion (upload + data source connections)

Login as **integrator1** (Runtime `/`). ⚠️ File upload is allowed for admin/integrator/steward-lineage roles — **technical_steward can create loads but gets 403 on the file-upload tab** (verify this in Part 8).

### 4A — CSV file upload (primary load)
| Step | Action | Expected |
|---|---|---|
| 4.1 | Go to `/loads` (Data Loads). Click **+** (new load). Select entity `Customer`, source system `CRM`, description "Initial load". | Create modal shows File and JSON tabs. |
| 4.2 | **File tab**: drag in `customers_good_and_bad.csv` (the picker accepts `.xlsx,.xls,.csv`). Submit. | Load created and auto-submitted; appears in the table with record count 15 and a status that advances: submitted → validating → enriching → matching → consolidating → completed. |
| 4.3 | Click the load row. | Drawer lists individual load records with per-record status (pending → validated → enriched → matched → consolidated) and parsed JSON data. |

### 4B — JSON records (second load)
| Step | Action | Expected |
|---|---|---|
| 4.4 | Create another load; **JSON tab**: paste the 3 rows of `customers_update.csv` as a JSON array of objects (same field names). Submit. | Load processes; C016/C017 create new golden records; C002 consolidates with the existing C002. |

### 4C — SQL API (bulk insert / query / export)
Run as admin/integrator token:
| Step | Action | Expected |
|---|---|---|
| 4.5 | `POST /api/v1/sql/entities/{entity_id}/bulk-insert` with `{"records":[{...2 new customers...}]}` (get entity_id from Studio or `GET /api/v1/entities`). <br>**🖱️ UI alternative:** Runtime → **Data Loads** → **New Load** → **Entity** = Customer → **Paste JSON** tab → paste the records array → **OK** (creates the draft load with the records). | Response with record_count/valid_count; a draft load created. Max 5000 records per call. |
| 4.6 | `POST /api/v1/sql/entities/{entity_id}/query` body `{"where":"segment = 'Premium'","limit":100}`. <br>**🖱️ UI alternative:** Runtime → **Business Views** → pick Domain + Customer → filter builder: **Field** `segment`, **Operator** `eq`, **Value** `Premium` → **Add**. Table shows the Premium subset. | Filtered golden records returned. |
| 4.7 | `GET /api/v1/sql/entities/{entity_id}/export-csv` <br>**🖱️ UI alternative:** Runtime → **Business Views** → pick Customer → **Export View** (downloads all goldens as a spreadsheet). | CSV download containing all golden records. |
| 4.8 | CSV import endpoint directly: `POST /api/v1/sql/entities/{entity_id}/import-csv` (multipart, file=`customers_update.csv`). <br>**🖱️ UI alternative:** Runtime → **Data Loads** → **New Load** → Customer → **Upload File** tab → select `customers_update.csv` → **OK** (or Business Views → **Import XLSX**). | Load created in `draft` status. |

### 4D — Data source connectors
| Step | Action | Expected |
|---|---|---|
| 4.9 | **Ingestion source (webhook)** — Studio → Integration → **Ingestion Sources** → **Create Source** (form fields in `test-scenarios/FORM_FIELDS.md`): **Name** = "crm-webhook" (R), **Source Type** = `webhook` (R), **Target Entity** = `Customer` (R), **Field Mapping (JSON)** = `{"cust_id":"customer_code","fname":"first_name","lname":"last_name","mail":"email"}`, **Active** ON. | Source created; an `api_key` is generated and shown. |
| 4.10 | Fire the webhook: `curl -X POST https://yhcrames.aizzentec.ai/api/v1/ingestion/webhook/{source_id} -H "X-API-Key: <api_key>" -H "Content-Type: application/json" -d '{"event_type":"upsert","data":{"cust_id":"C020","fname":"Webhook","lname":"User","mail":"webhook.user@example.com"}}'` <br>**🖱️ UI alternative (API Playground — no Send button):** copy the API key from Studio → Ingestion Sources → source drawer → *Webhook Endpoint* card. Then Studio → **API Playground**: POST `/api/v1/ingestion/webhook/<source_id>`, Header `X-API-Key` = `<key>`, Body the event JSON → Execute. Verify in the source drawer's **Change Events** table. | 200; event visible via `GET /api/v1/ingestion/sources/{id}/events` progressing received→mapped. |
| 4.11 | Flush the buffer: `POST /api/v1/ingestion/sources/{id}/flush`, then check `GET /api/v1/ingestion/sources/{id}/stats`. <br>**🖱️ UI alternative:** Studio → **Ingestion Sources** → open the source drawer → *Buffer Management* → **Flush Buffer**; **stats** are the Statistic cards at the top (click **Refresh**). | A Load is created from buffered events; stats show total_received/processed. |
| 4.12 | **Database connector** (uses the app's own PostgreSQL — reachable from inside the backend as service `postgres:5432`): `POST /api/v1/connectors` body `{"name":"Own PG","connector_type":"database","config":{"connection_string":"postgresql://yhcrames:<POSTGRES_PASSWORD from .env>@postgres:5432/yhcrames","table":"users","schema_name":"public"}}` then `POST /api/v1/connectors/{id}/test`. <br>**🖱️ UI alternative:** the same DB-test outcome is the dedicated **Warehouse Connectors** screen (see 4.15: New Connection type `postgres`, creds in Connection Config JSON, **▶ Test** icon). For the literal generic `/connectors` endpoint use Studio → **API Playground**: POST `/api/v1/connectors` with the body, then POST `/api/v1/connectors/<id>/test`. | Test returns success with latency_ms and PostgreSQL version — proves real outbound DB connectivity. |
| 4.13 | **REST API connector**: `POST /api/v1/connectors` `{"name":"Public API","connector_type":"rest_api","config":{"base_url":"https://jsonplaceholder.typicode.com","endpoint":"/users","method":"GET","auth_type":"none"}}` → test → `POST /api/v1/connectors/{id}/sync` direction=`read`, limit 10. <br>**🖱️ UI alternative (API Playground — no dedicated page for generic connectors):** Studio → **API Playground**: POST `/api/v1/connectors` (the body), copy the `id`, POST `/api/v1/connectors/<id>/test`, then POST `/api/v1/connectors/<id>/sync` Body `{"direction":"read","limit":10}`. | Test succeeds; sync returns 10 records; schema inferred from JSON fields. |
| 4.14 | **CSV connector**: create with `connector_type":"csv"`, `file_path` of a server-side CSV; test. <br>**🖱️ UI alternative (API Playground):** POST `/api/v1/connectors` Body `{"name":"CSV Conn","connector_type":"csv","config":{"file_path":"<server path>"}}`, then POST `/api/v1/connectors/<id>/test`. (To load a CSV from your machine, use Data Loads → Upload File, per 4.8.) | Schema inferred (column names/types) from first rows. |
| 4.15 | **Warehouse connection** — Studio → Integration → **Warehouse** → Connections → **New Connection** (form fields in `FORM_FIELDS.md`): **Name** (R), **Type** = `postgres` (R), **Connection Config (JSON)** = `{"host":"postgres","port":5432,"user":"yhcrames","password":"<PG_PASSWORD>","database":"yhcrames"}` (⚠️ all creds in this one JSON field — no separate inputs) → **Test** → **Discover**. | Connection healthy with latency; discovery lists tables (users, domains, entities, …). |
| 4.16 | **CDC connector smoke** — Studio → Integration → **CDC Connectors** → **New Connector** (form fields in `FORM_FIELDS.md`): **Name** (R), **Type** = `postgres_logical` (R — ⚠️ NOT `postgres_wal`, which doesn't exist; options debezium/postgres_logical/mysql_binlog/sqlserver_cdc/oracle_logminer/generic_polling), **Target Entity** = Customer (R), dummy Source Config. Don't start it. | Config-form validation works; connector saves in `stopped` state. |
| 4.17 | Negative test: connector test with a bad password in 4.12's connection string. | Test fails gracefully with an error message, not a 500. |

---

## Part 5 — Pipeline verification, stage by stage

Use **admin** or **steward1** unless noted. Data from Part 4 drives everything here.

| Step | Stage | Action | Expected |
|---|---|---|---|
| 5.1 | Validate | Runtime `/errors` (Error Queue), filter entity `Customer`, status `open`. | The C005 row's `not-an-email` appears as an **error** ("Email format"); any segment typos appear as **warnings**. Columns: Entity, Attribute, Severity, Code, Message, Value, Status. |
| 5.2 | Correct | As **steward1** (or bsteward1): click **Correct** on the email error, enter `michael.b@example.com`, save. | Status flips to `corrected` (green); corrected_value shown; action buttons disappear. |
| 5.3 | Dismiss | Click **Dismiss** on a warning. | Status `dismissed`. |
| 5.4 | Remediate | Load the corrected row again (same business key) as a new load — corrections in the Error Queue are triage metadata; there is no reprocess endpoint. | Corrected reload consolidates onto the same golden record with the fixed value. |
| 5.5 | Enrich | Runtime `/browse` → select Customer → open a record. | `city` values show the enricher's normalization (e.g. consistent casing) — proves pre-enrichment ran. |
| 5.6 | Match | Runtime `/duplicates` → entity `Customer`. | Duplicate groups exist: John Smith/Jon Smith and Jane Doe/Jane Do pairs, with match scores and tier badges (auto ≥0.95 green, confirm 0.85–0.95 gold, suggest 0.60–0.85 blue). The Smith pair matches on the **name** rule despite differing emails — active match rules **OR-combine**, each catching its own duplicates (fixed 2026-06-12; they used to dilute to a single blended score). ⚠️ If empty, match rules (2.4) were missing before load — re-check. |
| 5.7 | Compare | Click a group → **Compare**. | Side-by-side field comparison with exact/similar/different color coding. |
| 5.8 | AI assist | Click **AI Recommendations** on a group. | Field-level recommendations panel (if no ANTHROPIC/OPENAI key configured in `.env`, expect a graceful "AI not configured" error — note which). |
| 5.9 | Merge | As **steward1**: select master record, click **Merge**, enter justification, confirm. | Group status → `merged`; MergeDecision recorded (manual). |
| 5.10 | Split | Open the merged golden record (`/data/golden/{id}`) → Composition tab → **Split out** a contributor, give a reason. | New duplicate group created for the split record; decision logged. |
| 5.11 | Policy preview | Back on `/match-policies`, move sliders. | **Live Preview** now shows pending groups re-tiered as thresholds move; **Reclassify Pending Groups** re-tiers persisted groups. |
| 5.12 | Consolidate | `GET /api/v1/consolidation/strategies`; then for one group: `POST /api/v1/consolidation/groups/{group_id}/preview`. <br>**🖱️ UI alternative:** Runtime → **Duplicates** → Customer → click a group → **Preview Golden Record** (AI Survivorship) shows the per-field survivor selection. Raw strategy list: Studio → **API Playground** → `GET /api/v1/consolidation/strategies`. | Strategies list (most_recent, preferred_publisher, custom_ranking, per_attribute); preview shows survivor selection per field. |
| 5.13 | Publish | Runtime `/browse` → entity Customer. | All goldens visible: ~15 distinct customers (dupes merged, C001 key-consolidated). Row click → detail drawer with Overview / Compare Fields / Record Graph / All Fields tabs. |
| 5.14 | Author | In Browse, click **Author Record** → 3-step wizard (Root fields → Child collection → Review & Submit). Create customer C030 manually. | New golden record appears; if key fields changed later via Edit, a workflow task is created. |
| 5.15 | Delete | On a test record: **Delete Record** → soft delete radio → confirm. | Record marked deleted; dependency check table shown first. |
| 5.16 | Lineage | `/lineage` (or "View Full Lineage" from a merged record). | DAG renders: source records → load → match → consolidation → golden; node hover shows details. |
| 5.17 | Monitor | `/dashboard` as any role. | KPI cards (Total Loads, Total Records, Open Errors, Pending Duplicates) reflect everything above; charts populated (Load Status donut, Validation Errors, Duplicate Groups). Auto-refreshes every 60s. |
| 5.18 | Audit | `/audit` (as admin or dg_council). | Every correction, merge, split, delete from this part is logged with actor + timestamp. |

---

## Part 6 — Governance workbenches & tasks

| Step | Login as | Action | Expected |
|---|---|---|---|
| 6.1 | **bsteward1** | Log in to Runtime. | Lands on **/business-steward** (not /dashboard). Workbench tabs: Duplicate Queue, Quality Issues, My Tasks, Activity Feed; 6 KPI cards. Menu = Dashboard, Steward Workbench, Browse, Duplicates, Errors, Tasks, Quality. |
| 6.2 | bsteward1 | Correct an error from the workbench's Quality Issues tab. | Same correction flow as 5.2 — succeeds (inherits steward). |
| 6.3 | bsteward1 | `/tasks` (My Tasks): claim an unassigned task → Start → Complete. | Status transitions open → in_progress → completed; SLA deadline shown (red if overdue). |
| 6.4 | **downer1** | Log in. | Lands on **/domain-owner**. Stats: Domain Quality Score, Open Exceptions, Records Under Management, Scorecard Count; domains list. |
| 6.5 | downer1 | Assign a pending task to a steward via the assign modal. | Task assignee updates; visible in steward's My Tasks. |
| 6.6 | **dglead1** | Log in. | Lands on **/dg-lead**. Metrics: Governed Domains, Active Stewards, Avg Quality Score, SLA Compliance, Total Entities. |
| 6.7 | dglead1 | Studio `/studio/workflows` → **New Workflow**: trigger `validation_failed`, entity Customer, one approval step (assignee role steward, SLA 24h) → Save → Publish. | Succeeds — dg_lead inherits **architect**. Flow diagram renders trigger → step → end. |
| 6.8 | **tsteward1** | Log in. | Lands on **/technical-steward**. Metrics: Match Rules, Validation Rules, Pipeline Success Rate, Schema Version, Failed Pipelines. Menu includes Browse, Duplicates, Quality, Lineage, Loads. |
| 6.9 | tsteward1 | Open `/duplicates`, try to **Merge** a group. | Merge/Dismiss/Split buttons are **disabled** with a "Requires a steward role" hint — technical_steward inherits architect, not steward (fixed UX; API still 403s). |
| 6.10 | admin | Workflow instances API: `GET /api/v1/workflows/default/workflow-instances?status_filter=pending` (the UI now pre-fills the correct tenant name **`default`**). <br>**🖱️ UI alternative:** Runtime → **Workflow Admin** (pre-fills data location `default`) → **Refresh** → instances table (click a row for details). To claim/approve: Runtime → **My Tasks** → open a pending task → **Claim** → **Approve**/**Reject**. | Instance list returns (the 6.7 workflow may have spawned instances if validation failed again). Claim/approve a task via PATCH (UI: My Tasks). |

---

## Part 7 — Quality, dashboards & analytics

| Step | Login as | Action | Expected |
|---|---|---|---|
| 7.1 | admin (API) | Create a scorecard: Runtime `/quality` → select entity → **New Scorecard** (admin/architect only; API `POST /api/v1/data-quality/scorecards` also works) | 201. ⚠️ Without this, `/quality` shows only empty states. |
| 7.2 | steward1 | Runtime `/quality` → entity Customer → **Run Evaluation**. | Overall score % with color (green ≥80), dimension progress bars, trend chart starts tracking. |
| 7.3 | ansteward1 | Open `/quality` and try **Run Evaluation**. | Page renders read-only; the Run Evaluation button is hidden (viewer lineage). Sees "No trend data yet…" only if 7.2 skipped. |
| 7.4 | architect1 | Studio `/studio/dashboards` (Dashboard Builder): create dashboard "Customer Overview", add widgets, click **Publish**. | Dashboard saved with Published tag. ⚠️ Runtime lists only published dashboards. |
| 7.5 | viewer1 | Runtime `/dashboards`. | The published "Customer Overview" appears and renders. |
| 7.6 | viewer1 | `/views` (Business Views). | Views list with business-friendly attribute names; filters work; **Export CSV** downloads. |
| 7.7 | admin (API) | Hierarchy precondition: Runtime `/hierarchy` → **New Definition** (admin/architect only) for an entity with a self-referencing parent attribute; API `POST /api/v1/hierarchy/definitions` also works. | Definition selectable in dropdown; tree renders. Without it the page dead-ends at "Select a domain, entity, and hierarchy definition…". |
| 7.8 | architect1 | Studio `/studio/queries` (Named Queries): **New Query** on Customer with WHERE `segment = 'Premium'`; **Test**. | Results modal shows only Premium customers; export works. |

---

## Part 8 — Role-by-role authorization matrix

For **each** row: log in fresh (private window), confirm landing page, confirm the menu shows exactly the listed items, perform the ✅ action, attempt the ❌ action and confirm denial (403 toast or hidden UI).

> **🖱️ Reproducing the API-path denials in the UI:** where the ❌ column names an `/api/v1/...` call (e.g. `admin/console/health`, `workflows/definitions`, `workflows/tasks/{id}/action`), run it as that role in Studio → **API Playground** — it sends the logged-in session, so the same **403** comes back. The matching dedicated-UI denial is that the button/menu simply isn't shown for that role.

| Role (user) | Lands on | Runtime menu should show | ✅ Must succeed | ❌ Must be denied |
|---|---|---|---|---|
| admin | /dashboard | everything | open `/studio/admin` and `/studio/admin-console` | nothing — verify no 403 anywhere |
| architect1 | /dashboard | full studio access | create model/rules/workflows (Part 2) | `GET /api/v1/admin/console/health` → 403; `/studio/admin` redirects away (not superuser) |
| steward1 | /dashboard | Dashboard, Browse, Duplicates, Errors, Tasks, Quality | correct error, merge duplicates | `POST /api/v1/workflows/definitions` → 403; create scorecard → 403 |
| integrator1 | /dashboard | Dashboard, Browse, Loads, Lineage | create load + connectors (Part 4) | create validation rule → 403; `/studio/admin` blocked |
| viewer1 | /dashboard | Dashboard (+ broad read menus) | view dashboards/quality | correct error → 403; merge → 403; any POST/PATCH/DELETE; **approve/claim a workflow task → 403** (`POST /api/v1/workflows/tasks/{id}/action`, fixed 2026-06-12) |
| bsteward1 | **/business-steward** | + Steward Workbench | workbench actions, corrections, merges | create rule → 403 |
| tsteward1 | **/technical-steward** | + Tech Workbench, Loads, Lineage | manage match/validation rules | **merge/dismiss/split duplicates → 403**; correct error → 403; **file-upload tab in /loads → 403** (JSON load creation succeeds) |
| downer1 | **/domain-owner** | + Owner Workbench, Audit | assign tasks, corrections | create workflow → 403 |
| dglead1 | **/dg-lead** | + DG Lead Workbench, Audit | create workflow (architect inherit) AND correct error (steward inherit) | manage users → 403 |
| asteward1 | /dashboard | Dashboard, Browse, Loads, Lineage | create + file-upload loads (integrator inherit) | create rule → 403; merge → 403 |
| ansteward1 | /dashboard | Dashboard, Browse, Quality, Explorer | view quality, explorer | Run Evaluation button hidden; correct error → 403 |
| exec1 | /dashboard | Dashboard, Quality **only** | view KPIs | Browse absent from menu; all mutations 403 |
| council1 | /dashboard | Dashboard, Quality, Audit | view audit trail | correct error → 403; Browse absent |

Also verify (any non-superuser): direct URL navigation to a hidden workbench (e.g. steward1 → `/dg-lead`) renders the page shell but its data calls return 403 — frontend menus hide, backend enforces.

---

## Part 9 — Platform administration & notifications

All as **admin** unless noted.

| Step | Action | Expected |
|---|---|---|
| 9.1 | **Webhook notification end-to-end**: get a URL at https://webhook.site. Studio `/studio/notifications` → Channels → **New Channel** (type webhook, the URL) → Triggers → **New Trigger** (event `load_completed`, that channel). Then run a small load (Part 4B style). | webhook.site receives a POST with the load payload. Delivery logged in notification logs. |
| 9.2 | Email channel: create channel type `email` with dummy SMTP. | Channel saves; trigger fires; delivery **fails gracefully** in logs (no SMTP configured) — that's the expected result here. |
| 9.3 | `/studio/api-keys`: create key with read-only scopes; call a write endpoint with it; then a read endpoint. | Write → 403 (insufficient scope), read → 200. Key shown once then masked; revoke works. |
| 9.4 | `/studio/security` (Security Policies): create an `attribute_mask` policy on `email` for role `viewer`. As viewer1, browse Customer. | Email values masked for viewer; unmasked for steward. |
| 9.5 | `/studio/data-governance`: create a retention policy (archive after 365d) and a masking rule; add a consent record. | All three tabs persist entries; Dashboard tab counters update. |
| 9.6 | `/studio/admin` → Backup tab: **Export Tenant Config**; re-upload the JSON via Import. | Download contains domains/entities/rules counts; import validates and reports counts. |
| 9.7 | `/studio/admin-console`: Overview / Resources / Sessions / Errors / Background Jobs tabs. | Health=healthy; CPU/mem/disk gauges; your own session listed (terminate a stale one); celery queue depths visible. |
| 9.8 | `/studio/theme-settings`: switch dark mode, change primary color, save, refresh. | Theme persists across reload. |
| 9.9 | SAML/SCIM smoke: `/studio/admin` SAML tab → add a dummy provider → **Test**. SCIM tab → add directory with dummy endpoint → Sync Now. | Forms validate; tests fail gracefully against dummy endpoints with clear errors (not 500s); tokens masked. |
| 9.10 | **Flower** (server-side only): `ssh` to the host, open `http://127.0.0.1:5556` (or tunnel: `ssh -L 5556:127.0.0.1:5556 ubuntu@13.206.26.248`). Login with `FLOWER_USER`/`FLOWER_PASSWORD` from `/home/ubuntu/yhcrames/.env`. | Dashboard shows the celery worker, processed task counts; Tasks tab lists `process_load` executions from Parts 4–5 with SUCCESS status. |
| 9.11 | Logout test (each app): click logout in Runtime, then in Studio. | Runtime returns to `/login`; **Studio returns to `/studio/login`** (must NOT land on the Runtime login). |
| 9.12 | Deep-link refresh: hard-refresh on `/duplicates` and `/studio/models`. | Both reload into the correct app (no 404, no app swap). |

---

## Part 10 — Studio long-tail smoke checklist

For each page: it loads without error, the primary list/table renders (empty state is OK), and the create-button modal opens and validates. (All are reachable to authenticated users; superuser-only pages marked ★.)

`/studio/complex-types` · `/studio/model-versions` · `/studio/data-products` · `/studio/reference-data` · `/studio/overrides` · `/studio/conditional-rules` · `/studio/event-streaming` · `/studio/catalog` (Metadata Catalog) · `/studio/ai-enrichers` · `/studio/agent-builder` · `/studio/plugins` · `/studio/marketplace` · `/studio/mcp-marketplace` · `/studio/scheduler` · `/studio/alerts` · `/studio/observability` · `/studio/dm-probes` · `/studio/data-profiler` · `/studio/batch-config` · `/studio/api-playground` · `/studio/report-builder` · `/studio/automation-builder` · `/studio/agent-marketplace` · `/studio/onboarding` · `/studio/config-manager` · `/studio/accelerator-wizard` · `/studio/notification-templates` · `/studio/apps` (App Builder: create a form app on Customer, add fields, Preview, Publish) · `/studio/sla` · `/studio/rate-limits` · `/studio/data-locations` · `/studio/data-portal` · `/studio/knowledge-base` · ★`/studio/admin` · ★`/studio/admin-console`

---

## Appendix A — Useful API quick reference

```bash
BASE=https://yhcrames.aizzentec.ai/api/v1
AUTH="Authorization: Bearer $TOKEN"

# entities / domains
curl -s $BASE/domains -H "$AUTH"
curl -s "$BASE/entities?domain_id=<id>" -H "$AUTH"

# loads
curl -s -X POST "$BASE/loads/<load_id>/submit?processNow=true" -H "$AUTH"
curl -s $BASE/loads/<load_id> -H "$AUTH"           # poll status

# matching
curl -s "$BASE/matching/groups?entity_id=<id>" -H "$AUTH"
curl -s -X POST $BASE/matching/groups/<gid>/merge -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"master_id":"<rid>","justification":"manual test"}'

# validation
curl -s "$BASE/validation/errors?entity_id=<id>&status=open" -H "$AUTH"
curl -s $BASE/validation/starter-rules -H "$AUTH"   # FEIN/phone/DUNS/zip starter catalog

# monitoring
curl -s $BASE/monitoring/loads/stats -H "$AUTH"
curl -s $BASE/health
```

> **🖱️ Same calls in the UI.** Every line above can be run from Studio → **API Playground** (paste the path after `/api/v1`, no token needed — your session is used). Most also have a dedicated screen: domains/entities → Studio Model Designer; load submit/poll → Runtime **Data Loads** (Send icon + the load drawer's live status); matching groups + merge → Runtime **Duplicates** (group → Compare → Merge with justification); validation errors → Runtime **Errors**; monitoring stats → Runtime **Dashboard**. See §0.4 for the full lookup.

## Appendix B — Pipeline status vocabulary

- **Load**: initialized → loading → submitted → validating → enriching → matching → consolidating → completed | failed | cancelled
- **LoadRecord**: pending → validated → enriched → matched → consolidated → published
- **DuplicateGroup**: pending → reviewing → merged | split | dismissed; tiers: auto (≥0.95) / confirm (0.85–0.95) / suggest (0.60–0.85)
- **ValidationError**: open → corrected | dismissed | reprocessed
- **Lifecycle tables**: SA (staging) → SD (source data) → MD (master) → GD (golden), per-entity, created at domain **Deploy**

## Appendix C — Quirk status (after the 2026-06-12 fix round)

Fixed in the deployed build:
1. **Phantom `author` role** — removed; both role dropdowns (Studio User Management and Workflow Designer step assignee) now offer exactly the 13 backend roles including all 8 governance roles.
2. **technical_steward dead-end actions** — Merge/Dismiss/Split buttons are disabled with a "Requires a steward role" hint for roles without steward lineage, and the load file-upload tab is hidden for roles the backend rejects (JSON tab remains). APIs still enforce 403 — the backend stays the security boundary.
3. **Workflow Admin prefill** — now pre-fills the real tenant name `default` instead of `customer-hub`.
4. **Scorecards / hierarchy definitions** — now creatable in the UI: "New Scorecard" on the Data Quality page and "New Definition" on the Hierarchy page (admin/architect-lineage only). "Run Evaluation" is shown only to roles allowed to evaluate (steward/architect lineage).
5. **Runtime dashboards empty state** — now explains that dashboards must be built and Published in Studio.

Still true by design:
6. AI features need `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` in `.env`; without them expect graceful "not configured" errors.
7. Demo personas (`bs_user` etc.) are intentionally **not** seeded in production (bootstrap seeds them only when `APP_ENV` is not `production`) — the Part 1 accounts replace them.
8. Route guards are menu-level; direct URLs render shells whose API calls 403 — the backend is the enforcement layer (Part 8 verifies this).
