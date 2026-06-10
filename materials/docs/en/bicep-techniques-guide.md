# Bicep Techniques Used in This Repository

This guide explains the **specific Bicep patterns and techniques** used in this repository’s infrastructure templates.

Scope:
- Templates live under `materials/bicep/`
- The main entrypoint is `materials/bicep/main.bicep`
- This guide focuses on *how the Bicep is designed*, not on Azure service theory (that’s covered elsewhere in the workshop)

## 0) Quick map of the Bicep files

- `materials/bicep/main.bicep`
  - Orchestrates everything and defines parameters, feature flags, and outputs.
- `materials/bicep/main.bicepparam`
  - Committed “template” parameter file (students fill in required values).
- `materials/bicep/main.local.bicepparam`
  - Personal parameter file (gitignored via the repo-root `.gitignore` `*.local.bicepparam` rule). Copy from `main.bicepparam` and put your own tenant/client IDs, SSH key, etc.
- `materials/bicep/modules/**`
  - Reusable modules grouped by domain: `network/`, `compute/`, `monitoring/`, `security/`, `storage/`.

## 1) Parameter design: clear UX + safe defaults

### 1.1 `@description` and `@allowed` to guide students
In `materials/bicep/main.bicep`, most parameters have:
- `@description()` to make portal/CLI parameter prompts understandable
- `@allowed([...])` for controlled values (example: `environment` is `prod|dev|test`, `groupId` is `A-J`)

This reduces accidental misconfiguration during a workshop.

### 1.2 `@secure()` for secrets
Sensitive values are marked as secure, such as:
- `sshPublicKey` (not “secret” in the same way as a password, but still treated carefully)
- `sslCertificateData`, `sslCertificatePassword`
- `mongoDbAppPassword`

The intent is: **never commit secrets to Git** and avoid accidental logs.

### 1.3 Feature flags to keep workshop cost and complexity controllable
`materials/bicep/main.bicep` uses boolean parameters to turn costly/optional components on/off:
- `deployBastion`
- `deployNatGateway`
- `deployMonitoring`
- `deployKeyVault`
- `deployStorage`

Students can run “full” mode for the workshop, and instructors can switch to “cheaper” mode for dev.

## 2) Module composition: domain modules + tier modules

### 2.1 One “orchestrator” template + many smaller modules
The repo uses a common production pattern:
- `main.bicep` is the only file students typically deploy.
- Everything else is a module called by `main.bicep`.

This keeps the workshop UX simple (one deployment command) while preserving good IaC structure.

### 2.2 Reusable VM module + tier wrappers
Compute is split into:
- `materials/bicep/modules/compute/vm.bicep` (a reusable “single VM” module)
- `web-tier.bicep`, `app-tier.bicep`, `db-tier.bicep` (each deploys two VMs across AZ1 & AZ2)

Tier modules are responsible for tier-specific decisions like:
- which bootstrap script to run (NGINX / Node.js / MongoDB)
- which inputs are needed (e.g., Entra IDs and MongoDB URI for app tier)

## 3) Dependencies: when to rely on Bicep implicit ordering vs explicit `dependsOn`

### 3.1 Implicit dependencies via outputs
Bicep automatically creates dependencies when you reference another module’s outputs.

Example pattern used in `materials/bicep/main.bicep`:
- VNet needs NSG IDs → `vnet` module references `nsgWeb.outputs.nsgId`, etc.
- Key Vault waits for VMs because it references VM `principalIds`.

This is the preferred default because it’s readable and hard to get wrong.

### 3.2 Explicit `dependsOn` when Azure needs strict sequencing
This repo uses explicit dependencies when a resource must exist *and be fully usable* before the next resource is created.

Examples in `materials/bicep/main.bicep`:
- `vnet` depends on `natGateway` so subnets can safely attach the NAT Gateway.
- `dbTier` depends on `vnet` to ensure outbound connectivity is ready before MongoDB provisioning.

## 4) Conditional deployment + safe dereferencing (`.?` + `??`)

### 4.1 Conditional modules
Modules are deployed conditionally, e.g.:
- `module natGateway ... = if (deployNatGateway) { ... }`

### 4.2 Safe-dereference outputs
When a module is conditional, its outputs may not exist. This repo uses safe-dereference:
- `logAnalytics.?outputs.?workspaceId ?? ''`

