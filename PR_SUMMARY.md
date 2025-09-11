# ConwayAPI: REST API, Middleware, Docker, and Test Suite Overhaul

## Overview
This PR introduces a production-ready REST API for Conway's Game of Life using Vapor, improves middleware and validation, fixes Docker build flows for a monorepo, and modernizes the test suite to async XCTVapor with concise helpers.

## Key Changes
- New Swift package `ConwayAPI` with full REST API.
- Middleware: custom error handling, CORS, JSON content type; renamed to avoid Vapor type collisions.
- Validation: clear errors, width/height in invalid responses, grid size caps.
- Docker: fixed build context to include local engine, added curl for health checks.
- Tests: migrated to async XCTVapor, added helpers for status + JSON assertions; cleaned noisy logs.
- Removed misplaced API artifacts from `ConwayGameEngine` (Dockerfiles, configure stub, API_README).

## API Endpoints
- `GET /health` — health check
- `GET /api` — API info + endpoints
- `POST /api/game/step` — compute next generation
- `POST /api/game/simulate` — run N generations + convergence detection
- `POST /api/game/validate` — grid shape validation
- `GET /api/patterns` — list patterns
- `GET /api/patterns/{name}` — pattern detail
- `GET /api/rules` — list rule presets (Conway, HighLife, Day & Night)

## Middleware & Error Handling
- `APIErrorMiddleware` — structured error responses; logs unexpected errors
- `SimpleCORSMiddleware` — permissive defaults for demos; configurable later
- `JSONContentTypeMiddleware` — ensures JSON Content-Type when absent
- ISO-8601 JSON encoding via ContentConfiguration

## Validation
- Grid shape validation with actionable errors
- Error responses include `width` and `height` when invalid
- Grid size caps: default max 200x200 to protect resources

## Docker/Compose
- `ConwayAPI/Dockerfile` builds from repo root and copies local engine
- Runtime image installs `curl`; health checks wired up
- `docker-compose.yml` builds with `context: ..` and proper `dockerfile`

## Tests
- 38 tests across controllers + integration, all passing
- Async test lifecycle (`Application.make`, `asyncShutdown`)
- Helpers: `perform` and `decode` with status + optional JSON assertions
- Reduced vapor logs to warning level during tests

## Risks & Notes
- CORS is permissive; consider env-driven configuration for production
- Grid caps are hard-coded; can be made configurable via env/app storage
- Convergence detector returns period 0 for cycles; future enhancement could compute the true period

## How to Run
- Local: `cd ConwayAPI && swift run conway-api` then `GET /health`
- Tests: `cd ConwayAPI && swift test`
- Docker: `cd ConwayAPI && docker compose up --build`

## Checklist
- [x] Build passes
- [x] Tests pass locally (38/38)
- [x] API docs link fixed
- [x] Docker builds from monorepo
- [x] No Vapor type name shadowing

