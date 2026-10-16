# Implementation Plan and Release Gates

## Implemented scaffold

- React/Vite UI and standalone prototype
- Express API with opportunity fallback data and deterministic eligibility route
- FastAPI pitch-analysis service, PDF/PPTX extraction and 20 specialist roles orchestrated with LangGraph
- PostgreSQL schema for profiles, analyses, evidence claims, opportunities, rules, evaluations, applications and audit events
- Docker Compose development setup

## Required next work

1. Run install/build/typecheck for all workspaces and add CI.
2. Implement authentication, sessions, authorization and tests for owner/admin boundaries.
3. Add private object storage and file lifecycle controls; avoid long-lived public deck links.
4. Add verified opportunity ingestion, reviewer approval queue, source snapshots and deadline monitoring.
5. Add background analysis jobs, persisted analysis states, retry/recovery and user-visible progress.
6. Add application document workflows, email notifications, deadline alerts and deduplication.
7. Improve PPTX visual rendering, image-only deck handling, file malware scanning and resource limits.
8. Add observability, secret management, rate limits, backup/recovery and a production deployment guide.

## Release gate

Do not advertise the catalogue as live or verified until every published opportunity has a current official source and has been reviewed. Do not accept sensitive real-world decks before authentication, storage authorization, retention and incident-handling controls are in place.
