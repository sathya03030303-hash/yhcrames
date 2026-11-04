# P1 Implementation Plan — Runtime and Studio as functionally-scoped apps

Grounded in the actual code at `/Users/dinesh/yhcrames`. Companion to the design rationale in `ARCHITECTURAL_FIX_PLAN.md` (P1). Each phase is independently shippable; verification = `pnpm --filter <pkg> typecheck` + named test files + the live pages listed.

## Key facts confirmed in code (these shape the plan)

- **Runtime's 5 cross-app items live in three coupled places** in `frontend/runtime/src/App.tsx`: (a) the `CROSS_APP_LINKS` map (~lines 115-122), (b) the `allMenuItems` array as top-level `ws-*` entries + the `ws-onboarding` child under `g-home` (~139-191), and (c) the `onMenuSelect` handler doing `window.location.assign(crossAppUrl("configure", crossApp))` (~321-325). There are ALSO same-tab redirect **routes** for the bare paths `/domains /integrations /data-products /security /administration` via `<CrossAppRedirect>` (~218-225, 338-342). All must change together or nav and routes desync.
- **The Configure/Operate toggle is a shared `<Segmented>`** in `frontend/shared/src/components/workspace/WorkspaceContextBar.tsx` (~118-154), rendered by BOTH apps. Its `onChange` does `window.location.assign(crossAppUrl(target, ...))` — a same-tab cross-origin jump. It is **app-agnostic** (keyed off `getAppKind()`), so a change here hits both apps at once.
- **Two MORE cross-app switch paths exist that the design brief did not call out** (entity-workspace level): `frontend/shared/src/components/workspace/EntityWorkspaceLayout.tsx` `onSectionSelect` (~86-105) same-tab-jumps to Studio when a steward clicks a Configure section; `frontend/runtime/src/pages/workspace/RuntimeSectionRedirect.tsx` (~13-42) does the same for deep-links. **The plan must cover these** or "no same-tab jumps" is only half-true.
- **`crossAppUrl(kind, path)`** (`frontend/shared/src/workspace/apps.ts` ~58-63) only returns an origin-prefixed string; it does NOT navigate. Same-tab behavior comes from callers doing `window.location.assign(...)`. So "open in new tab" is achieved at the call sites (`window.open(url, "_blank", "noopener")`); adding an `openOtherApp()` helper in `apps.ts` centralizes it.
- **Branding** is centralized in `frontend/shared/src/components/AppLayout.tsx`: `DEFAULT_APP_NAME = "yhcrames"`, `appName` from the branding API, rendered in the Sider title and header. `appIdentity.name` in `frontend/shared/src/design-system/brand.ts`. There is **no per-app name today** — both render the same `appName`, and AppLayout has no `appName` prop, so per-app branding needs a new prop.
- **Tests that will break:** `frontend/runtime/src/navigation.test.tsx` asserts the 8 top-level keys *including* `ws-*` and asserts `CROSS_APP_LINKS` equals a 6-entry map; `frontend/shared/src/components/workspace/WorkspaceContextBar.test.tsx` asserts "Configure"/"Operate" text render; `frontend/studio/src/navigation.test.tsx` asserts Studio's 8 homes.
- **`setAppKind`** is called in each `main.tsx` (`"operate"`/`"configure"`, default `"configure"`); `getAppKind()` is the reliable "which product am I" signal. `ROLE_MENU_KEYS` (App.tsx ~98-107) gates nav by `user.role` (`null` = show all). The empty-tenant gate (`RuntimeEntryRedirect`, ~233-262) and `ws-onboarding` also same-tab-jump to Studio onboarding — see Phase 3.

---

## Phase 1 — App-scope source of truth; derive Runtime nav from scope∩role; drop the 5 cross-app items

**Goal:** Runtime's nav contains only Operate-scoped items, filtered by role. No `ws-*` items, no `CROSS_APP_LINKS` jumps from the menu.

**New file — source of truth:** `frontend/shared/src/workspace/scope.ts` (export from `frontend/shared/src/index.ts` near the `apps.ts` block). Sketch:

