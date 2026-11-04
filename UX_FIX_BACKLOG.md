# yhcrames — Consolidated UX Fix Backlog

Single, de-duplicated, prioritized backlog consolidating the three review reports:
`login-ux-fix-plan.md`, `app-ux-review.md` (runtime), `studio-ux-review.md`.

**Legend:** `[SAFE]` = mechanical / low-risk, implement now · `[ARCHITECTURAL]` = needs a
design decision or infra change, planned in `ARCHITECTURAL_FIX_PLAN.md`.

**Status key:** TODO · IN PROGRESS · DONE · PARTIAL · DEFERRED-TO-PLAN

---

## Priority 1 — Trust / brand / activation

| ID | Tag | Item | Source(s) | Status |
|----|-----|------|-----------|--------|
| S1 | [SAFE] | Remove competitor name "Semarchy" from all **user-visible** strings (frontend + user-facing backend strings). Keep type identifiers / API contract keys / `data-semarchy-release-note` test hooks. | app #2, studio A | DONE |
| P1 | [ARCHITECTURAL] | Share auth session across runtime (:3001) & studio (:3000) so cross-app nav doesn't force a 2nd login. Root cause: per-origin `localStorage` tokens. | app #1, login "out of scope" | DEFERRED-TO-PLAN |
| S7 | [SAFE] | Mark cross-app nav items ("opens Studio" / "opens Runtime") so the app jump isn't a surprise (interim mitigation for P1). | app #1 | DONE |
| S5 | [SAFE] | Onboarding discoverability: route empty-tenant (no domains) users to the onboarding wizard; add a persistent "Get started" entry. | studio C | DONE |

## Priority 2 — Orientation / consistency

| ID | Tag | Item | Source(s) | Status |
|----|-----|------|-----------|--------|
| P2 | [ARCHITECTURAL] | Consolidate the 4 overlapping duplicate/curation surfaces (`/duplicates`, `/clusters`, `/curation`, `/curator-hub`). | app #4, studio | DEFERRED-TO-PLAN |
| S4 | [SAFE] | Copy/jargon: "Author Record"→"New Record"; "Import Insured CSV"→generic/entity-driven; label/tooltip the Configure/Operate toggle; plainer Domain/Entity scope labels. | login post-login, app #6/#7 | DONE |
| — | [ARCHITECTURAL-ish] | Single source of truth for domain/entity scoping (header vs per-page selectors). Larger IA change — captured in plan as a follow-on; S4 lands the **labeling** part now. | app #3, studio D | PARTIAL (labels done; full unification deferred) |

## Priority 3 — First-paint / forms / polish

| ID | Tag | Item | Source(s) | Status |
|----|-----|------|-----------|--------|
| S2 | [SAFE] | Login UX: inline `<Alert>` instead of top toast on local-login failure; "Signing in…" button label; admin-contact footer. | login Fix A/B | DONE |
| S3 | [SAFE] | First-paint loading shell inside `#root` in both apps' `index.html` (no blank white screen). | login #4, app #5 | DONE |
| S6 | [SAFE] | Replace free-text "magic string" form fields with selects from real data — Workflow Admin (definition, data location, assign user) and DM Probes (data location; application = autocomplete + helper text, no list API). | app #8, studio E | DONE |

## Items reviewed and intentionally NOT changed (with reason)

- **app #9 — Dashboard KPI cards intermittently blank**: "verify" finding, not a confirmed
  defect; pixel-only, no reproducible root cause. Not actioned (no clear fix; needs live repro).
- **studio B — Studio vs Runtime indistinguishable (same wordmark)**: branding decision
  (distinct wordmark / accent). S4 adds the Configure/Operate label cue; full re-brand is a
  design task, out of the SAFE scope.
- **app #5 / login #4 — slow first paint on heavy pages**: partially addressed by S3 splash;
  route-level skeletons + lazy-loading are larger perf work, mostly dev-mode chunking.
- **"Leave alone" goodness** (empty states, role workbenches, accessibility, entity cockpit,
  honest disclaimers) — preserved, untouched.

---

## What "user-visible Semarchy" means here (S1 scope decision)

The string `Semarchy` appears in ~51 frontend files and ~many backend files, but the vast
majority are **NOT user-visible** and were left untouched:

