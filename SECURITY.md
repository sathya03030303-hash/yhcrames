# Security Policy

## Supported Versions

yhcrames has no tagged releases yet. Security fixes land on the `main` branch.

| Version | Supported |
|---------|-----------|
| `main` (latest commit) | Yes |
| 0.1.x package versions (`package.json`, `backend/pyproject.toml`) built from an older commit | No: upgrade to the latest `main` |

Once releases are tagged, this table will list the supported release lines.

## Reporting a Vulnerability

Please report vulnerabilities privately:

**Contact:** `<security contact — to be provided by the maintainers>`

The maintainers have not yet published a monitored security address. Until they do, the
deployment's `/.well-known/security.txt` deliberately answers 404 (see
`docs/security/README.md`). Do not use addresses found in older copies of this file.

Please include:

- a description of the vulnerability and its potential impact (for example: cross-tenant?
  pre-authentication?);
- steps to reproduce it, the affected endpoint(s), and the commit or image you tested;
- any relevant logs, screenshots or proof-of-concept code, with secrets redacted.

**Do not** open a public issue for a security vulnerability.

## Response Timeline

| Stage | Timeline |
|-------|----------|
| Acknowledgment | Within 48 hours of report |
| Initial assessment | Within 5 business days |
| Fix for critical severity | Within 30 days |
| Fix for high severity | Within 60 days |
| Fix for medium/low severity | Next scheduled release |

We will keep you informed of progress and coordinate disclosure timing with you.

## Scope and Safe Harbor

In scope: the yhcrames code in this repository and deployments you own or are authorized to
test. Out of scope: denial-of-service testing, social engineering, and systems you do not own,
including any hosted yhcrames instance unless its operator has authorized you.

If you make a good-faith effort to follow this policy, do not access or modify data beyond
what is needed to show the issue, and report it privately, the maintainers will not pursue or
support legal action against you for that research. The safe-harbor wording is a placeholder
until the maintainers confirm it with counsel.

## Security Practices

- **Authentication:** JWT access and refresh tokens with configurable expiry; OIDC, SAML 2.0,
  SCIM 2.0 provisioning, LDAP and Kerberos/SPNEGO. Login and registration are throttled, and
  self-registration is off by default (`AUTH_REGISTRATION_ENABLED`).
- **Authorization:** role-based access control with six tenant roles (admin, architect, steward,
  integrator, author, viewer) plus platform superusers.
- **Tenant isolation:** schema-per-tenant in PostgreSQL (`tenant_*`). For a request carrying a
  tenant JWT, TenantMiddleware lets the token name only its own tenant in `X-Tenant-ID`; a
  request with no JWT (API-key flows such as external MCP) still has the header honoured as
  given, which is a known gap (threat model TM-TEN-02, TM-MCP-05). A caller-supplied
  `tenant_schema` is always pinned to the request tenant. Routers are being audited for object-level scoping: see
  `docs/api/API_REFERENCE.md` and the threat model.
- **Caller-authored SQL:** runs under a per-tenant, read-only PostgreSQL reader role with
  statement timeouts and connection caps (`docs/adr/ADR-004-tenant-reader-roles.md`). The
  application connects as a NOSUPERUSER role.
- **Platform SQL:** values are bound as parameters, and identifiers go through validated
  quoting.
- **Input validation:** Pydantic schemas on request bodies; control characters refused in
  header-bound values.
- **Rate limiting:** policy-driven rate limiting that fails closed, plus signup and invite abuse
  throttles.
- **Data governance:** PII masking, retention policies, consent tracking; an immutable,
  field-level audit trail.
- **Secrets:** read from the environment; production refuses to start with the shipped default
  secrets. Connector, data-source and provider credentials are Fernet-encrypted at rest (when
  kept in the local secrets backend) and redacted from API responses. SCIM bearer tokens are
  redacted from API responses but not yet hashed at rest (threat model TM-AUTH-13).

## Automated Scanning

`scripts/security/run_scanners.sh` runs these scanners:

- bandit;
- custom offline semgrep rules (`.semgrep/yhcrames.yml`);
- pip-audit;
- pnpm audit;
- detect-secrets and gitleaks, when installed.

It compares the results with the committed `docs/security/scanner-baseline.json` and fails only
on new findings. A scanner that itself fails (wrong exit code, or an error document instead of
results, e.g. no network for pnpm audit) makes the run exit `2`; it never counts as clean. `docs/security/scanner-baseline.md` explains the baseline and how to triage a
new finding. Wiring the scan into CI is a pending follow-up.

## Penetration Testing Status

No external penetration test has been performed yet. One is planned (GitLab #26). The readiness
material is in `docs/security/`: the threat model (`docs/security/threat-model.md`) and the
scope and rules of engagement for the testing firm (`docs/security/pentest-scope.md`).

## Known Limitations

The threat model's "Known gaps" section (`docs/security/threat-model.md`) is the complete list
of open issues, each with an ID and its tracking item. The list below is only a partial
summary of the main areas:

- Some feature routers are not yet audited for request-tenant scoping. A wave-2 route guard is
  burning them down; until it is empty, do not assume an object outside the scoped list in
  `docs/api/API_REFERENCE.md` is isolated by tenant.
- Several auth/web dependencies have published advisories at the scanner baseline; upgrades are
  in progress (`docs/security/scanner-baseline.md`).
- With no bearer JWT (API-key flows), TenantMiddleware honours `X-Tenant-ID` as given
  (TM-TEN-02, TM-MCP-05).
- The external MCP API-key check compares the presented key directly with the stored bcrypt
  hash, so real keys do not authenticate there while a leaked hash would (TM-MCP-01).
- SCIM bearer tokens are stored in plaintext and compared without a constant-time check
  (TM-AUTH-13).
- OIDC `state`/`nonce` and SAML assertion replay/audience checks are not yet enforced.
- SAML and OIDC are tested against mocks and the in-repo test suites (including about 430
  PostgreSQL end-to-end tests), not yet against production identity providers.
- Real LLM providers (OpenAI, Anthropic, Azure OpenAI and others) are supported through the
  LLM gateway. Record data sent to them is masked only when `AGENT_FIELD_MASKING_ENABLED=true`.

## Hardening Checklist for Operators

Details are in `deploy/DEPLOYMENT_GUIDE.md`:

- Set every secret (`JWT_SECRET_KEY`, `SECRET_KEY`, `FERNET_KEY`, `DEFAULT_ADMIN_PASSWORD`,
  and a distinct `DB_READER_ROLE_SECRET`) to a random value. Rotate them if they may have
  leaked. Changing `FERNET_KEY` makes stored credentials unreadable: read the guide's
  `FERNET_KEY` note before you rotate it.
- Run the application as the NOSUPERUSER runtime role, and migrations as the owner role
  (section "Database Role").
- Keep `AUTH_REGISTRATION_ENABLED=false` and `SIGNUP_ENABLED=false` unless you need them. When
  you enable signup, configure SMTP, `PUBLIC_BASE_URL`, `MAX_TENANTS` and
  `SIGNUP_GLOBAL_PER_HOUR`.
- Behind a reverse proxy, set `FORWARDED_ALLOW_IPS` to the proxy addresses (never `*`).
- Serve over HTTPS and set `SSO_COOKIE_SECURE=true`.
- Use `APP_ENV=production` on any internet-facing host. Other values seed demo users.
- Publish a monitored contact through `SECURITY_TXT_CONTACT` once you have one.

## Disclosure Policy

We follow coordinated disclosure. Once a fix is released, we will publish a security advisory
in the project repository with full details and credit to the reporter, unless they ask to stay
anonymous.
