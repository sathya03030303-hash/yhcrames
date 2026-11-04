# Login first-time-user review & fix plan

**Page:** `http://localhost:3001/login` (runtime app) · **Code:** `frontend/shared/src/components/LoginPage.tsx`
**Date:** 2026-06-25 · **Method:** heuristic first-time-visitor walkthrough in a live browser (the fresheyes MCP harness wasn't connected in this session, so this is a manual review, not an official fresheyes run with a rage-quit score and replay).

## Verdict

A returning user with credentials can sign in fine. A **brand-new visitor hits a dead end**: the page asks for a username and password but offers no way to obtain either, and a failed attempt produces a vague error that flashes at the top of the screen, far from where they're looking. The rage-quit moment is the failed sign-in — "Invalid credentials," no Sign Up, no Forgot Password, nowhere to go.

## What I observed (live)

1. On first load the viewport was **blank white for ~2 seconds** with no loader, then the card appeared.
2. The form is clean: username, password (with show/hide), Sign In.
3. There is **no Sign Up / Create account** and **no Forgot password** anywhere.
4. Submitting `newuser` / a guessed password sat with no obvious feedback for several seconds, then an **"Invalid credentials" toast appeared pinned to the top-center of the window** and auto-dismissed — detached from the form and the button.

## Findings, ranked

| # | Severity | Friction | Root cause in code |
|---|----------|----------|--------------------|
| 1 | **High** | No way for a new visitor to get an account, and no guidance about how access works | `LoginPage.tsx` has no registration affordance; `api/auth.ts` exposes no `register` endpoint (access is admin-provisioned) |
| 2 | **Med** | Auth errors render as a global toast at the top of the screen, away from the form, and auto-dismiss | `onFinish` uses antd `message.error(...)` (line 93), which is a top-center transient toast |
| 3 | **Med** | No "Forgot password?" path or guidance | No reset link in `LoginPage.tsx`; no reset endpoint in `api/auth.ts` |
| 4 | **Med** | ~2s blank screen on first paint, no loading shell | SPA bundle loads before the card mounts; no splash in the app's `index.html` (worst in dev — verify against a production build) |
| 5 | Low–Med | Submit feels unresponsive; the button's loading state is easy to miss next to a top toast | Button has `loading` (good — it disables during the request) but no label change, and feedback lives at the top |
| 6 | Low | "Username" with no hint; "Invalid credentials" is terse | Field label + backend `detail` string |

## Already good (no change needed)

- **SSO/SAML is implemented.** "Sign in with SSO" and per-provider SAML buttons render when OIDC/SAML is configured (lines 144–171). They were absent here only because neither is enabled in this dev environment — not a defect.
- **Accessibility is strong:** `role="main"`, `aria-label` on the form, `aria-required` on inputs, `autoComplete`, and `aria-hidden` on decorative icons.

## Proposed fixes

### Fix A — move auth errors inline, and sharpen submit feedback (covers #2, #5, #6)

Replace the top toast with a persistent inline `Alert` above the form, and label the button while it works.

```diff
- import { Button, Card, Divider, Form, Input, Typography, message, Space } from "antd";
+ import { Button, Card, Divider, Form, Input, Typography, message, Space, Alert } from "antd";
```

```diff
   const [loading, setLoading] = useState(false);
+  const [error, setError] = useState<string | null>(null);
```

```diff
   const onFinish = async (values: { username: string; password: string }) => {
     setLoading(true);
+    setError(null);
     try {
       await login(values.username, values.password);
       message.success("Logged in");
       onSuccess?.();
     } catch (err: any) {
-      message.error(err?.response?.data?.detail || "Login failed");
+      setError(
+        err?.response?.data?.detail ||
+          "We couldn't sign you in. Check your username and password and try again."
+      );
     } finally {
       setLoading(false);
     }
   };
```

```diff
           <Form layout="vertical" onFinish={onFinish} autoComplete="off" aria-label="Login form">
+            {error && (
+              <Form.Item>
+                <Alert
+                  type="error"
+                  message={error}
+                  showIcon
+                  closable
+                  onClose={() => setError(null)}
+                  role="alert"
+                />
+              </Form.Item>
+            )}
```

```diff
-              <Button
-                type={(oidcConfig?.enabled || samlProviders.length > 0) ? "default" : "primary"}
-                htmlType="submit"
-                loading={loading}
-                block
-                size="large"
-              >
-                Sign In
-              </Button>
+              <Button
+                type={(oidcConfig?.enabled || samlProviders.length > 0) ? "default" : "primary"}
+                htmlType="submit"
+                loading={loading}
+                block
+                size="large"
+              >
+                {loading ? "Signing in…" : "Sign In"}
+              </Button>
```

Keep `message.error(...)` for the SSO/SAML *initiation* failures (lines 83, 105, 119) — those happen before navigation and a toast is acceptable. Only the local-login path needs the inline alert.

### Fix B — give a new visitor somewhere to go (covers #1, #3)

Add a footer under the form. This is guidance, not a self-serve signup (access is admin-provisioned), so it sets expectations instead of leading to a 404.

```diff
             </Form.Item>
           </Form>
+          <div style={{ textAlign: "center" }}>
+            <Text type="secondary" style={{ fontSize: 12 }}>
+              Need an account or a password reset? Contact your administrator.
+            </Text>
+          </div>
```

If/when the backend grows a password-reset or self-registration flow, swap this line for real `<a>`/`Link` affordances pointing at those routes.

### Fix C — kill the blank first paint (covers #4)

Add a minimal splash to the runtime app's `index.html` (the `#root` mount target) that's painted by the browser instantly and removed when React mounts. Example:

```html
<div id="root">
  <div id="app-splash" style="min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:system-ui;color:#888">
    Loading yhcrames…
  </div>
</div>
```

React replaces `#root`'s contents on mount, so no cleanup code is needed. Confirm the real-world gap against a **production build** (`pnpm build` + preview) — a chunk of the 2s is dev-mode module serving and won't exist in prod.

## Test & verify

- Update `LoginPage.test.tsx` to assert the inline `Alert` renders on a rejected `login` (instead of asserting on the global message), and that the button reads "Signing in…" while pending.
- Keep coverage ≥ 90% for the shared library (per `CLAUDE.md`).
- Re-run the walkthrough after the changes; the failed-login path should show a persistent, form-adjacent error and the footer guidance.

## Post-login first-run (bonus — lighter pass)

After signing in as `admin`, you land on `/dashboard`. First-time-user notes (directional — I grounded the standout in code but didn't do a full dashboard audit):

- **Two adjacent, similar-sounding domain dropdowns (Med).** The header shows "Select domain" (DomainSelect) right next to "Select a domain first" (EntitySelect, disabled). The second is actually the *entity* picker, gated until a domain is chosen — `frontend/shared/src/components/workspace/EntitySelect.tsx` (`placeholder={domainId ? placeholder : "Select a domain first"}`, `disabled={disabled || !domainId}`, lines 67/69). Side by side they read as redundant and confusing. **Fix:** label them "Domain" / "Entity", and make the gating read as a sequence — hide or visually subordinate the entity picker until a domain is selected, rather than showing a confusing disabled twin.
- **No first-run guidance / empty state (Med).** You're dropped straight into a dense dashboard (Loads, Validation Errors, Duplicate Groups) with no welcome, "start here," or tour. **Fix:** a one-time "Select a domain to begin" callout or lightweight first-run hint.
- **Unlabeled mode toggle (Low).** "Configure / Operate" switches modes with no hint of what changes. **Fix:** tooltips or short captions.
- **Jargon without help (Low).** "Loads," "Pending Duplicates," "Working (latest)" have no tooltips. **Fix:** hover help on KPI labels.
- **Credit where due:** once you're in, the dashboard is clean, professional, and genuinely informative (clear KPI numbers; charts with AI / Export / Switch Type). The trust gap is all *pre*-login — the inside looks solid.

I can do a full dashboard/onboarding pass with concrete diffs if you want it.

## Out of scope (flagging only)

Tokens are stored in `localStorage` (`stores/auth.ts`), which is readable by any XSS on the page. Not a usability issue — noting it for a future security pass; `httpOnly` cookies are the usual mitigation.
