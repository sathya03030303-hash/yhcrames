# yhcrames

Open-source Master Data Management platform — Semarchy xDM-class capabilities at a fraction of the cost.

## What is yhcrames?

yhcrames is a model-driven MDM platform that creates governed, certified, and AI-ready master data for enterprise domains (customer, product, supplier, location, reference). It supports the full certification lifecycle:

**Ingest → Validate → Enrich → Match/Merge → Stewardship → Consolidate → Publish → Notify → Monitor**

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Frontend (React / Ant Design)              │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │    Studio     │  │    Runtime    │  │     Shared       │ │
│  │ Model Design  │  │  Data Ops     │  │  API clients,    │ │
│  │ Rule Builder  │  │  Loads/Dup    │  │  Auth store,     │ │
│  │ Admin         │  │  Errors/Audit │  │  Components      │ │
│  │              │  │  Tasks/Dash   │  │                  │ │
│  └──────────────┘  └───────────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                     REST API (JWT)
                           │
┌─────────────────────────────────────────────────────────────┐
│               Backend (FastAPI + SQLModel)                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐  │
│  │ Metamodel│ │   Load   │ │Validation│ │ Match/Merge   │  │
│  │ Engine   │ │  Manager │ │  Engine  │ │ + Consolidate │  │
│  ├──────────┤ ├──────────┤ ├──────────┤ ├───────────────┤  │
│  │Enrichment│ │   Data   │ │  Audit   │ │  SQL API      │  │
│  │ Pipeline │ │  Service │ │  Trail   │ │  + CSV I/O    │  │
│  ├──────────┤ ├──────────┤ ├──────────┤ ├───────────────┤  │
│  │ Named    │ │ Notifi-  │ │ Workflow │ │  Monitoring   │  │
│  │ Queries  │ │ cations  │ │ Engine   │ │  + Health     │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Celery Pipeline (validate→enrich→match→consolidate) │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
    PostgreSQL 16     Redis (Queue)    Flower (Monitor)
   (schema-per-tenant)
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Python 3.12+, FastAPI, SQLModel, Alembic |
| Task Queue | Celery + Redis |
| Frontend | React 18, TypeScript, Ant Design 5.x, Nx monorepo |
| Database | PostgreSQL 16 (schema-per-tenant isolation) |
| Auth | JWT + OIDC |
| Dev | Docker Compose |

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Node.js 20+ with pnpm
- Python 3.12+ with Poetry

### Backend

```bash
cd backend
poetry install
cp ../.env.example .env      # edit as needed
docker compose -f ../docker/docker-compose.yml up -d postgres redis
poetry run uvicorn app.main:app --reload
```

### Frontend

```bash
pnpm install
pnpm dev:studio    # http://localhost:3000
pnpm dev:runtime   # http://localhost:3001
```

### Full Stack (Docker)

```bash
docker compose -f docker/docker-compose.yml up -d
```

- Backend API: http://localhost:8000/docs
- Studio: http://localhost:3000
- Runtime: http://localhost:3001
- Flower (Celery monitor): http://localhost:5555

### Default Credentials

- Username: `admin`
- Password: `change-me-in-production`

Change the password immediately — with `app_env=production` the server refuses to boot while it holds the default. To create and manage additional tenants (console wizard, API, self-service signup) and for the guided first-run experience, see the [Tenant Onboarding Guide](docs/site/docs/tenant-onboarding-guide.md).

## API Modules (2,700+ endpoints across 248 route modules)

| Module | Endpoints | Description |
|--------|-----------|-------------|
| auth | 4 | JWT login, refresh, register, profile |
| tenants | 5 | Tenant CRUD + schema provisioning |
| users | 4 | User management with RBAC |
| metamodel | 19 | Domains, entities, attributes, relationships, DDL gen, YAML export |
| schema | 3 | Deploy/drop lifecycle tables in tenant schemas |
| loads | 7 | Batch load lifecycle (init → load → submit → cancel) |
| validation | 8 | Rule engine (required/regex/range/length/enum/custom), error recycle |
| enrichment | 5 | Pipeline with built-in enrichers + plugin hooks |
| data | 5 | Golden record browse/search, SA authoring, history |
| audit | 3 | Immutable field-level change tracking |
| sql | 4 | Bulk insert, SQL-like query, CSV import/export |
| matching | 8 | Fuzzy matching, duplicate groups, merge/dismiss |
| consolidation | 2 | Survivorship strategies (9 policies), golden record generation |
| named-queries | 10 | Parameterized custom endpoints, versioning, slug-based execution |
| notifications | 10 | Webhook/email channels, event triggers, delivery logs, manual fire |
| workflows | 12 | Step definitions with SLA, instances, task claim/act, escalation |
| monitoring | 4 | Load/validation/matching stats, system health |

## Data Model

### System Tables (public schema)

