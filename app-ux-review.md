# yhcrames runtime app — first-time-user UX review & fix plan

**Target:** `http://localhost:3001/` (runtime app), logged in as `admin` · **Date:** 2026-06-25
**Method:** heuristic first-time-visitor walkthrough in a live browser. The fresheyes MCP harness isn't connected in this environment (its server build is missing from the install), so this is a manual review — no official rage-quit score or replay artifact. Findings below are what I actually saw on screen, mapped to code where I could ground them.
**Scope:** every navigable page in the **runtime** app (24 routes). The **Studio** app (`:3000`) is a separate app with its own login and was not swept — see finding #1.

---

## Verdict

The product *inside* is genuinely strong — clean, consistent, with unusually good empty states and well-designed role workbenches. But the first-time experience is undermined at the seams: **half the main nav silently throws you to a second app that makes you log in again**, a **competitor's name ("Semarchy") is visible in the UI**, and the **domain/entity scoping model is inconsistent from page to page**. The polish is real; the seams are what cost you a new user's trust.

---

## Coverage

| Area | Pages visited |
|------|---------------|
| Home | Dashboard, Agency Dashboard, Dashboards (gallery) |
| Work | My Tasks, Business/Technical/Owner/DG-Lead Steward Workbenches, Error Queue, Duplicates, Cluster Curation, AI Curation, Curator Hub |
| Operations / data | Data Loads, Data Browser, Data Explorer, Business Views, Lineage, Hierarchy, Data Quality, AI Quality, Match Policies, Audit Trail, Workflow Admin |
| Cross-app (Studio :3000) | Domains/Integrations/Data Products/Security/Administration → redirect (tested via Domains) |

---

## Findings, ranked

### 1. Half the nav dumps you at a second login — HIGH
Domains, Integrations, Data Products, Security, and Administration are presented as normal left-nav items, but clicking them redirects from the runtime app (`:3001`) to the **Studio app (`:3000`)**, which has a **separate login session**. Clicking "Domains" while fully logged in landed me on `http://localhost:3000/studio/login` — effectively logged out. For a newcomer this reads as "did I just get logged out?" or even "is this a phishing redirect?" — a trust-breaking, rage-quit-class moment, and it gates 5 of 8 primary nav destinations.

**Root cause (grounded):** auth tokens are stored in `localStorage` (`frontend/shared/src/stores/auth.ts` — `yhcrames_token`), which is **per-origin**. `:3001` and `:3000` are different origins, so the runtime token is invisible to Studio → a second login is unavoidable. The redirects are defined in `frontend/runtime/src/App.tsx` (`CrossAppRedirect` to `/studio/*`, ~lines 280–284).

**Fix:** serve both apps under one origin (reverse-proxy `runtime` and `studio` under a single host/path) so the session is shared, or move auth to a cookie scoped to a shared parent domain / real SSO. Until then, at minimum visually mark cross-app nav items (e.g., an "opens Studio" indicator) so the jump isn't a surprise.

### 2. A competitor's name ("Semarchy") ships in the product — HIGH (trust/brand/legal)
`/workflow-admin` shows the subtitle **"Semarchy workflow administration."** The name is not isolated copy — `grep "Semarchy"` spans 40+ frontend files: a Studio nav capability (`canAccessSemarchyAdministration`), and pervasive type names in `frontend/studio/src/pages/DataLocations.tsx` (`SemarchyDataLocation`, `SemarchyPurgeResult`, …). User-visible competitor branding is a professionalism and brand/legal risk.

**Fix:** global rename to yhcrames terminology. Prioritize user-visible strings first (workflow-admin subtitle, any "Semarchy administration" nav label), then internal type names. `grep -ri semarchy frontend/ backend/` to scope it.

### 3. Inconsistent domain/entity scoping model — MED
The top bar carries two selectors — "Select domain" and "Select a domain first" (the entity picker, gated). But most pages *also* carry their **own inline** domain/entity selectors, with **inconsistent defaults**: Data Browser defaults to "Customer," Duplicate Manager to "Agency." Hierarchy stacks **three** inline selectors on top of the header's two. A first-timer can't form a mental model of "what am I looking at, and how do I change it."

**Fix:** pick one source of truth. Either the header selector drives all pages (remove the per-page ones), or remove the header pair and standardize a single inline pattern. Make defaults consistent and label them plainly ("Domain" / "Entity"). Components: `frontend/shared/src/components/workspace/DomainSelect.tsx`, `EntitySelect.tsx`, the runtime header/layout, and each page's inline usage.

### 4. Four overlapping surfaces for duplicate/curation work — MED
Duplicate Manager (`/duplicates`), Cluster Curation (`/clusters`), AI Curation (`/curation`), and Curator Hub (`/curator-hub`) all address dedup/merge/review, and all four sit together under the **Work** menu (alongside the steward workbenches, which also have a "Duplicate Queue"). A newcomer has no way to know which to use for "review duplicates."

