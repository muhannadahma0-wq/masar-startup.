# Architecture

## Stack

- Web: React, TypeScript, Vite, Lucide icons; Arabic RTL is the initial display direction.
- API: Node.js, Express, TypeScript, Zod, PostgreSQL.
- Pitch analyzer: Python 3.12, FastAPI, Pydantic, LangGraph, OpenAI Responses API.
- Data: PostgreSQL + JSONB for analysis artifacts; optional pgvector for source-linked retrieval.
- Local services: Docker Compose.

## Boundaries

The Node API owns HTTP entry points, upload validation, opportunity queries, eligibility rules and public application workflow. The Python service only extracts/analyses the pitch deck and returns a report; it must not directly modify PostgreSQL. The service-to-service endpoint is token protected. Configure `PITCH_SERVICE_TOKEN` to the same strong secret in both containers.

## Eligibility engine

Mandatory rules are deterministic. Any confirmed mandatory failure yields `NOT_ELIGIBLE`; a missing mandatory value yields `UNCERTAIN`; otherwise the result is `ELIGIBLE`. Fit scores never override the outcome. Each published opportunity should have an official source, last-verified date, explicit geography criteria and approval history.

## Agent workflow

LangGraph fans out to twenty bounded specialist roles, limits provider concurrency, then synthesizes the independent outputs. The roles are tasks executed by a configured model, not twenty separate trained models. One agent failure should not prevent other results from being reviewed. If the API key or model configuration is unavailable, live analysis cannot run.

## Deployment boundaries

The compose file is for local development only. Before production, add user authentication and object-level authorization, private object storage, background jobs, source review UI, notification delivery, monitoring, rate limiting, HTTPS and tested backup/recovery. Keep `.env` files and pitch decks out of Git.
