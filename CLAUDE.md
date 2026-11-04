# yhcrames - Development Guide

## Project Overview
yhcrames = open-source MDM (Master Data Management) platform, inverse of "Semarchy".
Semarchy xDM-class capabilities: model-driven, certification lifecycle, stewardship workflows.

## Tech Stack
- **Backend**: Python 3.12+, FastAPI, SQLModel, Alembic, Celery + Redis
- **Frontend**: React 18, TypeScript, Ant Design 5.x, Nx monorepo
- **Database**: PostgreSQL 16 with schema-per-tenant isolation
- **Auth**: JWT (access + refresh tokens), OIDC SSO, SAML 2.0, SCIM 2.0, Kerberos/SPNEGO, LDAP

## Key Architecture Decisions
- **Multi-tenant**: schema-per-tenant in PostgreSQL (`tenant_{name}` schemas)
- **Repository pattern**: `backend/app/db/repository.py` — generic async CRUD
- **Model storage**: DB primary, YAML export for version control
- **Lifecycle tables**: SA_, SD_, AE_, SE_, GE_, MD_, MH_, MX_, GD_, GH_, GX_, DU_, UM_
- **System columns**: B_LOADID, B_CLASSNAME, B_PUBID, B_CREATOR, B_CREDATE, B_UPDATOR, B_UPDDATE, B_SOURCEID
- **Pipeline**: Celery task chain — validate → enrich → match → consolidate → publish → notify

## Running the Project
```bash
# Backend
cd backend && poetry install && poetry run uvicorn app.main:app --reload

# Frontend
pnpm install && pnpm dev:studio  # port 3000
pnpm dev:runtime                  # port 3001

# Docker (full stack)
docker compose -f docker/docker-compose.yml up -d
```