- **TypeScript type identifiers** (`SemarchyDataLocation`, `SemarchyWorkflowInstance`, …),
  API-client method names (`semarchyStartWorkflow`), query keys (`["semarchy-…"]`),
  component identifiers (`SemarchyAuthoringStepperProgress`). Renaming all is high-churn /
  high-risk; identifiers are invisible to users. Left as-is **except** the studio-local
  `canAccessSemarchyAdministration` (renamed — see S1 notes).
- **`data-semarchy-release-note="…"` attributes** — test hooks asserted by unit tests; not
  rendered text. Left as-is.
- **Backend `SEMARCHY_*_SOURCE` constants, `semarchy_*` field-config keys, comments, test
  files, migration column `semarchy_status`** — internal / API-contract / provenance; not
  rendered to end users. Left as-is (changing field-config keys would break the API contract).

**Changed (user-visible only):** page subtitles/descriptions, tab labels, alert/help text,
card titles, aria-labels, confirm-dialog titles, and the API-Playground category **label** +
example **descriptions** (the `category="semarchy_admin"` *key* — an API contract value — was
kept). One internal provenance constant (`SEMARCHY_COMPONENT_PROPERTY_FORMAT_SOURCE` in
`shared/src/i18n/runtimeDateFormat.ts`) is NOT rendered and was intentionally left.

---

## Verification (final)

- **Typecheck — PASS (authoritative).** `tsc --noEmit` ran successfully for all three
  frontend projects (shared, runtime, studio) → exit 0 each. Confirms the identifier rename
  (`canAccessAdministration`, `ADMIN_MENU_KEYS`, `RequireAdministration`), all new imports
  (`metamodelApi`, `useQuery`, `dataLocationsApi`, `usersApi`, `Select`, `AutoComplete`,
  `ExportOutlined`, `RocketOutlined`, `Tooltip`, `Typography`), and all JSX edits compile.
- **Backend** — `python -m py_compile backend/app/services/api_playground.py` → OK.
- **Unit tests — COULD NOT RUN in this Linux sandbox.** The mounted `node_modules` ships the
  macOS-native rollup binary; `@rollup/rollup-linux-arm64-gnu` is missing, so `vitest`/vite
  abort before running. Fell back to **diff review + grep confirmation**: updated the 4
  `DataLoads.test.tsx` assertions ("Import Insured CSV" → "Import CSV"), the
  `studio/navigation.test.tsx` import+calls (renamed fn), and the runtime
  `navigation.test.tsx` `CROSS_APP_LINKS` `toEqual` (added `ws-onboarding`). Confirmed
  `WorkspaceContextBar.test.tsx` queries by aria-label / combobox-index (preserved),
  `DataBrowser.test.tsx` asserts the unchanged stepper component + test-fixture strings, and
  `Administration.test.tsx`/`AppBuilder.test.tsx` assert `data-semarchy-release-note` /
  component names / unchanged labels — none broken.
- **e2e (Playwright) parity specs — updated, not executed.** 35 visible-string assertions +
  18 aria-label `getByRole(name:)` selectors across ~16 `e2e/*.spec.ts` files were updated to
  the new strings (string-content-only edits; cannot run without a live stack + browsers).
  Remaining `Semarchy` in `e2e/` are mock fixture DATA, identifiers, category keys, test
  titles, `data-semarchy-*`, or two strings (`Semarchy-style steward …`) not present in app
  source — none are stale assertions on changed UI.

### Files touched (by fix)
- **S1:** `runtime/WorkflowAdmin.tsx`, `studio/{NamedQueryEditor,DataProducts,AIEnrichers,
  DataLocations,APIKeys,DataManagementProbes,NotificationConfig,PluginManager,ThemeSettings,
  ModelVersions,AdminConsole,AppBuilder,Administration}.tsx`, `studio/{navigation,App}.tsx`
  (+`navigation.test.tsx`), `backend/app/services/api_playground.py`, and ~16 `e2e/*.spec.ts`.
- **S2:** `shared/src/components/LoginPage.tsx`.
- **S3:** `runtime/index.html`, `studio/index.html`.
- **S4:** `runtime/DataBrowser.tsx`, `runtime/DataLoads.tsx` (+`DataLoads.test.tsx`),
  `shared/src/components/workspace/WorkspaceContextBar.tsx`.
- **S5:** `studio/App.tsx`, `runtime/App.tsx` (+ runtime `navigation.test.tsx`).
- **S6:** `runtime/WorkflowAdmin.tsx`, `studio/DataManagementProbes.tsx`.
- **S7:** `runtime/App.tsx` (+ runtime `navigation.test.tsx`).
</content>
</invoke>
