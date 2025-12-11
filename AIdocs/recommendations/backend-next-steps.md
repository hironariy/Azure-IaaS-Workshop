# Backend Application - Next Steps

## Immediate Next Steps

### 1. Microsoft Entra ID App Registration

You need to register an application in Entra ID to enable JWT authentication:

1. **Azure Portal** → Microsoft Entra ID → App registrations → New registration
2. Configure:
   - **Name**: `blogapp-api` (or similar)
   - **Supported account types**: Single tenant (for workshop)
   - **Redirect URI**: Not needed for API (backend)
3. After creation:
   - Copy **Application (client) ID** → `ENTRA_CLIENT_ID`
   - Copy **Directory (tenant) ID** → `ENTRA_TENANT_ID`
4. **Expose an API**:
   - Set Application ID URI: `api://<client-id>`
   - Add a scope: `access_as_user`
5. Update your `.env` file with these values

### 2. Set Up Local MongoDB

The Docker Compose for MongoDB replica set should exist in `/materials/db/`. If not created yet:

```bash
cd materials/db
docker-compose up -d
```

### 3. Configure Environment

```bash
cd materials/backend
cp .env.example .env
# Edit .env with your Entra ID values
```

### 4. Run the Backend

```bash
npm run dev
```

### 5. Test Health Endpoint

```bash
curl http://localhost:3000/health
```

---

## Additional Tasks (After Basic Setup Works)

| Task | Description |
|------|-------------|
| **Add Users Routes** | CRUD for user profiles |
| **Add Comments Routes** | Comments on posts |
| **Add Unit Tests** | Jest tests for services/controllers |
| **Add Integration Tests** | API endpoint tests |
| **Systemd Service File** | For Azure VM deployment |
| **NGINX Config** | Upstream configuration for Internal LB |

---

## Related Documentation

- `/design/BackendApplicationDesign.md` - Backend architecture specifications
- `/design/RepositoryWideDesignRules.md` - Security and logging patterns
- `/materials/backend/README.md` - Backend setup instructions
