# ============================================================================
# yhcrames — Open-source Master Data Management Platform
# Development Makefile
# ============================================================================

.DEFAULT_GOAL := help

# ----------------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------------
BACKEND_DIR     := backend
FRONTEND_DIR    := frontend
DOCKER_DIR      := docker
COMPOSE_FILE    := $(DOCKER_DIR)/docker-compose.yml
POETRY          := poetry
PNPM            := pnpm

# ----------------------------------------------------------------------------
# Help
# ----------------------------------------------------------------------------
.PHONY: help
help: ## Show this help
	@printf '\nUsage: make \033[36m<target>\033[0m\n\n'
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

# ----------------------------------------------------------------------------
# Installation
# ----------------------------------------------------------------------------
.PHONY: install install-backend install-frontend
install: install-backend install-frontend ## Install all dependencies (backend + frontend)

install-backend: ## Install backend Python dependencies via Poetry
	cd $(BACKEND_DIR) && $(POETRY) install

install-frontend: ## Install frontend Node dependencies via pnpm
	$(PNPM) install

# ----------------------------------------------------------------------------
# Development Servers
# ----------------------------------------------------------------------------
.PHONY: dev-backend dev-studio dev-runtime dev-all
dev-backend: ## Start backend dev server (uvicorn --reload)
	cd $(BACKEND_DIR) && $(POETRY) run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

dev-studio: ## Start Studio frontend (port 3000)
	$(PNPM) dev:studio

dev-runtime: ## Start Runtime frontend (port 3001)
	$(PNPM) dev:runtime

dev-all: ## Start backend + both frontends (requires tmux or run in separate terminals)
	@echo "Run these in separate terminals:"
	@echo "  make dev-backend"
	@echo "  make dev-studio"
	@echo "  make dev-runtime"

# ----------------------------------------------------------------------------
# Testing
# ----------------------------------------------------------------------------
.PHONY: test test-unit test-e2e test-perf
test: ## Run all backend tests
	cd $(BACKEND_DIR) && $(POETRY) run python -m pytest tests/ -q

test-unit: ## Run unit tests only (exclude e2e/ and performance/)
	cd $(BACKEND_DIR) && $(POETRY) run python -m pytest tests/ -q \
		--ignore=tests/e2e --ignore=tests/performance

test-e2e: ## Run E2E tests only
	cd $(BACKEND_DIR) && $(POETRY) run python -m pytest tests/e2e/ -q

test-perf: ## Run performance benchmarks
	cd $(BACKEND_DIR) && $(POETRY) run python -m pytest tests/performance/ -q

# ----------------------------------------------------------------------------
# Code Quality
# ----------------------------------------------------------------------------
.PHONY: lint lint-ruff lint-mypy format
lint: lint-ruff lint-mypy ## Run ruff linter + mypy type checker

lint-ruff: ## Run ruff linter
	cd $(BACKEND_DIR) && $(POETRY) run ruff check app/ tests/

lint-mypy: ## Run mypy type checker
	cd $(BACKEND_DIR) && $(POETRY) run mypy app/

format: ## Auto-format with ruff
	cd $(BACKEND_DIR) && $(POETRY) run ruff format app/ tests/
	cd $(BACKEND_DIR) && $(POETRY) run ruff check --fix app/ tests/

# ----------------------------------------------------------------------------
# Coverage
# ----------------------------------------------------------------------------
.PHONY: coverage coverage-html
coverage: ## Run tests with coverage report
	cd $(BACKEND_DIR) && $(POETRY) run python -m pytest tests/ -q \
		--cov=app --cov-report=term-missing \
		--ignore=tests/performance

coverage-html: ## Generate HTML coverage report
	cd $(BACKEND_DIR) && $(POETRY) run python -m pytest tests/ -q \
		--cov=app --cov-report=html:htmlcov \
		--ignore=tests/performance
	@echo "Coverage report: $(BACKEND_DIR)/htmlcov/index.html"

# ----------------------------------------------------------------------------
# Docker
# ----------------------------------------------------------------------------
.PHONY: docker-up docker-down docker-build docker-logs docker-ps
docker-up: ## Start full stack via Docker Compose
	docker compose -f $(COMPOSE_FILE) up -d

docker-down: ## Stop Docker Compose services
	docker compose -f $(COMPOSE_FILE) down

docker-build: ## Build Docker images
	docker compose -f $(COMPOSE_FILE) build

docker-logs: ## Tail Docker Compose logs
	docker compose -f $(COMPOSE_FILE) logs -f

docker-ps: ## Show running Docker Compose services
	docker compose -f $(COMPOSE_FILE) ps

# ----------------------------------------------------------------------------
# Database
# ----------------------------------------------------------------------------
.PHONY: db-migrate db-downgrade db-history db-seed
db-migrate: ## Run Alembic migrations (upgrade head)
	cd $(BACKEND_DIR) && $(POETRY) run python -m alembic upgrade head

db-downgrade: ## Downgrade one Alembic migration
	cd $(BACKEND_DIR) && $(POETRY) run python -m alembic downgrade -1

db-history: ## Show Alembic migration history
	cd $(BACKEND_DIR) && $(POETRY) run python -m alembic history --verbose

db-seed: ## Seed demo data
	cd $(BACKEND_DIR) && $(POETRY) run python scripts/seed_demo_data.py

# ----------------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------------
.PHONY: clean clean-backend clean-frontend
clean: clean-backend clean-frontend ## Remove build artifacts, caches

clean-backend: ## Clean backend artifacts
	cd $(BACKEND_DIR) && rm -rf __pycache__ .pytest_cache .mypy_cache .ruff_cache htmlcov .coverage
	find $(BACKEND_DIR) -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find $(BACKEND_DIR) -type f -name "*.pyc" -delete 2>/dev/null || true

clean-frontend: ## Clean frontend artifacts
	rm -rf node_modules/.cache
	rm -rf $(FRONTEND_DIR)/studio/dist $(FRONTEND_DIR)/runtime/dist
