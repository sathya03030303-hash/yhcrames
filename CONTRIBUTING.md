# Contributing to yhcrames

Thank you for your interest in contributing to yhcrames. This guide will help you get started.

## Prerequisites

- Python 3.12+ with [Poetry](https://python-poetry.org/)
- Node.js 20+ with [pnpm](https://pnpm.io/)
- Docker & Docker Compose
- PostgreSQL 16 (or use Docker)
- Redis (or use Docker)

## Getting Started

1. Fork the repository and clone your fork:

```bash
git clone https://github.com/<your-username>/yhcrames.git
cd yhcrames
```

2. Start infrastructure services:

```bash
docker compose -f docker/docker-compose.yml up -d postgres redis
```

3. Set up the backend:

```bash
cd backend
poetry install
cp ../.env.example .env   # edit DB credentials as needed
poetry run alembic upgrade head
poetry run uvicorn app.main:app --reload
```

4. Set up the frontend:

```bash
cd frontend
pnpm install
pnpm dev:studio    # http://localhost:3000
pnpm dev:runtime   # http://localhost:3001
```

5. Verify everything works:

```bash
# Backend tests
cd backend && poetry run python -m pytest tests/ -q

# Frontend type check
cd frontend && pnpm typecheck
```

## Development Workflow

1. Create a feature branch from `main`:

```bash
git checkout -b feat/your-feature-name main
```

2. Make your changes, write tests, and ensure all tests pass.
3. Push your branch and open a Pull Request against `main`.
4. Address any review feedback. PRs require at least one approval before merging.

### Branch Naming

Use prefixes that match the change type:

- `feat/` -- new features
- `fix/` -- bug fixes
- `docs/` -- documentation changes
- `refactor/` -- code restructuring
- `test/` -- test additions or fixes

## Backend Development

### Architecture

The backend follows a layered architecture:

- **Routes** (`app/api/v1/`) -- Thin controllers that validate input and delegate to services. Do not put business logic here.
- **Services** (`app/services/`) -- Business logic layer. Each module has its own service class.
- **Repository** (`app/db/repository.py`) -- Generic async CRUD using `BaseRepository`. Use this for all database operations instead of writing raw queries.
- **Models** (`app/models/`) -- SQLModel definitions. Extend `BaseModel` (audit fields) or `SoftDeleteModel` (soft delete + audit).
- **Schemas** (`app/schemas/`) -- Pydantic models for request/response validation.

### Key Patterns

- **Multi-tenant**: Tenant context is resolved via middleware (JWT claims or `X-Tenant-ID` header). Lifecycle tables live in `tenant_{name}` schemas.
- **JSON fields**: Store as TEXT columns using `json.dumps`/`json.loads` in services, not in models.
- **SQLModel columns**: Use `sa_type` + `sa_column_kwargs` for customization. Do NOT use `sa_column=Column(...)` as it creates shared instances that break inheritance.
- **Celery pipeline**: The certification pipeline runs as a Celery task chain -- validate, enrich, match, consolidate, publish, notify.

### Adding a New Module

1. Create model(s) in `app/models/`.
2. Create schema(s) in `app/schemas/`.
3. Create a service in `app/services/`.
4. Create route(s) in `app/api/v1/`.
5. Register the router in `app/main.py`.
6. Generate an Alembic migration: `poetry run alembic revision --autogenerate -m "add your_module tables"`.
7. Write tests in `tests/`.

### Running Tests

```bash
cd backend

# All tests
poetry run python -m pytest tests/ -q

# Unit tests only
poetry run python -m pytest tests/ -q --ignore=tests/e2e --ignore=tests/performance

# E2E tests
bash tests/e2e/run_e2e.sh

# Performance benchmarks (always serial -- see tests/performance/README.md)
bash tests/performance/run_perf.sh

# Parallel run (needs pytest-xdist): everything except tests/performance in
# parallel, then tests/performance serially -- its latency targets are
# wall-clock and must not compete with other workers for the CPU
poetry run python -m pytest tests/ -q -n 4 --dist loadfile --ignore=tests/performance
poetry run python -m pytest tests/performance/ -q

# With coverage
poetry run python -m pytest tests/ --cov=app --cov-report=term-missing
```

## Frontend Development

### Structure

The frontend is an Nx monorepo with three packages:

- **shared** (`frontend/shared/`) -- API clients, auth store, common components. Import via `@yhcrames/shared`.
- **studio** (`frontend/studio/`) -- Design-time app (model designer, rule builder, admin).
- **runtime** (`frontend/runtime/`) -- End-user app (data browser, loads, duplicates, tasks).

### Key Patterns

- Use **Ant Design 5.x** components throughout. Do not introduce other UI libraries.
- Use **React Query** for server state and **Zustand** for client state.
- Import shared code from `@yhcrames/shared` (path alias in `tsconfig.base.json`).
- TypeScript strict mode is enabled for both apps. All code must compile cleanly.

### Running Frontend

```bash
cd frontend
pnpm install
pnpm dev:studio      # Studio on port 3000
pnpm dev:runtime     # Runtime on port 3001
pnpm typecheck       # Type check all packages
pnpm lint            # Lint all packages
```

## Code Style

### Python

- Formatter/linter: **ruff** (configured in `pyproject.toml`).
- Run before committing: `poetry run ruff check . --fix && poetry run ruff format .`
- Follow existing patterns in the codebase for consistency.

### TypeScript

- TypeScript strict mode enabled. No `any` types unless absolutely necessary.
- ESLint + Prettier configured in the Nx workspace.
- Run before committing: `pnpm lint && pnpm typecheck`

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short description>

[optional body]
```

Types:

- `feat` -- new feature
- `fix` -- bug fix
- `docs` -- documentation only
- `refactor` -- code change that neither fixes a bug nor adds a feature
- `test` -- adding or updating tests
- `chore` -- build process, dependencies, CI changes

Examples:

```
feat: add bulk import endpoint for reference data
fix: resolve tenant UUID resolution in middleware
docs: update API module counts in README
test: add E2E tests for matching pipeline
refactor: extract survivorship logic into strategy classes
```

## Testing Requirements

All PRs must:

1. Pass the existing test suite (`poetry run python -m pytest tests/ -q`).
2. Include tests for new functionality.
3. Not decrease overall code coverage.
4. Pass TypeScript type checking if frontend changes are included.

## Reporting Issues

Open a GitHub issue with:

- A clear title describing the problem.
- Steps to reproduce.
- Expected vs. actual behavior.
- Environment details (OS, Python version, Node version).

## Questions?

Open a discussion on GitHub or reach out to the maintainers.
