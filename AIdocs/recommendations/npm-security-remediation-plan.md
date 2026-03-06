# NPM Security Remediation Plan (Pre-Implementation)

## Purpose
Create a safe, review-first plan to remediate npm dependency vulnerabilities in frontend and backend applications before applying package updates.

## Scope
- Frontend: `materials/frontend`
- Backend: `materials/backend`
- No runtime code changes in this PR
- No dependency version changes in this PR

## Audit Summary
### Frontend (runtime)
- `axios` high severity advisory
- Path: direct dependency
- Current state indicates a fix is available in newer patch release

### Backend (runtime)
- `dompurify` moderate severity advisory
- Path: direct dependency
- `lodash` moderate severity advisory
- Path: transitive via `express-validator`
- `qs` low severity advisory
- Path: transitive via `express`

### Tooling/dev dependency findings
- Additional issues observed in build/lint/test toolchain (for example `minimatch`, `ajv`, `rollup`, `esbuild`, `diff`)
- These will be handled in a controlled second pass to reduce breaking-change risk

## Proposed Implementation PR (next)
1. Runtime-first remediation (low-risk)
- Frontend: update `axios` to fixed patch version
- Backend: update `dompurify` to fixed patch version
- Backend: add npm `overrides` for `lodash` and `qs` fixed versions
- Regenerate lockfiles for frontend and backend

2. Validation
- Run `npm audit --omit=dev` in both projects
- Run build/lint/test commands in both projects
- Confirm no regression in application startup and core endpoints

3. Toolchain hardening (separate PR if needed)
- Update lint/build/test dependencies with potential semver-major impact
- Handle Vite/Vitest/ESLint major updates separately if required

## Risk Control
- Keep runtime security fixes isolated from toolchain upgrades
- Use small commits per package group
- Verify with CI and local checks before merge

## Merge Criteria for Next PR
- Runtime vulnerabilities reduced to zero high/critical in `--omit=dev`
- Build and tests pass for both frontend and backend
- No unrelated file changes