```ts
export const OPERATE_SCOPE_HOMES = ["g-home", "g-work", "g-operations"] as const;
export const CONFIGURE_SCOPE_HOMES = [
  "g-home","g-domains","g-work","g-operations",
  "g-integrations","g-data-products","g-security","g-administration",
] as const;
export function homesForApp(kind: AppKind): readonly string[] {
  return kind === "operate" ? OPERATE_SCOPE_HOMES : CONFIGURE_SCOPE_HOMES;
}
```

This makes "Runtime drops Domains/Integrations/Data Products/Security/Administration" a **declarative fact** instead of being implicit in which `ws-*` entries exist. The existing `isSectionInApp`/`sectionHostApp` in `apps.ts` already model entity-workspace **section** scope; `scope.ts` is the **nav-home** analog — extends, not duplicates.

**Edits to `frontend/runtime/src/App.tsx`:**
- Delete the `ws-domains/ws-integrations/ws-data-products/ws-security/ws-administration` top-level entries and the `ws-onboarding` child from `allMenuItems`. `allMenuItems` becomes the 3 Operate homes (`g-home`, `g-work`, `g-operations`).
- Delete `CROSS_APP_LINKS`, `crossAppLabel`, and the now-unused icon imports (`DatabaseOutlined`, `CloudServerOutlined`, `SettingOutlined`, `ExportOutlined`, `RocketOutlined` — verify each is unused elsewhere first; `ExportOutlined` is reused by Phase 2/3, keep it).
- Simplify `onMenuSelect` to `navigate(\`/${key}\`)` — drop the `CROSS_APP_LINKS[key]` branch.
- Optionally filter `allMenuItems` through `homesForApp("operate")` defensively; `filterRuntimeMenu` still applies `ROLE_MENU_KEYS` on top — composition is `scope ∩ role`.
- Leave the same-tab redirect routes for the 5 removed paths in place during Phase 1 (deep-links still resolve); convert them in Phase 3, keeping Phase 1 a pure nav-surface change.

**Studio (low-risk):** keep `frontend/studio/src/navigation.tsx` defining all 8 homes, but assert against `CONFIGURE_SCOPE_HOMES` in its test so the scope module is authoritative. No behavior change.

**Tests:** rewrite `frontend/runtime/src/navigation.test.tsx` (top-level keys → `["g-home","g-work","g-operations"]`; delete the `CROSS_APP_LINKS` assertion; keep the role-filter `not.toContain("ws-security")` and add positive Operate-leaf assertions). Add a `scope.ts` test.

**Verify:** `pnpm --filter @yhcrames/runtime typecheck && pnpm --filter @yhcrames/shared typecheck` + both navigation tests. Live (:3001): sign in as a steward and as an admin/`viewer` (null role) — sidebar shows only Home/Work/Operations, no Domains/Integrations/Security/Administration, and every remaining item stays on :3001.

---

## Phase 2 — Replace the Configure/Operate toggle with a gated new-tab app launcher

**Goal:** No same-tab mode switch. Users who hold *both* scopes see an explicit "Open Studio ↗" (from Operate) / "Open Operate ↗" (from Studio) launcher that opens the other product in a new tab. Everyone else sees no switch affordance.

**The one genuinely new policy decision (needs product sign-off):** "holds both scopes" needs a predicate. There is no `canConfigure`/`canOperate` today — Studio gates only `canAccessAdministration` (`is_superuser`). Add `canAccessConfigure(user)` / `canAccessOperate(user)` to a shared helper (e.g. `frontend/shared/src/workspace/access.ts`). Pragmatic v1: Configure ≈ `is_superuser || role ∈ {admin, architect}`; Operate-only roles (stewards, owners, dg_lead, …) would NOT see "Open Studio". **Start conservative (`is_superuser` only) if unsure**, expand later.

**Edits to `frontend/shared/src/components/workspace/WorkspaceContextBar.tsx`:** remove the `<Segmented>` Mode block (and now-unused imports), replace with a conditionally-rendered launcher:

```tsx
const other = otherAppKind();                 // "configure" from Operate, vice-versa
const showLauncher = canAccessConfigure(user) && canAccessOperate(user);
{showLauncher && (
  <Tooltip title={`Opens ${otherProductName} in a new tab; you may need to sign in`}>
    <Button size="small" icon={<ExportOutlined />}
      onClick={() => {
        const url = ws.tenant && ws.domain && ws.entity
          ? crossAppUrl(other, workspaceUrlIn(other, {...ws, section: other === "operate" ? "operate/records" : "overview"}))
          : crossAppUrl(other, homeUrlIn(other));
        window.open(url, "_blank", "noopener");   // NEW TAB, not assign()
      }}>
      Open {otherProductName} <ExportOutlined />
    </Button>
  </Tooltip>
)}
```