## Backend Conventions
- Services in `backend/app/services/` contain business logic (263 top-level services; `ls backend/app/services/*.py | wc -l`)
- API routes in `backend/app/api/v1/` — thin controllers delegating to services (248 routers)
- Models in `backend/app/models/` — SQLModel with BaseModel (audit fields) or SoftDeleteModel (91 models)
- Schemas in `backend/app/schemas/` — Pydantic for request/response validation
- Use `BaseRepository` for all DB operations (don't write raw queries in routes)
- Tenant context resolved via middleware or JWT claims
- JSON fields (parameter_schema, steps, config) stored as TEXT with json.dumps/loads in services

## Frontend Conventions
- Shared library at `frontend/shared/` — 40+ API clients, stores, common components, theme, i18n, a11y
- Import from `@yhcrames/shared` (path alias in tsconfig.base.json)
- Use React Query for server state, Zustand for client state
- Ant Design components throughout — don't introduce other UI libraries
- TypeScript strict mode — both apps compile cleanly

## Backend Modules
| Module | Service | Key Operations |
|--------|---------|----------------|
| auth | AuthService | JWT tokens, password hashing, user CRUD |
| tenants | TenantService | CRUD + schema provisioning |
| metamodel | MetamodelService | Domain/Entity/Attribute/Relationship CRUD, DDL gen, YAML export |
| schema | SchemaDeploymentService | Deploy lifecycle tables + DU/UM + indexes |
| loads | LoadService | Batch lifecycle (init/load/submit/cancel) |
| validation | ValidationService | Rule CRUD, validate_record/load, error correction |
| enrichment | EnrichmentService | 5 built-in enrichers + expression enricher |
| data | DataService | Dynamic SQL on lifecycle tables (GD browse, SA authoring) |
| audit | AuditService | Immutable field-level change tracking |
| sql | SqlApiService | Bulk insert SD, query GD, CSV import/export |
| matching | MatchingService | Fuzzy matching (levenshtein/exact), duplicate groups, merge/dismiss |
| consolidation | ConsolidationService | 9 survivorship strategies, master/golden record generation |
| named-queries | NamedQueryService | Parameterized endpoints, versioning, slug execution |
| notifications | NotificationService | Webhook/email delivery, event triggers, retry tracking |
| workflows | WorkflowService | Multi-step definitions, task routing, SLA, claim/act |
| monitoring | — (inline) | Load/validation/matching stats, system health |
| backup | BackupService | Tenant/system config export, import with upsert, snapshots |
| plugins | PluginService | Plugin CRUD, Docker sandbox execution, health checks |
| oidc | OIDCService | OIDC discovery, token exchange, user provisioning |
| lineage | LineageService | Field-level provenance, chain tracing, source impact analysis |
| reference-data | ReferenceDataService | Code lists, lookup values, import/export, bulk operations |
| scheduler | SchedulerService | Cron/interval/once jobs, execution tracking, manual trigger |
| hierarchy | HierarchyService | Tree views, parent-child navigation, relationship graphs |
| data-quality | DataQualityService | Scorecards, 5 quality dimensions, entity scoring, trends |
| app-builder | AppBuilderService | Form/view designer, field config, auto-generate, publish/clone |
| ingestion | IngestionService | Webhook CDC, field mapping, transforms, buffer management |
| ai-enricher | AIEnricherService | GenAI enrichment (5 types), multi-provider, prompt templates, batch |
| event-streaming | EventStreamingService | Kafka/JMS/RabbitMQ/Redis streams, publish, retry, DLQ, metrics |
| saml | SAMLService | SAML 2.0 SSO, IdP config, ACS/SLO, metadata import, session mgmt |
| migrations | MigrationService | Alembic migrations, upgrade/downgrade/stamp, tenant schema support |
| security | SecurityPolicyService | Row filters, attribute masking/hiding/readonly, data classifications |
| rate-limits | RateLimitService | Per-tenant/user/role rate limiting, API quotas, middleware |
| data-governance | DataGovernanceService | Retention policies, PII masking (6 types), consent tracking |
| alerts | AlertService | 14 built-in metrics, configurable thresholds, severity/escalation, silences |
| excel | ExcelService | Pure-Python XLSX generation/parsing, template export, multi-sheet domain export |
| model-versions | ModelVersionService | Snapshot/compare/restore, environment promotion workflow |
| workflow-comments | WorkflowCommentService | Threaded comments, approval chains (sequential/parallel/any-of) |
| conditional-rules | ConditionalRuleService | AND/OR/NOT expression trees, 13 operators, applies to validation/enrichment |
| scim | SCIMService | SCIM 2.0 inbound/outbound provisioning, group-to-role mapping |
| observability | ObservabilityMiddleware | Prometheus metrics, W3C trace context, component health |
| certification | CertificationService | Approval chains, escalation, recertification |
| federated-matching | FederatedMatchingService | Privacy-preserving cross-source matching |
| ipaas | iPaaSIntegrationService | Webhook management, HMAC verification, batch delivery |
| mcp-marketplace | MCPMarketplaceService | Tool package publishing, discovery, installation |
| cache | CacheService | Redis cache-aside pattern for golden records |
| graphql | GraphQLService | Full schema generation, introspection, query execution |
| ha | HAService | Leader election, heartbeat manager, failover |
| connectors | ConnectorService | HubSpot, Kafka, Oracle, S3, ServiceNow, SQL Server, Workday |
| azure-servicebus | AzureServiceBusService | Event streaming to Azure Service Bus |
| warehouse-pushdown | WarehousePushdownService | SQL dialect translation for Snowflake/BigQuery/Redshift |
| purview | PurviewConnectorService | Microsoft Purview bidirectional catalog sync |
| partner-integrations | Experian/MelissaService | Address, email, phone, identity verification |
| kerberos | KerberosAuthService | SPNEGO/Kerberos integrated Windows authentication |
| search | SearchEngineService | PostgreSQL full-text search, faceted navigation, autocomplete |
| gdpr | GDPRComplianceService | DSAR, right-to-erasure, consent, data residency, compliance scoring |
| ml-matching | MLMatchingService | Logistic regression trained from steward decisions |
| cdc-streaming | CDCStreamingService | PostgreSQL, MySQL, MongoDB change data capture |
| bi-connector | BIConnectorService | OData v4, Tableau WDC, Looker LookML |
| i18n | I18nService | Multi-language support (6 locales), locale-aware formatting |
| impact-analysis | ImpactAnalysisService | Source change simulation, COPQ analysis, dependency graphs |
| collaboration | CollaborationService | WebSocket presence, record locking, conflict resolution |
| data-contracts | DataContractService | Schema versioning, breaking change detection, SLA monitoring |
| data-products | DataProductService | Data mesh primitives, product lifecycle, SLA monitoring |
| usage-metering | UsageMeteringService | SaaS plans, quota enforcement, billing stubs |
| disaster-recovery | DisasterRecoveryService | Backup verification, PITR, failover, DR drills |
| admin-console | AdminConsoleService | System health, resource utilization, session management |
| data-dictionary | DataDictionaryService | Auto-generated docs, ERD (Mermaid/PlantUML/DOT) |
| workflow-templates | WorkflowTemplateService | 7 pre-built templates, 1-click install |
| graph-visualization | GraphVisualizationService | Entity/duplicate/lineage/hierarchy graph rendering |
| api-analytics | APIAnalyticsService | Token bucket rate limiting, latency distributions, deprecation |
| smoke-tests | SmokeTestService | Liveness/readiness probes, synthetic transactions |
| anomaly-detection | AnomalyDetectionService | Z-score, IQR, isolation forest, time series anomalies |
| query-optimizer | QueryOptimizerService | Slow query detection, index suggestions, bloat analysis |
| event-sourcing | EventSourcingService | Append-only event store, projections, CQRS |
| nl-query | NLQueryService | Natural language to SQL translation |
| knowledge-graph | KnowledgeGraphService | Property graph, SPARQL queries, RDF/JSON-LD export |
| automation-builder | AutomationBuilderService | No-code trigger→condition→action chains |
| entity-resolution | EntityResolutionService | Real-time and batch entity resolution as a service |
| export-pipeline | ExportPipelineService | Multi-step ETL with 6 target connectors |
| data-observability | DataObservabilityService | Freshness, volume, drift, pipeline SLA monitoring |
| ai-copilot | AICopilotService | Contextual suggestions, NL commands, action learning |
| data-marketplace | DataMarketplaceService | Data product listings, pricing, subscriptions |
| compliance-as-code | ComplianceAsCodeService | YAML policy definitions, automated enforcement |
| data-sre | DataSREService | SLO/SLI, error budgets, chaos engineering stubs |
| semantic-layer | SemanticLayerService | Business terms, calculated metrics, dimensional hierarchies |
| data-versioning | DataVersioningService | Record snapshots, branching, merge, time-travel |
| extensions | ExtensionService | 15 hook points, extension registry, chain execution |
| api-gateway | APIGatewayService | Circuit breaker, retry, caching, canary deployments |
| synthetic-data | SyntheticDataService | Privacy-safe synthetic record generation |
| self-healing | SelfHealingService | Pipeline failure detection, auto-remediation |
| clean-rooms | CleanRoomService | Privacy-preserving multi-party data collaboration |
| federated-learning | FederatedLearningService | Cross-tenant model training with differential privacy |
| digital-twins | DigitalTwinService | Twin registry, state sync, IoT ingestion, simulation |
| gamification | GamificationService | Points, badges, leaderboards, streaks, team competitions |
| field-encryption | FieldEncryptionService | AES-256-GCM, key rotation, deterministic search |
| sovereignty-router | SovereigntyRouterService | Jurisdiction classification, cross-border controls |
| entity-360 | Entity360Service | Unified record view across all data dimensions |
| master-index | MasterIndexService | Cross-domain unified identifier index |
| quality-sla | QualitySLAService | Contractual quality guarantees with escalation |

## Important Files
- PRD: `MDM_Product_PRD_v2_2026-02-17.md`
- Backlog: `MDM_Product_Backlog_v2_2026-02-17.csv`
- Backend entry: `backend/app/main.py`
- Config: `backend/app/core/config.py`
- Repository: `backend/app/db/repository.py`
- Pipeline: `backend/app/tasks/pipeline.py`
- Consolidation: `backend/app/services/consolidation.py`
- Workflow: `backend/app/services/workflow.py`

## Testing

### Backend Tests
- **Unit tests**: 14,900+ tests in `backend/tests/` across 430+ test files (SQLite-based); count with `poetry run python -m pytest tests/ --collect-only -q`
- **E2E tests**: 186 tests in `backend/tests/e2e/` (PostgreSQL-based, tenant isolation, pipeline, concurrency)
- **Performance tests**: 21 benchmarks in `backend/tests/benchmarks/` (matching, pipeline, API, memory). NOTE: files are named `benchmark_*.py`, which pytest's default `test_*.py` pattern does not collect — run them via `tests/benchmarks/run_benchmarks.sh` after adding `python_files = ["test_*.py", "benchmark_*.py"]` to `[tool.pytest.ini_options]` in `pyproject.toml`
- **Locust load tests**: `backend/tests/performance/locustfile_extended.py` (10 user behavior classes)
- Run all: `poetry run python -m pytest tests/ -q`
- Run E2E only: `bash tests/e2e/run_e2e.sh`
- Run perf only: `bash tests/performance/run_perf.sh`

### Frontend Tests
- **Unit tests**: Vitest + React Testing Library in `frontend/shared/src/**/*.test.{ts,tsx}`
- **Coverage threshold**: enforced in `vitest.config.ts` at 85% statements/functions/lines, 75% branches — measured only over the hand-picked `coverage.include` list (~14 component/hook/store paths), not the whole shared library
- **E2E tests**: Playwright in `e2e/*.spec.ts` (auth, accessibility, UI components, page navigation, CRUD, API health)
- **Test setup**: `frontend/shared/src/test/setup.ts` (jsdom, mocks)
- **Test utils**: `frontend/shared/src/test/test-utils.tsx` (providers wrapper)
- Run unit tests: `npx vitest run`
- Run with coverage: `npx vitest run --coverage`
- Run E2E: `npx playwright test`
- Run single test file: `npx vitest run path/to/file.test.tsx`

### Testing Skills (Auto-invocable)
- `/test-unit` — Run frontend unit tests with coverage
- `/test-e2e` — Run Playwright E2E tests
- `/test-all` — Run TypeScript check + unit tests + coverage (pre-commit validation)

### Testing Policy
- All new shared components MUST have unit tests (meet the `vitest.config.ts` thresholds: 85% statements/functions/lines, 75% branches)
- All new pages SHOULD have integration tests for key interactions
- Tests MUST pass before any commit is marked as complete
- Coverage MUST NOT drop below the `vitest.config.ts` thresholds (85% statements/functions/lines, 75% branches) for the paths in its `coverage.include` list

## Alembic Migrations
- Config: `backend/alembic.ini`
- Scripts: `backend/alembic/versions/`
- For an existing DB that the app built with create_all and never stamped: `alembic stamp 039`, then `python scripts/schema_drift.py --apply`, then `alembic upgrade head` — never `alembic stamp head` (it would skip migrations 040+; see deploy/DEPLOYMENT_GUIDE.md step 4a)
- For fresh DB: `alembic upgrade head`
- New migration: `alembic revision --autogenerate -m "description"`
- API: `POST /api/v1/migrations/upgrade`, `/downgrade`, `/stamp`, `/history`

## Deployment
- **Docker**: Production Dockerfiles at `docker/` (backend, frontend, celery)
- **Docker Compose**: `docker/docker-compose.production.yml` with Nginx, PostgreSQL, Redis
- **Helm**: Full Kubernetes chart at `deploy/helm/yhcrames/` (21 templates)
- **CI/CD**: GitHub Actions at `.github/workflows/` (CI, CD, Release)
- **IaC**: AWS CloudFormation, Azure Bicep, GCP Terraform at `deploy/`
- **Monitoring**: 5 Grafana dashboards at `deploy/grafana/`

## SDKs
- **Python**: `sdks/python/` — sync + async client (httpx)
- **TypeScript**: `sdks/typescript/` — fetch-based client
- **Go**: `sdks/plugin-go/` — JSON-RPC plugin SDK
- **Java**: `sdks/plugin-java/` — HttpServer-based plugin SDK
- **Node.js**: `sdks/plugin-node/` — TypeScript plugin SDK

## Documentation
- **API Reference**: `docs/api/API_REFERENCE.md`
- **Documentation Site**: `docs/site/` (MkDocs Material)
- **Deployment Guide**: `deploy/DEPLOYMENT_GUIDE.md`

## Remaining Work (Future)
- Real provider integration testing (connect to actual Kafka/Snowflake/Salesforce)
- Production load testing at scale (100M+ records)
- Security penetration testing
- UI/UX polish and user testing
- Documentation review and tutorials
