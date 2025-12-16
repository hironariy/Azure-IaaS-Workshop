---
Date: 2025-12-16
Reviewer: GitHub Copilot (GPT-5.1-Codex-Max Preview)
Scope: materials/backend (Express + MongoDB API)
---
# Backend Security Review – Azure IaaS Workshop

## Summary
Security posture is generally solid (rate limiting, helmet, centralized errors, JWT-based auth), but three issues require attention before workshop use: token audience/scope laxness, stored content sanitization, and unrestricted detailed health endpoints.

## Findings

### 1) Accepts non-API Entra tokens (High)
- Update: Audience was tightened to the API URI (`api://<client-id>`). This blocks SPA ID tokens from being accepted by the API.
- Remaining gap: scopes/roles are still not enforced (intentional for workshop simplicity). If you raise the bar later, assert `scp`/`roles` before attaching `req.user`.
- Evidence: [materials/backend/src/middleware/auth.middleware.ts#L83-L113](materials/backend/src/middleware/auth.middleware.ts#L83-L113)

### 2) Stored XSS via unsanitized rich text (High)
- Update: Server-side sanitization added using DOMPurify/JSdom in post, comment, and user routes; raw inputs are sanitized before persistence.
- Evidence: [materials/backend/src/routes/posts.routes.ts](materials/backend/src/routes/posts.routes.ts), [materials/backend/src/routes/comments.routes.ts](materials/backend/src/routes/comments.routes.ts), [materials/backend/src/routes/users.routes.ts](materials/backend/src/routes/users.routes.ts), sanitizer in [materials/backend/src/utils/sanitize.ts](materials/backend/src/utils/sanitize.ts)
- Residual risk: Allowlist is limited but still permits basic HTML. If you need stricter control, store raw markdown plus sanitized render, and expand tests to cover malicious payloads.

### 3) Detailed health endpoint exposed publicly (Medium)
- `/health/detailed` (and `/ready`) return DB state, uptime, and memory without authentication; this leaks operational data if exposed externally.
- Evidence: [materials/backend/src/routes/health.routes.ts#L13-L63](materials/backend/src/routes/health.routes.ts#L13-L63)
- Recommendation: Restrict these endpoints to internal callers (IP allowlist, auth middleware, or bind to an internal-only listener). Keep `/health` minimal for load balancer probes.

## Next Steps
1) Tighten JWT validation: API-only audience + scope/role checks; update docs and tests.
2) Add server-side sanitization/encoding for stored user content; re-scan existing data if any.
3) Lock down detailed health/readiness endpoints to internal traffic only.
4) Re-run automated tests and a quick penetration test of auth and content flows after fixes.
