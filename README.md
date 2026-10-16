# Masar Startup — مَسار للشركات الناشئة

**منصة ذكية لتطوير الشركات الناشئة واكتشاف فرص التمويل**

Masar Startup supports founders from pitch-deck review and improvement to evidence-backed funding eligibility checks and application tracking.

## Project status

This repository is being populated from the project archive. The current implementation is an initial scaffold/prototype, not a production-ready SaaS. Live AI analysis requires provider credentials. Sample opportunities must be independently verified before being relied on.

## Main components

- `apps/web`: React + TypeScript + Vite frontend
- `apps/api`: Node.js + Express + TypeScript API, including deterministic eligibility rules
- `services/pitch-analyzer`: FastAPI pitch-analysis service with specialist-agent roles
- `db/schema.sql`: PostgreSQL schema
- `docs/`: product brief, architecture, agent roster, research and implementation plan
- `prototype.html`: standalone interactive prototype

## Run the UI

Requires Node.js 20 or newer.

```bash
npm install
npm run dev:web
```

## Security

Do not commit `.env` files, API keys, or real user pitch decks. Copy `.env.example` to `.env` and configure your own local credentials. Review the implementation notes before public deployment.
