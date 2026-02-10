# Identity, Access, and Secrets Guide (Entra ID + RBAC + Managed Identity)

This guide explains how identity and access work in this workshop, focusing on:
- Microsoft Entra ID (user authentication)
- Azure RBAC (control-plane authorization)
- Managed Identity (service-to-service auth inside Azure)
- Secret handling patterns used in this repository

It is written for AWS-experienced engineers and maps Azure concepts to familiar mental models.

## 1) The most important mental model: two planes

Azure has two different “authorization worlds” that often get confused:

### 1.1 Control plane (Azure Resource Manager / “ARM”)
- “Can I create/update/read Azure resources?”
- Governed by **Azure RBAC role assignments** on scopes (subscription / resource group / resource)

AWS analogy:
- Similar to IAM permissions used to call AWS APIs (CreateVpc, RunInstances, etc.).

### 1.2 Data plane (your application APIs)
- “Can I call the blog API?”
- Governed by your **app’s authentication and authorization** (OAuth tokens, JWT validation, app roles)

AWS analogy:
- Similar to Cognito-issued JWTs that your API validates.

In this workshop:
- Azure RBAC controls access to Azure infrastructure (portal, deployments, Key Vault access)
- Entra ID tokens control access to the backend API endpoints

## 2) The three identities you will see in this workshop

### 2.1 Your human identity (student/instructor)
Used for:
- Portal access
- Running deployments
- Getting your object ID (used to grant you Key Vault admin rights)

In Bicep parameter files this is typically:
- `adminObjectId`

### 2.2 Entra ID app registrations (frontend + backend)
This repo uses the recommended enterprise pattern:
- **Frontend SPA app**: MSAL client ID used by the browser
- **Backend API app**: API audience + scope definition

In Bicep parameter files:
- `entraTenantId`
- `entraFrontendClientId` (SPA)
- `entraClientId` (API)

Important:
- **Client IDs and tenant IDs are identifiers**, not secrets.
- They still should not be casually committed to public repos, but leaking them is not the same as leaking a password.

### 2.3 VM Managed Identities (system-assigned)
Each VM is created with a **system-assigned managed identity**.

Used for:
- Accessing Azure resources without a password (e.g., reading Key Vault secrets)

AWS analogy:
- Like an EC2 instance profile / IAM role attached to an instance.

Where this shows up:
- In Bicep (`vm.bicep`), VMs set `identity: { type: 'SystemAssigned' }`
- In Key Vault module, the VM identities get the “Key Vault Secrets User” role

## 3) How user login works (frontend)

### 3.1 Configuration source: dev vs Azure
The frontend is designed to support **runtime configuration**:

- Development mode:
  - Uses Vite env vars (e.g., `.env.local`) via `import.meta.env.VITE_*`
- Production (on Azure VMs):
  - Fetches `/config.json` at runtime
  - This file is created by the Web tier VM bootstrap script (NGINX Custom Script)

Relevant repo files:
- Frontend runtime config loader: `materials/frontend/src/config/appConfig.ts`
- NGINX script that writes `/var/www/html/config.json`: `materials/bicep/modules/compute/scripts/nginx-install.sh`

Why this matters:
- React/Vite normally bakes config at build time.
- The workshop needs “per student environment” Entra IDs without rebuilding the frontend.

### 3.2 MSAL behavior
The frontend uses MSAL (Authorization Code Flow with PKCE) and stores tokens in **sessionStorage** (not localStorage).

Where this is set:
- `materials/frontend/src/config/authConfig.ts` uses `cacheLocation: 'sessionStorage'`

## 4) How API calls are authorized (frontend → backend)

### 4.1 API scope
The frontend requests an access token for the backend API scope:

- Scope: `api://{BACKEND_CLIENT_ID}/access_as_user`

Where it’s configured:
- `materials/frontend/src/config/authConfig.ts` (`createApiRequest()` / `createLoginRequest()`)

### 4.2 Sending the token
When calling the backend, the frontend attaches:
- `Authorization: Bearer <access_token>`

Where it happens:
- `materials/frontend/src/services/api.ts` (Axios request interceptor)

## 5) How the backend validates tokens

The backend validates JWTs using:
- **JWKS** signing keys from the tenant
- Standard JWT checks: signature, issuer, audience

Where it happens:
- `materials/backend/src/middleware/auth.middleware.ts`