The deep-link-to-same-entity logic is salvaged from the old `onChange`; the only substantive change is `window.open(_, "_blank", "noopener")` + the gating. **Optional:** add `openOtherApp(path)` in `apps.ts` so "new tab" is centralized and "never same-tab cross-app" is enforced in one place (the launcher and Phase 3 interstitial both call it).

**Tests:** update `WorkspaceContextBar.test.tsx` (remove the "Configure"/"Operate" assertions; add: dual-scope user → launcher renders and `window.open` called with `_blank`; Operate-only user → no launcher). The test harness needs an auth-store user seed (currently only metamodel is mocked).

**Verify:** `pnpm --filter @yhcrames/shared typecheck` + the ContextBar test. Live: as a steward (Operate) → NO launcher; as an admin → "Open Studio ↗" opens :3000 in a **new tab**, original tab unchanged. Mirror on Studio.

---

## Phase 3 — Interstitial + redirects for removed routes and entity-workspace cross-app jumps

**Goal:** Deep-links to removed Runtime routes, and clicks on Configure sections inside Runtime's entity workspace, show an explicit "this lives in Studio — open Studio?" interstitial that opens Studio in a new tab. No silent same-tab bounce, no 404.

**New file:** `frontend/runtime/src/pages/OpenInStudio.tsx` — small page: heading "This is part of Studio (Configure)", one sentence, primary "Open in Studio ↗" (`window.open(crossAppUrl("configure", target), "_blank", "noopener")`), secondary "Back to [Operate home]". Takes the target Studio path as a prop/param.

