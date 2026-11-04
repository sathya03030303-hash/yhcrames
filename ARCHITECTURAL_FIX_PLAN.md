# Architectural Fix Plan (P1, P2)

Planning only — no code changes here. These two items need a design decision and/or
infra change beyond the mechanical SAFE fixes already implemented. The revised P1 below
(functional-scope separation) **supersedes the interim SAFE fix S7** ("opens Studio" nav
cue): under this approach those nav items leave Runtime entirely rather than being
annotated.

---

## P1 — Treat Runtime and Studio as two functionally-scoped apps (no in-app switching)

### Decision (revised direction, per product owner)
Rather than make the two apps **share a session so users can hop between them seamlessly**,
**scope each app to its functional persona and remove silent cross-app switching entirely.**
A user inside Runtime never gets bounced into Studio (or vice-versa). This dissolves the
"did I get logged out?" moment at its source instead of papering over it, and it also fixes
the "two identical-looking apps" confusion (Studio report, finding B).

### Problem & root cause (unchanged, for context)
Today, clicking a Configure/platform nav item (Domains, Integrations, Data Products,
Security, Administration) or flipping the **Operate → Configure** toggle hard-navigates from
Runtime (`:3001`) to Studio (`:3000`), which shows its own `/studio/login` — the user appears
logged out mid-session. Root cause: tokens live in per-origin `localStorage`
(`frontend/shared/src/stores/auth.ts`) and the two apps are different origins in dev
(`frontend/shared/src/workspace/apps.ts`). **Note:** prod already serves both from one origin
behind nginx (Studio at `/studio`, Runtime at `/`), so session-sharing is largely a dev-topology
issue — but the deeper UX problem is that **the apps offer to switch at all**, which the model
below removes.

### The model
- **Studio = the superset** (Configure + Operate) — for designers / admins / DG leads. It
  already contains the operational views (the entity-workspace **Operate** sections: records,
  loads, errors, clusters, data-quality, lineage), so a Studio user never needs to leave Studio
  to see operational data. *"Runtime's specifics are also present in Studio."*
- **Runtime = the operate-only subset** — for stewards / operators: Dashboard, My Tasks, the
  steward workbenches, Error Queue, Duplicates & Curation, Loads, Data Browser/Author, Quality,
  Lineage, Hierarchy, Explorer, Views. **No model design, no integrations/security/admin config,
  no app-switch.**
- **Nav = (the app's functional scope) ∩ (the user's role permissions)** — "functional-scope
  driven." Each app renders only what it's for, then filtered by what the user may do.

### What changes vs today
- Runtime's nav **drops the 5 items that currently redirect to Studio** (Domains/model,
  Integrations, Data Products, Security, Administration) — they belong to Studio's scope. This
  **supersedes the interim S7 "opens Studio ↗" cue**: the items leave Runtime's nav rather than
  being annotated.
- The **Configure | Operate toggle stops being a silent same-tab app-switch.** Preferred: remove
  the inline toggle. For the minority who legitimately hold both personas, offer an explicit
  **app launcher** ("Open Studio" / "Open Runtime") that opens the other product in a **new tab**
  with a clear "you're switching products" affordance — never an in-place redirect.
- Each app gets **distinct branding** (e.g. "yhcrames Studio" vs "yhcrames Operate") and ideally
  an accent color, so you always know which product you're in.

### What this does to the auth problem
Because normal workflows stay inside one app, the cross-app **re-login disappears regardless of
origin topology** — so session-sharing is demoted from "the fix" to an **optional single-sign-on
convenience** for the few who run both products. Keep serving both behind one origin in prod
(already the documented model in `apps.ts`) so that *if* someone launches the other product, a
shared cookie/localStorage gives them SSO; but nothing in the core UX depends on it anymore.

### Personas / the one tradeoff
- Operator / steward → **Runtime** (scoped, no config, no switching).
- Designer / admin / DG-lead → **Studio** (superset; configures *and* operates in one place).
- A solo admin in a small deployment who wants "everything" simply **lives in Studio** (it's the
  superset) — never blocked, they just don't use the stripped-down Runtime. So strict separation
  costs nobody access; it only removes the confusing mid-task jump.

### Files / mechanisms (plan only)
- `frontend/runtime/src/App.tsx` — `allMenuItems` + `ROLE_MENU_KEYS`: remove the 5 cross-app
  (`ws-*`) entries; drive the menu from an explicit **Runtime scope set** ∩ role keys.
- A shared **app-scope definition** (e.g. under `frontend/shared/src/workspace/`) listing which
  nav keys belong to Operate vs the full Studio set; both apps build nav from `scope ∩ canAccess*`.
- Replace the Configure/Operate toggle with either nothing (Runtime) or an explicit new-tab
  **app launcher**, gated to users who hold both scopes.
- `frontend/shared/src/workspace/apps.ts` — `crossAppUrl` becomes "open the other product in a new
  tab," not in-place `window.location` navigation; keep single-origin prod serving for optional SSO.
- Per-app branding (wordmark / accent) in each app's shell/header.
- Redirects for the removed Runtime routes (`/domains`, `/integrations`, `/security`,
  `/administration`, `/data-products`) → an explicit "this lives in Studio — open Studio?"
  interstitial (new tab), not a silent same-tab bounce.
- Tests: `frontend/runtime/src/navigation.test.tsx` (the `CROSS_APP_LINKS` / leaf-key assertions
  change).