Key validation rules (workshop-relevant):
- JWKS endpoint:
  - `https://login.microsoftonline.com/${ENTRA_TENANT_ID}/discovery/v2.0/keys`
- Valid issuers:
  - `https://login.microsoftonline.com/${ENTRA_TENANT_ID}/v2.0`
  - `https://sts.windows.net/${ENTRA_TENANT_ID}/` (v1 issuer)
- Audience (must match API registration):
  - `api://${ENTRA_CLIENT_ID}`

Why the audience check is important:
- Prevents accidentally accepting an ID token meant for the SPA (different audience)

## 6) How Entra IDs are injected into the deployed VMs

This repo intentionally centralizes student configuration in the Bicep parameter file.

### 6.1 App tier (backend)
The app tier bootstrap script writes:
- `/etc/environment`
- `/opt/blogapp/.env`

Including:
- `ENTRA_TENANT_ID`
- `ENTRA_CLIENT_ID`
- `MONGODB_URI`

Where it’s defined:
- Script template: `materials/bicep/modules/compute/scripts/nodejs-install.sh`
- Placeholder replacement: `materials/bicep/modules/compute/app-tier.bicep`

### 6.2 Web tier (frontend)
The web tier bootstrap script writes:
- `/var/www/html/config.json`

Including:
- `ENTRA_TENANT_ID`
- `ENTRA_FRONTEND_CLIENT_ID`
- `ENTRA_BACKEND_CLIENT_ID`

Where it’s defined:
- Script template: `materials/bicep/modules/compute/scripts/nginx-install.sh`
- Placeholder replacement: `materials/bicep/modules/compute/web-tier.bicep`

## 7) Secrets: what is a secret in this workshop?

### 7.1 Secrets (must be protected)
- `mongoDbAppPassword` (MongoDB user password)
- `sslCertificateData` and `sslCertificatePassword`
- Any future client secrets (if you ever use a confidential client flow)

Repo techniques used to protect these:
- Bicep uses `@secure()` parameters
- Local parameter files are intended to be gitignored (repo-root `.gitignore` includes `*.local.bicepparam`)
- Backend/frontend `.env` files are not meant to be committed

### 7.2 Not secrets (still treat carefully)
- `entraTenantId`
- `entraClientId`, `entraFrontendClientId`

These are identifiers. They’re safe to share in many contexts, but in workshops it’s still good hygiene to avoid committing them.

## 8) Key Vault access (RBAC + managed identity)

The infrastructure deploys a Key Vault configured for RBAC authorization:
- `enableRbacAuthorization: true`

Role assignments used:
- Admin user gets “Key Vault Administrator”
- VMs get “Key Vault Secrets User”

Where it happens:
- Key Vault module: `materials/bicep/modules/security/key-vault.bicep`
- The module is deployed **after** VMs so it can collect VM `principalIds` and assign roles.

Important note about the current repo state:
- The backend currently reads `MONGODB_URI` directly from env vars.
- There is an optional `KEY_VAULT_NAME` env var in `materials/backend/src/config/environment.ts`, but there is no runtime Key Vault secret fetch implemented yet.

That’s intentional for workshop simplicity; the Key Vault is still useful for teaching and for future hardening.

## 9) Common failure modes (and what they usually mean)

- Backend returns `401 Unauthorized`:
  - Missing `Authorization: Bearer ...` header
  - Token expired
  - Token is for the wrong audience (SPA token instead of API token)

- Backend returns `401 Invalid token` after login:
  - Wrong backend API client ID configured (audience mismatch)
  - Tenant mismatch (token issued by a different tenant than configured)

- Frontend keeps prompting for consent / `AADSTS65001`:
  - The SPA didn’t get consent for `access_as_user`
  - Fix: ensure the frontend requests the API scope during login (this repo does)

- Key Vault access denied from VM identity:
  - Missing role assignment, or role assignment not propagated yet
  - Wrong principal ID (VM recreation changes identity)

## 10) Log hygiene (do not leak secrets)

This repo includes log sanitization guidance and utilities. The big rules:
- Never log tokens.
- Never log connection strings with passwords.

See:
- Repository rules: `design/RepositoryWideDesignRules.md` (Secret Management & Log Sanitization)
- Backend sanitizers: `materials/backend/src/utils/logger.ts`
