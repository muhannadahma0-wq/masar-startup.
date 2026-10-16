# Masar Startup — مَسار للشركات الناشئة

**من فكرة إلى مشروع جاهز للنمو والتمويل.**

Masar Startup is a bilingual founder workspace that brings together pitch-deck review, startup profile preparation, funding-opportunity discovery, evidence-backed eligibility checks, and application tracking. The initial intended audience is Palestinian founders; international eligibility must be confirmed from official program criteria rather than inferred from an opportunity's name.

> **Status:** early-stage scaffold and interactive prototype. Do not treat the included opportunity examples as live funding offers. Live pitch analysis requires a configured model API key. Authentication, private object storage, source-verification workflows, notifications, and production hardening remain incomplete.

## Repository structure

- `apps/web` — React + TypeScript + Vite frontend (Arabic-first RTL with an English toggle).
- `apps/api` — Express + TypeScript API, upload validation, opportunity endpoint, and deterministic eligibility engine.
- `services/pitch-analyzer` — FastAPI service for PDF/PPTX extraction and a LangGraph workflow with twenty specialist review roles.
- `db/schema.sql` — PostgreSQL + pgvector schema for profiles, analyses, evidence claims, opportunities, eligibility rules, applications, notifications, and audit history.
- `docs/` — product brief, architecture, specialist roster, UX notes, research decisions, and implementation plan.
- `prototype.html` — lightweight standalone HTML prototype.

The twenty specialist roles are model-driven tasks—not twenty separately trained models—and can only make live provider calls when credentials and valid model names are configured. Their results are draft analysis and require founder review.

## Run the web app locally

Requires Node.js 20+ (Node 22 recommended).

```bash
npm install
npm run dev:web
```

Open `http://localhost:5173`. Without an API base URL, the app is a demo experience and will show an explicitly labelled illustrative report.

## Run all services with Docker Compose

1. Copy `.env.example` to `.env`.
2. Set `OPENAI_API_KEY` and replace `PITCH_SERVICE_TOKEN` with a long random secret. The API and pitch-analyzer containers must use the same token.
3. Start the stack:

```bash
docker compose up --build
```

The web UI is served on port `5173`, the Node API on `4000`, PostgreSQL on `5433` on the host, and the internal analyzer on `127.0.0.1:8000`. Do not expose the analyzer publicly.

## Local services

```bash
# Node API (after npm install)
npm run dev:api

# Python analyzer (Python 3.11+ recommended)
cd services/pitch-analyzer
python -m venv .venv
# Windows PowerShell: .venv\\Scripts\\Activate.ps1
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Configure `DATABASE_URL`, `PITCH_ANALYZER_URL`, `PITCH_SERVICE_TOKEN`, and model credentials as appropriate for the environment. Never commit real `.env` files, model keys, private pitch decks, or user data.

## API outline

- `GET /health` — API health.
- `GET /api/opportunities` — published database records when configured, otherwise clearly labelled illustrative examples.
- `POST /api/eligibility/evaluate` — deterministic three-state rule evaluation.
- `POST /api/pitch-analyses` — PDF/PPTX upload to the internal analyzer.
- Analyzer `GET /health` and token-protected `POST /internal/analyze`.

## Eligibility principles

- Results are `ELIGIBLE`, `NOT_ELIGIBLE`, or `UNCERTAIN`.
- A confirmed mandatory failure gives `NOT_ELIGIBLE`; missing mandatory information gives `UNCERTAIN`.
- Fit ranking must never override a mandatory eligibility rule and is not a prediction of funding success.
- Published opportunity records must have official-source evidence, a last-verified timestamp, geography criteria, and reviewer approval.
- AI suggestions never silently overwrite the founder's pitch or profile.

## Important work before production

Implement and test authentication/authorization, private object storage and retention, background jobs, a reviewer queue for official sources, verified opportunity ingestion, reminders, rate limiting, monitoring, HTTPS, backups, and access-control tests. Do not invite users to upload sensitive decks or rely on deadlines until those safeguards and the opportunity database are complete. See [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md).