### Optional follow-on (only if you still want one sign-on)
To give dual-persona users a single sign-on across both products, layer an **httpOnly
shared-parent-domain cookie** (also closes the `localStorage` XSS gap noted in
`login-ux-fix-plan.md`): tokens → `Set-Cookie Domain=.yhcrames…; httpOnly; Secure; SameSite`,
axios `withCredentials`, `/auth/me` bootstrap, CSRF protection. This is now a convenience, not a
prerequisite.

### Open decisions for you
1. Runtime's product name — "Operate"? "Runtime"? (affects branding + launcher labels).
2. Remove the Configure/Operate toggle entirely, or keep it as an explicit new-tab launcher for
   dual-persona users?
3. Deep-links to the removed Runtime routes: an "open in Studio" interstitial vs. just hiding them.

---

## P2 — Consolidate the 4 overlapping duplicate / curation surfaces

### Problem
Four runtime pages all address dedup / merge / review and sit together under the **Work**
menu (plus the steward workbenches, which also have a "Duplicate Queue"). A newcomer has no
way to know which to use for "review duplicates." Routes & current purpose (grounded):

| Route | Page | usePageTitle | What it does |
|-------|------|--------------|--------------|
| `/duplicates` | `Duplicates.tsx` | "Duplicates" | Per-entity duplicate **groups**: view/manage, merge/dismiss. Also embeddable. |
| `/clusters` | `ClusterCuration.tsx` | "Cluster Curation" | Runs **cluster analysis** on a group → sub-clusters + confidence; flags bad merges. |
| `/curation` | `AICuration.tsx` | "AI Curation" | AI-suggested curation actions. |
| `/curator-hub` | `CuratorHub.tsx` | "Curator Hub" | Queue of **AI match recommendations / suggestions** to accept/reject. |

Overlap: `/curation` and `/curator-hub` are both "AI suggestion review"; `/duplicates` and
`/clusters` are both "work a duplicate group" (groups vs. sub-cluster analysis of a group).

### Proposed consolidated IA
Collapse the four into **one surface, "Duplicates & Curation"** (single nav item under Work),
implemented as a tabbed page that reuses the existing components (most already support an
`embedded` mode — e.g. `Duplicates.tsx` has an `embedded` prop):

- **Tab 1 — Duplicate Groups** (`Duplicates.tsx`, embedded): the default landing; browse/
  manage groups, merge/dismiss. This is the "start here" for "review duplicates."
- **Tab 2 — Cluster Analysis** (`ClusterCuration.tsx`, embedded): deeper analysis of a
  selected group (sub-clusters, confidence, bad-merge detection). Reached from a group in
  Tab 1 ("Analyze clusters") or directly via the tab.
- **Tab 3 — AI Curation Queue** (merge `AICuration.tsx` + `CuratorHub.tsx`): unify the two
  AI-suggestion surfaces into one queue (accept/reject suggestions + AI match
  recommendations). These overlap the most and should become a single review queue, not two.

Entity scope is selected once at the page level and shared across tabs (consistent with the
S4 Domain/Entity labeling and the broader scoping cleanup).

**What merges:** AI Curation + Curator Hub → one "AI Curation Queue" tab.
**What stays (as tabs, not separate nav):** Duplicate Groups, Cluster Analysis.
**Nav change:** Work menu goes from 4 items (`duplicates`, `clusters`, `curation`,
`curator-hub`) to **1** ("Duplicates & Curation"). The steward workbenches' "Duplicate
Queue" should deep-link into Tab 1 rather than duplicating the surface.

### Routing / nav changes
- New parent route `/duplicates` renders the tabbed container; tabs map to query params or
  sub-paths: `/duplicates` (Groups), `/duplicates/clusters`, `/duplicates/curation`.
- Keep `/clusters`, `/curation`, `/curator-hub` as **redirects** to the corresponding tab so
  existing bookmarks/links don't 404 (the app already favors redirect-not-blank, e.g.
  `RuntimeCatchAll`).
- `allMenuItems` in `frontend/runtime/src/App.tsx`: replace the 4 Work children with 1; update
  `ROLE_MENU_KEYS` entries that list `duplicates`/`clusters`/`curation`/`curator-hub`.
- Update `frontend/runtime/src/navigation.test.tsx` (leaf-key assertions reference
  `duplicates`).

### Files affected
- `frontend/runtime/src/App.tsx` (routes + `allMenuItems` + `ROLE_MENU_KEYS`).
- `frontend/runtime/src/pages/Duplicates.tsx`, `ClusterCuration.tsx`, `AICuration.tsx`,
  `CuratorHub.tsx` (ensure each renders in an `embedded`/tab mode; build the merged AI queue).
- A new container page (e.g. `DuplicatesCuration.tsx`) hosting the tabs.
- `frontend/runtime/src/navigation.test.tsx` and any workbench "Duplicate Queue" links.

### Migration path
1. Introduce the tabbed container reusing the existing components in `embedded` mode; leave
   the 4 routes working.
2. Merge AI Curation + Curator Hub into the single "AI Curation Queue" tab (de-dupe their
   data fetching and accept/reject actions).
3. Switch the Work nav to the single item; convert the old routes to tab redirects.
4. Repoint steward-workbench "Duplicate Queue" entries to the new tab.
5. Remove dead code once redirects + tabs are verified; update tests.

### Risk / sequencing
Lower-risk than P1 (no auth/infra), but touches navigation IA and merges two data-fetching
surfaces, so it warrants its own PR with screenshots and a redirect-coverage check. Sequence
**after** P1 only if desired; they are independent.