| Table | Purpose |
|-------|---------|
| tenants | Tenant registry |
| users | User accounts with RBAC (6 roles) |
| domains | Domain definitions (Customer, Product, etc.) |
| entities | Entity definitions within domains |
| attributes | Column definitions per entity |
| entity_relationships | Relationships between entities |
| loads / load_records | Batch load tracking |
| validation_rules / validation_errors | Rule definitions and error queue |
| enrichers / enrichment_logs | Enricher registry and execution logs |
| match_rules | Match rule definitions (exact/levenshtein) |
| duplicate_groups / duplicate_candidates | Duplicate detection results |
| merge_decisions | Steward merge/split audit |
| audit_entries | Immutable change audit trail |
| named_queries | Parameterized custom endpoint definitions |
| notification_channels | Webhook/email delivery channels |
| notification_triggers | Event-based notification rules |
| notification_logs | Delivery attempt tracking |
| workflow_definitions | Multi-step workflow with SLA/escalation |
| workflow_instances | Running workflow instances |
| workflow_tasks | Assigned stewardship tasks |

### Lifecycle Tables (per-tenant schema)

Each entity generates 11+ lifecycle tables:

| Prefix | Purpose |
|--------|---------|
| SA | Source Authoring (manual/override) |
| SD | Source Data (loaded from publishers) |
| AE/SE/GE | Error tables (authoring/source/golden) |
| MD/MH/MX | Master data + history + soft deletes |
| GD/GH/GX | Golden data + history + soft deletes |
| DU/UM | Duplicate management (fuzzy-match entities) |

System columns on every lifecycle table: `B_LOADID`, `B_CLASSNAME`, `B_PUBID`, `B_CREATOR`, `B_CREDATE`, `B_UPDATOR`, `B_UPDDATE`, `B_SOURCEID`

## Frontend Apps

### Studio (Design-time)

- **Model Designer** — Domain/entity/attribute CRUD, strategy selection, schema deployment, DDL preview
- **Rule Builder** — Validation rule CRUD with dynamic config (required/regex/range/length/enum/custom/expression), severity, toggle active
- **Administration** — User management with RBAC, create/edit/toggle users

Additional implemented Studio pages include App Builder, Workflow Designer, Named Query Editor, Notification Config, Plugin Manager, Reference Data, Scheduler, Ingestion Sources, AI Enrichers, and Event Streaming (~59 pages total).

### Runtime (End-user)

- **Dashboard** — Load/validation/matching stats overview with aggregate counts and status breakdowns
- **Data Browser** — Domain/entity selector, golden record table with search/sort/pagination, record detail drawer
- **Data Loads** — Load lifecycle management (create/submit/cancel), entity filter, record counts, detail drawer
- **Duplicate Manager** — Duplicate group browser with merge/dismiss, candidate comparison, master record selection
- **Error Queue** — Validation error browser with correct/dismiss actions, entity/status filters
- **My Tasks** — Workflow task inbox with claim/approve/reject actions, SLA tracking, status filters
- **Audit Trail** — Field-level change history viewer, search by entity or record UUID, action type filters

## Certification Pipeline

The Celery pipeline processes loads through these stages:

1. **Pre-validation** — Run validation rules, route errors to error tables
2. **Pre-enrichment** — Standardize/augment records (text, email, phone, name, address)
3. **Matching** — Identify duplicates using configurable match rules (exact/levenshtein)
4. **Consolidation** — Apply survivorship policies (most_recent/most_frequent/source_priority/longest/smallest/manual/custom_ranking/preferred_publisher/ai), generate master/golden records
5. **Post-enrichment** — Post-processing enrichers
6. **Post-validation** — Validate golden records
7. **Publish** — Expose via GD tables and APIs
8. **Notify** — Fire notification triggers to webhook/email channels

## Multi-Tenancy

- Schema-per-tenant isolation in PostgreSQL (`tenant_{name}` schemas)
- Tenant resolved from JWT claims or `X-Tenant-ID` header
- Each tenant gets its own set of lifecycle tables
- System tables live in the `public` schema

## Roles

| Role | Access |
|------|--------|
| admin | Full access, tenant management |
| architect | Model design, rule configuration, schema deployment, workflow design |
| steward | Data quality, duplicate resolution, error correction, task completion |
| integrator | Load management, SQL API, CSV import, named query execution |
| author | Data authoring (SA table writes) |
| viewer | Read-only browse and search |

## Project Structure

```
yhcrames/
├── backend/
│   ├── app/
│   │   ├── api/v1/          # 248 route modules (2,700+ endpoints)
│   │   ├── core/            # Config, auth, tenant, logging
│   │   ├── db/              # Session management, repository pattern
│   │   ├── models/          # 91 SQLModel definitions
│   │   ├── schemas/         # Pydantic request/response models
│   │   ├── services/        # 263 business logic services
│   │   ├── tasks/           # Celery pipeline (8-stage certification)
│   │   └── plugins/         # Plugin infrastructure
│   ├── alembic/             # Database migrations
│   ├── tests/               # Test suite
│   └── pyproject.toml
├── frontend/
│   ├── shared/              # 65+ API clients, auth store, components
│   ├── studio/              # ~59 pages (all implemented)
│   └── runtime/             # ~27 pages (all implemented)
├── docker/
│   ├── docker-compose.yml
│   ├── Dockerfile.backend
│   └── init-db.sql
├── packages/
│   └── common/              # Shared TypeScript types
├── nx.json
├── package.json
└── tsconfig.base.json
```

## License

Apache-2.0