This keeps `main.bicep` deployable in multiple modes (e.g., monitoring off) without rewriting modules.

## 5) “Extension-only” updates: `skipVmCreation` + `existing` resources

Re-deploying a VM resource can fail when immutable properties change (common workshop issue: SSH keys).

This repo includes a deliberate technique:
- A per-tier flag in `main.bicep`:
  - `skipVmCreationWeb`, `skipVmCreationApp`, `skipVmCreationDb`
- A VM-module flag in `vm.bicep`:
  - `skipVmCreation`

When `skipVmCreation` is `true`:
- The module uses `existing` resources for the VM and NIC
- Only extensions (Azure Monitor Agent, Custom Script) can be updated

This is a workshop-friendly recovery/iteration approach.

## 6) Forcing Custom Script re-execution: `forceUpdateTag`

Custom Script Extensions are often idempotent, but Azure may not re-run them if nothing “changed”.

Technique in this repo:
- `vm.bicep` exposes `forceUpdateTag`
- `main.bicep` has `forceUpdateTagWeb`, `forceUpdateTagApp`, `forceUpdateTagDb`

Change the tag value (e.g., a timestamp string) to force that tier’s script to re-run.

## 7) Script injection pattern: `loadTextContent()` + placeholders + `base64()`

Tier modules load bash scripts and substitute placeholders.

Example patterns:
- `web-tier.bicep` loads `scripts/nginx-install.sh` and replaces:
  - `__ENTRA_TENANT_ID__`, `__ENTRA_FRONTEND_CLIENT_ID__`, `__ENTRA_BACKEND_CLIENT_ID__`
- `app-tier.bicep` loads `scripts/nodejs-install.sh` and replaces:
  - `__MONGODB_URI__`, `__ENTRA_TENANT_ID__`, `__ENTRA_CLIENT_ID__`

Why this pattern:
- Avoids `format()` escaping pitfalls with bash/JSON braces
- Keeps scripts readable and testable as standalone files
- Keeps “student-specific” values flowing from one place: the `.bicepparam`

## 8) Observability technique: Azure Monitor Agent in Bicep, DCR after deployment

The VM module deploys **Azure Monitor Agent** (AMA) as a VM extension.

However, this repo intentionally does **not** deploy the **Data Collection Rule (DCR)** via Bicep.
Reason (documented in `main.bicep` and implemented in scripts):
- Log Analytics tables like `Syslog` and `Perf` are created asynchronously.
- Creating the DCR immediately can fail with errors like “InvalidOutputTable”.

Workshop pattern:
- Deploy infrastructure with Bicep
- Then run the post-deployment script:
  - macOS/Linux: `scripts/configure-dcr.sh <resource-group>`
  - Windows: `scripts/configure-dcr.ps1 -ResourceGroupName <resource-group>`

## 9) RBAC technique: Key Vault deployed after VMs (Managed Identity access)

Key Vault is deployed in `materials/bicep/modules/security/key-vault.bicep`.
Technique highlights:
- Uses `enableRbacAuthorization: true` (RBAC mode, not access policies)
- Assigns built-in roles:
  - Admin: “Key Vault Administrator”
  - VMs: “Key Vault Secrets User”
- Filters principal IDs defensively to avoid deployment failure when a VM is missing/failed

Even if you don’t use Key Vault in code during the workshop, students can still learn:
- “VM identity” exists as a first-class Azure principal
- RBAC on a resource is the control-plane mechanism to allow secret reads

## 10) Outputs as a “workshop contract”

`materials/bicep/main.bicep` exports outputs that students/instructors can use immediately:
- Application Gateway FQDN and HTTPS URL
- Private IPs per tier
- MongoDB connection string (for validation)
- Key Vault URI (if deployed)
- NAT Gateway public IP (if deployed)

This makes the deployment usable without hunting through the portal.

## Appendix: student-safe workflow for parameter files

Recommended (workshop) workflow:
1. Copy `main.bicepparam` → `main.local.bicepparam`
2. Put real values only in `main.local.bicepparam`
3. Deploy using `--parameters main.local.bicepparam`

Why:
- Avoids committing tenant IDs, client IDs, and other identifiers
- Keeps “what students edit” stable and predictable