**Edits to `frontend/runtime/src/App.tsx`:**
- Replace the 5 `<CrossAppRedirect to="/studio/...">` routes with `<OpenInStudio to="/studio/domains" feature="Domains" />` etc.; delete `CrossAppRedirect`.
- `RuntimeCatchAll`: today a `/studio/*` URL on the Runtime origin same-tab-assigns to Studio — change to render `OpenInStudio` for `/studio/*`; keep `<Navigate to="/dashboard">` for genuinely-unknown paths.
- `RuntimeEntryRedirect` + `ws-onboarding`: the empty-tenant case auto-assigns to `/studio/onboarding`. **Confirmable:** keep as a true first-run cold-start hop (recommended) or route through `OpenInStudio`. Recommend keeping it and documenting it as the single sanctioned cross-app same-tab transition (it's not a mid-task jump).

**Entity-workspace cross-app paths (the extra ones found):**
- `EntityWorkspaceLayout.onSectionSelect`: when `!isSectionInApp(key)` and `getAppKind()==="operate"`, prefer **not rendering Configure sections in Runtime's section menu at all** — check `buildSectionMenu()`; if it already filters by `isSectionInApp`, this branch is dead; if not, filter there so Runtime's entity sidebar is Operate-only.
- `RuntimeSectionRedirect.tsx`: change the two `window.location.assign(crossAppUrl("configure", ...))` to render `OpenInStudio` (new tab) instead of auto-bouncing.

**Tests:** add `openInStudio.test.tsx` (renders copy + button; click calls `window.open` `_blank`; nothing auto-navigates on mount). Grep `CrossAppRedirect`/`RuntimeSectionRedirect` for existing tests before deleting.

**Verify:** `pnpm --filter @yhcrames/runtime typecheck`. Live: in Operate, type `/domains`, `/security`, `/studio/anything` → interstitial renders, opens :3000 in a new tab, original tab stays. In an Operate entity workspace, Configure sections aren't offered (or, by URL, show the interstitial).

---

## Phase 4 — Per-app branding (distinct product names + accent)

**Goal:** Operate reads "yhcrames Operate"; Studio reads "yhcrames Studio".

**Edits to `frontend/shared/src/components/AppLayout.tsx`:** add optional `appName?: string` (and optional `accentColor?`) to `AppLayoutProps`; use it as highest-priority source for the Sider title + header, falling back to the branding-API `appName` → `DEFAULT_APP_NAME` chain. Keep customer white-label authoritative: order `brandingConfig.app_name ?? props.appName ?? DEFAULT_APP_NAME` (confirmable — flip if product wants the product-suffix to always show).

**Edits to the two `App.tsx` files:** pass the name at each `<AppLayout>` — Runtime `RuntimeLayout` → `appName="yhcrames Operate"`; Studio `StudioLayout` → `appName="yhcrames Studio"`. `EntityWorkspaceLayout` also renders `<AppLayout>` — pass the name derived from `getAppKind()`. Centralize the strings (`productNameForApp(kind)` in `scope.ts`/`brand.ts`) so launcher labels (Phase 2) and interstitial copy (Phase 3) reuse them.

**Accent (optional, low priority):** AppLayout already computes `primaryColor`; rather than override `colorPrimary` (fights white-label), use a subtle product chip/tag next to the wordmark or a sider-header tint. Ship the wordmark first.

**Tests:** `AppLayout.test.tsx` — passing `appName="yhcrames Operate"` renders it; tenant-branding `app_name` still overrides. Update any snapshot expecting bare `"yhcrames"`.

**Verify:** `pnpm --filter @yhcrames/shared typecheck` + AppLayout test. Live: :3001 → "yhcrames Operate", :3000 → "yhcrames Studio", in both the global shell and an entity workspace; custom-branding tenant still overrides.

---

## Phase 5 (optional follow-on) — Shared-session SSO

Now a convenience, not a prerequisite (normal workflows stay in one app). If/when dual-persona launcher usage warrants it: move tokens from per-origin `localStorage` (`frontend/shared/src/stores/auth.ts`) to an httpOnly parent-domain cookie (`Domain=.yhcrames…; Secure; SameSite`), add axios `withCredentials`, an `/auth/me` bootstrap, and CSRF. Until then, the new-tab launcher may land on `/studio/login` if the session isn't shared — acceptable because it's an explicit new-tab action; the tooltip already warns "you may need to sign in". Keep single-origin prod serving so prod gets SSO via shared `localStorage`.

---

## Cross-cutting risks / rollback / sequencing

- **Four switch surfaces, not two.** Beyond the nav menu + toggle, Phase 3 must also handle `EntityWorkspaceLayout.onSectionSelect` and `RuntimeSectionRedirect` or "no same-tab jumps" leaks. This is the main thing the original design under-specified.
- **The toggle is shared/app-agnostic**, so the Phase 2 change touches both products at once — test both context bars. Rollback is clean (one component + test).
- **`ROLE_MENU_KEYS` ≠ scope predicate.** Phase 2 introduces a NEW policy (which roles get Configure). There's no existing `canConfigure` — only `is_superuser` in Studio. Get product sign-off on the role→scope map; start conservative (`is_superuser` only).
- **Empty-tenant + `ws-onboarding` first-run hop** still same-tab-jumps to Studio onboarding. Recommend leaving it (cold start) and documenting it as the single sanctioned cross-app same-tab transition.
- **Each phase is independently revertible.** Phase 1 = nav data + one test. Phase 2 = one shared component + test. Phase 3 = new page + route swaps. Phase 4 = one prop + call-site strings. No DB/infra until optional Phase 5.
- **Recommended ship order (minimal-policy-first): 1 → 4 → 3 → 2 → 5.** Branding and interstitial carry no new policy; the launcher's role mapping is the only thing needing product input.
- **Dead-import sweep:** removing `CROSS_APP_LINKS`/`crossAppLabel`/`CrossAppRedirect`/`Segmented` orphans several imports; `noUnusedLocals` is on, so typecheck catches stragglers — run it after each phase.

## Critical files
- `frontend/runtime/src/App.tsx`
- `frontend/shared/src/components/workspace/WorkspaceContextBar.tsx`
- `frontend/shared/src/components/AppLayout.tsx`
- `frontend/shared/src/workspace/apps.ts` (+ new sibling `scope.ts`, `access.ts`)
- `frontend/shared/src/components/workspace/EntityWorkspaceLayout.tsx`
- `frontend/runtime/src/pages/workspace/RuntimeSectionRedirect.tsx`
