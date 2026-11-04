# yhcrames Studio app — first-time-user UX review & fix plan

**Target:** `http://localhost:3000/studio/` (Studio / "Configure" app), logged in as `admin` · **Date:** 2026-06-25
**Method:** heuristic first-time-visitor walkthrough in a live browser (fresheyes harness not connected — manual review, no rage-quit score/replay). Findings are what I saw on screen, mapped to code where grounded.
**Scope:** all ~47 top-level Studio pages (`StudioLayout`), plus the entity-workspace **Overview cockpit** (sampled). The ~30 entity sub-section pages (`.../e/:entity/model|quality|match|workflows|operate|release/...`) were not individually swept — see "Not covered."

---

## Verdict

Studio is a deep, genuinely impressive configuration suite — ~47 consistent, well-built pages with excellent empty states, and an entity "cockpit" that's the best-designed surface in the entire product. Three things hold back the first-time experience: the **"Semarchy" (competitor) name is visible on at least nine pages**, Studio is **visually indistinguishable from the Runtime app** (same wordmark, nav, header), and the **best guidance — onboarding wizard, accelerator wizard, entity cockpit — is buried**, while a new user lands on a bare Model Designer.

---

## Cross-cutting findings

### A. "Semarchy" is pervasive in Studio's UI — HIGH (brand/trust/legal)
Visible competitor branding on at least nine surfaces:

- Named Queries — "inspect **Semarchy-compatible** endpoints"
- Notifications — "**Data Location** Operations" tab (Semarchy term)
- Plugin Manager — "**Semarchy** plugin bundles"
- Data Locations — "**Semarchy** data-location lifecycle manager" + "Semarchy-compatible data-location paths"
- API Keys — "**Semarchy** API Keys" tab
- Data Products — "**Semarchy-compatible** data product management"
- Data Management Probes — "**Semarchy** Data Management probe monitor" + "Semarchy-compatible /probes endpoints"
- API Playground — "**Semarchy** Administration API" example category
- (Runtime) Workflow Admin — "**Semarchy** workflow administration"

**Fix:** global rename. `grep -ri semarchy frontend/ backend/` to scope; prioritize visible strings, then internal type names (`DataLocations.tsx` etc.).

### B. Studio is indistinguishable from Runtime — HIGH (orientation)
Same "yhcrames" wordmark, same left-nav labels (Home/Domains/Work/Operations/Integrations/Data Products/Security/Administration), same header. The only cue you've switched apps is the unlabeled **Configure | Operate** toggle (Configure = Studio, Operate = Runtime). Combined with the separate-login handoff (see `app-ux-review.md` finding #1), a first-timer can't tell which app they're in. **Fix:** distinct mode branding ("yhcrames Studio" wordmark, a mode label/accent color) and a label/tooltip on the Configure/Operate toggle.

### C. The best guidance is buried; new users land on a bare page — HIGH (activation)
Studio has three genuinely strong guidance surfaces — but none is the default landing, and all sit unmarked in the nav:

- **Platform Onboarding** (`/onboarding`) — "Welcome to yhcrames MDM," quickstart templates (Customer/Product/Supplier MDM, ~15 min each) or start from scratch.
- **Accelerator Wizard** (`/accelerator-wizard`) — 8 industry packs (Customer 360, Product, Supplier/Vendor, Healthcare Provider & Patient, Insurance/Policyholder, Financial Services, Retail/CPG, Manufacturing) with pre-built entities, match rules, survivorship, and a Browse→Customize→Review→Deploy→Complete stepper.
- **Entity workspace "cockpit"** (`/.../e/:entity/overview`) — a 6-of-6 readiness ring, health score, and "recommended next actions."

Yet the default route is `/models` (Model Designer), a bare domain table. **Fix:** route first-time / empty-tenant users to `/onboarding`; add a persistent "Get started" entry; surface the entity cockpit's readiness pattern earlier.

### D. Same inconsistent domain/entity scoping as Runtime — MED
The header "Select domain" / "Select a domain first" pair rides along on every Studio page, while many pages also scope via their own controls (RACI has its own domain + entity selectors; Model Versions, Data Products have inline domain pickers). Same fix as the app-wide report: one scoping model, consistent labels.

### E. Free-text "magic string" forms repeat — LOW/MED
Like Runtime's Workflow Admin, **Data Management Probes** drives actions via free-text fields ("Data location" = `customer-hub`, "Application" = `CustomerWorkbench`) the user must already know. **Fix:** populate these from real data-locations/applications via dropdowns.

---

## What's genuinely good (leave alone / amplify)

- **Empty states everywhere** — nearly every page has a clear, instructive empty state with a primary CTA. Consistently excellent.
- **The entity workspace cockpit** — guided readiness checklist, health, recommended actions, entity-scoped nav (Model / Quality & Enrichment / Match & Merge / Workflows / Operate / Release). This is the product's gold standard; lean into it.
- **Onboarding + Accelerator wizards** — strong activation tools (once surfaced).
- **Honest disclaimers** — Config Manager states plainly it's "a configuration registry, not the live runtime config"; Data Locations gates destructive purges behind dry-run previews. Good trust-building.
- **Theming/a11y** — Theme & Branding ships Default/Dark/High Contrast/Corporate/Modern/Warm presets with live preview.
- **Developer tooling** — API Playground (33 categorized examples, request builder, code-snippet generator) and a built-in Knowledge Base for help content.
- **Consistent, professional visual system** across all 47 pages.

---

## Page log (top-level Studio)

