# Local Development Environment

This directory contains Docker Compose configuration for local development of the Azure IaaS Workshop blog application.

## Prerequisites

- Docker Desktop for Mac
- Docker Compose (included with Docker Desktop)

## Quick Start

### 1. Start the Environment

```bash
cd dev-environment

# Start all containers
docker-compose up -d

# Check container status
docker-compose ps
```

### 2. Initialize MongoDB Replica Set

**First time only:**

```bash
# Wait for MongoDB containers to be healthy (about 10 seconds)
sleep 10

# Initialize replica set
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js
```

### 3. Verify Setup

```bash
# Check replica set status
docker exec -it blogapp-mongo-primary mongosh --eval "rs.status()"

# Expected output:
# - Primary: mongo-primary (host: mongo-primary:27017)
# - Secondary: mongo-secondary (host: mongo-secondary:27017)
```

### 4. Access Services

- **MongoDB Primary**: `localhost:27017`
- **MongoDB Secondary**: `localhost:27018`
- **Mongo Express (Web UI)**: http://localhost:8081
  - Username: `admin`
  - Password: `admin`

## Connection Strings

### For Backend Application

Add to `materials/backend/.env.development`:

```bash
NODE_ENV=development
PORT=3000

# MongoDB connection string (replica set)
MONGODB_URI=mongodb://localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0

# For development, you can use mock authentication
JWT_ISSUER=https://login.microsoftonline.com/mock-tenant-id/v2.0
JWT_AUDIENCE=api://mock-app-id
USE_MOCK_AUTH=true
```

**Note**: Authentication is disabled in local development for simplicity. In production (Azure VMs), you'll use proper authentication with passwords stored in Azure Key Vault.

### Direct Connection (mongosh)

```bash
# Connect to primary
mongosh "mongodb://localhost:27017/"

# Connect to secondary (read-only)
mongosh "mongodb://localhost:27018/?readPreference=secondary"
```

## Common Tasks

### Stop Environment

```bash
# Stop containers (preserves data)
docker-compose stop

# Stop and remove containers (preserves volumes)
docker-compose down

# Stop, remove containers AND delete all data
docker-compose down -v
```

### View Logs

```bash
# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f mongodb-primary
docker-compose logs -f mongodb-secondary
```

### Restart Containers

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart mongodb-primary
```

### Test Failover (HA Simulation)

```bash
# Stop primary to simulate failure
docker-compose stop mongodb-primary

# Wait a few seconds, then check replica set status
docker exec -it blogapp-mongo-secondary mongosh -u admin -p devpassword123 --authenticationDatabase admin --eval "rs.status()"

# Secondary should become PRIMARY (manual in 2-node setup)
# Note: With 2 nodes, automatic failover requires manual intervention

# Restart primary
docker-compose start mongodb-primary
```

### Reset Database

```bash
# Delete all data and start fresh
docker-compose down -v
docker-compose up -d

# Re-initialize replica set
sleep 10
docker exec -it blogapp-mongo-primary mongosh -u admin -p devpassword123 --authenticationDatabase admin /scripts/init-replica-set.js
```

### Execute Script in MongoDB

```bash
# Run create-schema.js (when available)
docker exec -it blogapp-mongo-primary mongosh blogapp < ../materials/backend/scripts/create-schema.js

# Run seed-data.js (when available)
docker exec -it blogapp-mongo-primary mongosh blogapp < ../materials/backend/scripts/seed-data.js
```

## Troubleshooting

### Containers Won't Start

```bash
# Check logs
docker-compose logs

# Verify ports not in use
lsof -i :27017
lsof -i :27018
lsof -i :8081

# Remove and recreate
docker-compose down -v
docker-compose up -d
```

### Replica Set Not Initialized

```bash
# Check if MongoDB is ready
docker exec -it blogapp-mongo-primary mongosh --eval "db.adminCommand('ping')"

# Re-run initialization
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js
```

### Can't Connect from Backend

**Ensure using correct connection string:**
- Host: `localhost` (not `mongo-primary` - that's internal Docker network)
- Ports: `27017,27018`
- No authentication for local dev

### Mongo Express Not Loading

```bash
# Check if containers are healthy
docker-compose ps

# Restart Mongo Express
docker-compose restart mongo-express
```

## Development Workflow

### Typical Daily Workflow

1. **Morning: Start Environment**
   ```bash
   cd dev-environment
   docker-compose up -d
   ```

2. **Develop Backend**
   ```bash
   cd materials/backend
   npm run dev
   # Code, save, hot reload
   ```

3. **Develop Frontend**
   ```bash
   cd materials/frontend
   npm run dev
   # Code, save, hot reload
   ```

4. **Evening: Stop Environment**
   ```bash
   cd dev-environment
   docker-compose stop
   # Or leave running if continuing tomorrow
   ```

### When to Use Azure Instead

- ✅ Testing Bicep templates
- ✅ Validating Azure-specific features (Managed Identity, Key Vault)
- ✅ Testing monitoring/logging integration
- ✅ Workshop dry run
- ✅ Final validation before workshop delivery

**For Azure testing**: Use separate Bicep template in `materials/bicep/dev/` with minimal resources.

## Resource Usage

**Typical Resource Consumption:**
- CPU: ~5-10% (idle)
- RAM: ~500 MB (all containers)
- Disk: ~2 GB (with data)

**Safe to run in background** while developing.

## Next Steps

1. ✅ Start containers: `docker-compose up -d`
2. ✅ Initialize replica set
3. ✅ Create backend project structure
4. ✅ Develop schemas and models
5. ✅ Build API endpoints
6. 🔄 Test with local MongoDB
7. ☁️ Validate on Azure when feature complete

## See Also

- [Workshop Development Strategy](../AIdocs/recommendations/workshop-development-strategy.md)
- [Backend Application Design](../design/BackendApplicationDesign.md)
- [Database Design](../design/DatabaseDesign.md)