**Fix:** consolidate, or differentiate explicitly — add one-line descriptions under each nav item and a clear "start here" path; consider merging Cluster Curation + Curator Hub or making them tabs of one surface.

### 5. Slow first paint on heavy pages, bare spinner — MED
`/explorer` showed only a centered spinner for ~8s before rendering (Views and Lineage were also slow on first hit). No skeleton or app-shell during the wait. (Login also shows a ~2s white screen on first paint — see `login-ux-fix-plan.md`.)

**Fix:** add route-level skeletons/loading shells; verify the real gap against a **production build** (much of this is dev-mode chunk compilation). Lazy-load heavy deps (the Explorer's visualization stack) behind interaction.

### 6. Domain-specific copy leaking into a generic product — MED
Data Loads' primary action is **"Import Insured CSV"** — insurance-specific wording in a generic MDM tool. There's also a hardcoded **"Agency Dashboard"** route/page. These look like demo/customer-specific bits shipped in core.

**Fix:** make labels entity/config-driven (e.g., "Import {entity} CSV"); gate or generalize the Agency Dashboard. Files: `frontend/runtime/src/pages/DataLoads.tsx`, `AgencyDashboard.tsx`.

### 7. MDM jargon in primary controls, no help — LOW
"Author Record" (Data Browser — newcomers expect "Add"/"New Record"), plus unexplained "Loads," "Pending Duplicates," "Working (latest)," and the unlabeled **Configure / Operate** mode toggle. **Fix:** plainer labels + tooltips on first-run.

### 8. Workflow start form uses free-text magic strings — LOW
`/workflow-admin` starts a workflow via free-text fields ("Data location," "Workflow definition" = `customer-approval`, "Assign user" = `steward2`). A user must already know valid values. **Fix:** dropdowns populated from definitions/users. File: `WorkflowAdmin.tsx`.

### 9. Dashboard KPI cards intermittently blank — LOW (verify)
The dashboard's top KPI cards rendered with values on first load but appeared empty on a later visit. Couldn't determine cause from pixels. **Fix:** verify the KPI fetch/loading state and add a skeleton/error state.

---

## What's genuinely good (leave alone)

- **Empty states are a standout.** Nearly every page has an instructive, friendly empty state ("Pick an entity and enter a record ID to see how it was sourced, matched, and consolidated," "All records have passed validation," etc.). This is better than most shipping products.
- **Role workbenches are excellent** — each (Business Steward, Technical Steward, Domain Owner, DG Lead) opens with a one-line purpose, a role badge, relevant KPIs, and focused tabs. They're discoverable under the **Work** menu.
- **Consistent, professional visual design** — breadcrumbs, clean tables with sort/filter/export, AI/Export affordances, sensible iconography.
- **Login accessibility is solid** (role="main", labelled form, aria-required, autocomplete) — see `login-ux-fix-plan.md`.

---

## Prioritized fix list

| # | Severity | Fix | Where |
|---|----------|-----|-------|
| 1 | High | Share auth session across runtime/studio (single origin or shared-domain cookie/SSO); mark cross-app links until then | `App.tsx` (~280–284), `stores/auth.ts`, deploy/proxy |
| 2 | High | Remove "Semarchy" from UI + code (rename to yhcrames) | grep `Semarchy` across repo; start with `WorkflowAdmin.tsx`, studio nav, `DataLocations.tsx` |
| 3 | Med | Single, consistent domain/entity scoping model + consistent defaults + clear labels | `DomainSelect.tsx`, `EntitySelect.tsx`, runtime header, per-page usages |
| 4 | Med | Consolidate/differentiate the 4 duplicate-curation surfaces | Work nav + `Duplicates`/`ClusterCuration`/`AICuration`/`CuratorHub` |
| 5 | Med | Route skeletons + verify on prod build; lazy-load heavy chunks | runtime route loader, `DataExplorer/*` |
| 6 | Med | Entity-driven labels; generalize/gate Agency Dashboard | `DataLoads.tsx`, `AgencyDashboard.tsx` |
| 7 | Low | Plainer labels + tooltips ("Author Record" → "New Record", explain Configure/Operate) | `DataBrowser.tsx`, runtime header |
| 8 | Low | Replace workflow free-text fields with pickers | `WorkflowAdmin.tsx` |
| 9 | Low | Verify dashboard KPI loading/empty states | `Dashboard.tsx`, `components/dashboard/KPIRow.tsx` |

---

## Suggested next steps

- The **Studio app (`:3000`)** is a whole second app (Domains, Ingestion, Security, Administration, Data Locations, model design) with its own login — I can run the same sweep there if you log me in to it.
- For the *official* fresheyes run (rage-quit score + shareable replay), build the harness locally per the steps I gave, then I'll re-run this against the live persona engine.