| Page | Notes |
|------|-------|
| Model Designer (`/models`) | Domain list, New Domain, Delivery/Deploy/delete. Default landing. |
| Named Queries (`/queries`) | Good empty state; "Semarchy-compatible endpoints". |
| Notifications (`/notifications`) | Tabs incl. "Data Location Operations". |
| Reference Data (`/reference-data`) | Master-detail, strong empty states. |
| Scheduler (`/scheduler`) | KPI row + good empty state. |
| Plugin Manager (`/plugins`) | "Semarchy plugin bundles" / Import JAR. |
| Data Locations (`/data-locations`) | Heavy Semarchy copy; dry-run-gated purges (good). |
| Ingestion Sources (`/ingestion`) | Good empty state. |
| Ingestion Plans (`/ingestion-plans`) | KPI row + good empty state. |
| Import Templates (`/import-templates`) | Good empty state. |
| AI Enrichers (`/ai-enrichers`) | Tabs (AI Prompt / Partner), cost/token KPIs. |
| Event Streaming (`/event-streaming`) | KPI row, good empty state. |
| Warehouse Connectors (`/warehouse`) | Tabs (Connections/Queries/Sync/Discovery/Translate SQL). |
| CDC Connectors (`/cdc`) | Tabs (Connectors/Events/Metrics/Configuration). |
| Security Policies (`/security`) | Tabs (Policies/Classifications/Attribute/Runtime Preview). |
| Roles & Permissions (`/roles-permissions`) | 13 built-in system roles; comprehensive RBAC. |
| RACI Matrix (`/raci`) | Gated empty state; own domain+entity scope (double-scoping). |
| Data Governance (`/data-governance`) | Dashboard + Retention/Masking/Consent. |
| Alert Rules (`/alerts`) | KPI row, tabs, Evaluate All. |
| Rate Limits & Quotas (`/rate-limits`) | KPI row, tabs. |
| API Key Management (`/api-keys`) | "yhcrames" / "**Semarchy** API Keys" tabs. |
| Model Versions (`/model-versions`) | Environments + Version History + Promotion Requests. |
| Data Products (`/data-products`) | "Semarchy-compatible data product management". |
| Observability (`/observability`) | Health/Stats/Traces/Alerts; live status (Celery DEGRADED = env state). |
| SLA Policies (`/sla`) | KPI row, tabs, Check All. |
| Complex Data Types (`/complex-types`) | Tabs (Type Library/Designer/Schema Preview). |
| Metadata Catalog (`/catalog`) | Tabs (Sources/Asset Browser/Lineage Map/Dashboard/Auto-Map). |
| Data Management Probes (`/dm-probes`) | Semarchy copy + free-text magic-string form. |
| Override & Certification (`/overrides`) | Tabs (Override Flags/Certifications). |
| Dashboard Builder (`/dashboards`) | 4 dashboards, grid layout, full actions. |
| Agent Builder (`/agent-builder`) | Tabs (Custom/Templates/Built-in). |
| Automation Builder (`/automation-builder`) | Tabs (Automations/Templates/Triggers & Actions). |
| Report Builder (`/report-builder`) | KPI row, good empty state. |
| Self-Service Data Portal (`/data-portal`) | Catalog of datasets, request flow, KPIs. |
| Plugin Marketplace (`/marketplace`) | Tabs (Dashboard/Browse/Featured/Installations/Categories). |
| MCP Tool Marketplace (`/mcp-marketplace`) | KPIs, Publish Package, empty states. |
| AI Agent Marketplace (`/agent-marketplace`) | Filters incl. "Verified only", Publish Agent. |
| Knowledge Base (`/knowledge-base`) | Articles/FAQs/Categories, master-detail. |
| Platform Onboarding (`/onboarding`) | **Quickstart templates wizard (buried).** |
| Steward Workbench (`/steward-workbench`) | KPIs, Tasks/Activity/Metrics (overlaps Runtime workbenches). |
| Accelerator Wizard (`/accelerator-wizard`) | **8 industry accelerator packs (buried).** |
| API Playground (`/api-playground`) | 33 examples incl. "Semarchy Administration API"; request builder. |
| Theme & Branding (`/theme-settings`) | Presets (incl. Dark/High Contrast), live preview. |
| Configuration Management (`/config-manager`) | Honest "registry, not live config" disclaimer; envs + feature flags. |
| Domains (`/domains`) | Domain→entity picker → opens entity workspace. |
| Entity workspace Overview (`/.../e/:entity/overview`) | **Cockpit: readiness ring, health, recommended actions, entity nav.** |

---

## Prioritized fixes (Studio)

| # | Severity | Fix |
|---|----------|-----|
| 1 | High | Remove "Semarchy" from all visible copy (9+ surfaces) + code; rename to yhcrames |
| 2 | High | Brand/distinguish Studio vs Runtime; label the Configure/Operate toggle |
| 3 | High | Route new/empty-tenant users to `/onboarding`; surface Accelerator Wizard + the entity cockpit's readiness pattern earlier |
| 4 | Med | One consistent domain/entity scoping model (shared with Runtime fix) |
| 5 | Low/Med | Replace free-text magic-string forms (Data Management Probes) with pickers |

---

## Not covered (offer)

The ~30 **entity sub-section** pages (Model attributes/keys/relationships/settings/app-designer; Quality validation/conditional/enrichers/policies; Match rules/blocking/thresholds/survivorship/overrides; Workflows definitions/routing/sla; Operate records/loads/errors/clusters/data-quality/profiling/lineage; Release pending/validation/versions/deployments/audit) weren't individually swept. The Overview cockpit suggests they're well-organized and readiness-tracked. I can sweep them as a follow-up if you want full coverage.
