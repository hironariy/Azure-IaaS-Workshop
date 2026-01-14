# Local Development Guide

This guide explains how to set up and run the Blog Application on your local machine for development and testing.

---

## Table of Contents

- [1. Architecture Overview](#1-architecture-overview)
- [2. Prerequisites](#2-prerequisites)
  - [2.1 Required Tools](#21-required-tools)
  - [2.2 Microsoft Entra ID App Registrations](#22-microsoft-entra-id-app-registrations)
- [3. Setup Instructions](#3-setup-instructions)
  - [Step 1: Clone the Repository](#step-1-clone-the-repository)
  - [Step 2: Start MongoDB](#step-2-start-mongodb)
  - [Step 3: Configure and Start Backend](#step-3-configure-and-start-backend)
  - [Step 4: Configure and Start Frontend](#step-4-configure-and-start-frontend)
  - [Step 5: Test the Application](#step-5-test-the-application)
- [4. Quick Commands Reference](#4-quick-commands-reference)
- [5. Troubleshooting](#5-troubleshooting)

---

## 1. Architecture Overview

The local development environment runs all components on your machine:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Local Development                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Browser ──► Frontend (Vite :5173) ──► Backend (Express :3000)  │
│                     │                          │                 │
│                     │                          │                 │
│                     ▼                          ▼                 │
│             Microsoft Entra ID         MongoDB (Docker :27017)   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

| Component | Technology | Port |
|-----------|------------|------|
| Frontend | React 18 + Vite | 5173 |
| Backend | Express.js + TypeScript | 3000 |
| Database | MongoDB 7.0 (Docker) | 27017 |
| Authentication | Microsoft Entra ID | N/A (cloud service) |

---

## 2. Prerequisites

### 2.1 Required Tools

Install these tools on your computer:

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Node.js** | 20.x LTS | JavaScript runtime | [Download](https://nodejs.org/) |
| **npm** | 10.x+ | Package manager | Included with Node.js |
| **Git** | 2.x+ | Version control | [Download](https://git-scm.com/) |
| **Docker Desktop** | Latest | Local MongoDB | [Download](https://www.docker.com/products/docker-desktop/) |
| **VS Code** | Latest | Code editor (recommended) | [Download](https://code.visualstudio.com/) |

**Verify your installation:**

```bash
# Check Node.js
node --version
# Expected: v20.x.x

# Check npm
npm --version
# Expected: 10.x.x

# Check Git
git --version
# Expected: git version 2.x.x

# Check Docker
docker --version
# Expected: Docker version 24.x.x or newer
```

### 2.2 Microsoft Entra ID App Registrations

You need to create **two app registrations** in Microsoft Entra ID for authentication to work.

> **Why two app registrations?**
> - **Frontend App**: Handles user login via MSAL.js (browser-based)
> - **Backend API App**: Validates JWT tokens and protects API endpoints

#### Required Permissions

> ⚠️ **IMPORTANT: Check Your Permissions Before Starting**
>
> To create app registrations in Microsoft Entra ID, you need one of the following:
>
> | Role/Setting | Who Has It |
> |--------------|------------|
> | **Application Developer** role | Assigned by your IT admin |
> | **Cloud Application Administrator** role | Assigned by your IT admin |
> | **Global Administrator** role | Tenant administrators |
> | **"Users can register applications"** = Yes | Default tenant setting (may be disabled) |
>
> **How to check if you have permission:**
> 1. Go to [Azure Portal](https://portal.azure.com) → Microsoft Entra ID → App registrations
> 2. Click "+ New registration"
> 3. If you see the registration form, you have permission ✅
> 4. If you see an error or the button is disabled, contact your IT administrator ❌
>
> **For Personal/Free Azure Accounts:**
> If you created your own Azure account, you are automatically the Global Administrator and can create app registrations without any additional setup.

#### Create Frontend App Registration

<details>
<summary>📝 Click to expand: Step-by-step instructions</summary>

1. **Open Azure Portal**
   - Go to [portal.azure.com](https://portal.azure.com)
   - Sign in with your Microsoft account

2. **Navigate to Entra ID**
   - In the search bar at the top, type "Entra ID"
   - Click on "Microsoft Entra ID"

3. **Create App Registration**
   - In the left menu, click "App registrations"
   - Click "+ New registration" button

4. **Configure the App**
   - **Name**: `BlogApp Frontend (Dev)` (or any name you prefer)
   - **Supported account types**: Select "Accounts in this organizational directory only"
   - **Redirect URI**: 
     - Select **"Single-page application (SPA)"** from the dropdown
     - Enter: `http://localhost:5173`

   > ⚠️ **CRITICAL**: You MUST select **"Single-page application (SPA)"** - NOT "Web". 
   > If you select "Web", authentication will fail with error `AADSTS9002326`.

5. **Click "Register"**

6. **Copy Important Values** (you'll need these later)
   - **Application (client) ID**: This is your `VITE_ENTRA_CLIENT_ID`
   - **Directory (tenant) ID**: This is your `VITE_ENTRA_TENANT_ID`

   > 💡 Keep this browser tab open - you'll need these values soon.

</details>

#### Create Backend API App Registration

<details>
<summary>📝 Click to expand: Step-by-step instructions</summary>

1. **Create Another App Registration**
   - Go back to "App registrations"
   - Click "+ New registration"

2. **Configure the App**
   - **Name**: `BlogApp API (Dev)`
   - **Supported account types**: "Accounts in this organizational directory only"
   - **Redirect URI**: Leave empty (APIs don't need redirect URIs)

3. **Click "Register"**

4. **Copy the Application (client) ID**
   - This is your `ENTRA_CLIENT_ID` (for backend)
   - Also used as `VITE_API_CLIENT_ID` (for frontend)

5. **Expose an API Scope**
   - In the left menu, click "Expose an API"
   - Click "Add a scope"
   - If asked for Application ID URI, click "Save and continue" (accept default)
   - Configure the scope:
     - **Scope name**: `access_as_user`
     - **Who can consent**: Admins and users
     - **Admin consent display name**: `Access BlogApp API`
     - **Admin consent description**: `Allows the app to access BlogApp API on behalf of the signed-in user`
   - Click "Add scope"

</details>

#### Grant Frontend Permission to Call Backend API

<details>
<summary>📝 Click to expand: Step-by-step instructions</summary>

1. **Go to Frontend App Registration**
   - Navigate to App registrations → `BlogApp Frontend (Dev)`

2. **Add API Permission**
   - In the left menu, click "API permissions"
   - Click "+ Add a permission"
   - Select "My APIs" tab
   - Click on "BlogApp API (Dev)"
   - Check the box next to `access_as_user`
   - Click "Add permissions"

3. **(Optional) Grant Admin Consent**
   - If you're an admin, click "Grant admin consent for [Your Organization]"
   - This prevents users from needing to consent individually

</details>

#### Summary of Values You'll Need

| Value | Where to Find | Used For |
|-------|---------------|----------|
| `VITE_ENTRA_CLIENT_ID` | Frontend app → Overview → Application (client) ID | Frontend login |
| `VITE_ENTRA_TENANT_ID` | Any app → Overview → Directory (tenant) ID | Both frontend and backend |
| `ENTRA_CLIENT_ID` | Backend API app → Overview → Application (client) ID | Backend token validation |
| `VITE_API_CLIENT_ID` | Same as ENTRA_CLIENT_ID | Frontend API calls |

---

## 3. Setup Instructions

Follow these steps to run the application on your local machine.

### Step 1: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/Azure-IaaS-Workshop.git

# Navigate to project folder
cd Azure-IaaS-Workshop
```

### Step 2: Start MongoDB

The application uses MongoDB with a replica set. We provide a Docker Compose configuration for easy setup.

```bash
# Navigate to dev-environment folder
cd dev-environment

# Start MongoDB container
docker-compose up -d

# Wait for MongoDB to be ready (about 5 seconds)
sleep 5

# Initialize the replica set (first time only)
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js
```

**Verify MongoDB is running:**

```bash
# Check container status
docker-compose ps

# Expected output:
# NAME                   STATUS          PORTS
# blogapp-mongo-primary  running         0.0.0.0:27017->27017/tcp

# Test MongoDB connection
docker exec -it blogapp-mongo-primary mongosh --eval "db.adminCommand('ping')"
# Expected: { ok: 1 }
```

> **💡 Troubleshooting:** If the container fails to start, try:
> ```bash
> docker-compose down -v  # Remove existing volumes
> docker-compose up -d    # Start fresh
> ```

### Step 3: Configure and Start Backend

```bash
# Navigate to backend folder (from project root)
cd materials/backend

# Create environment file from example
cp .env.example .env
```

**Edit `.env` file** with your Entra ID values:

```bash
# materials/backend/.env

NODE_ENV=development
PORT=3000

# MongoDB (local Docker)
MONGODB_URI=mongodb://localhost:27017/blogapp?replicaSet=blogapp-rs0

# Microsoft Entra ID - Use values from your Backend API app registration
ENTRA_TENANT_ID=paste-your-tenant-id-here
ENTRA_CLIENT_ID=paste-your-backend-api-client-id-here

# Logging
LOG_LEVEL=debug

# CORS (allow frontend to call API)
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

**Start the backend:**

```bash
# Install dependencies
npm install

# Start development server (with hot reload)
npm run dev
```

**Expected output:**
```
[INFO] Server running on port 3000
[INFO] MongoDB connected successfully
[INFO] Environment: development
```

**Verify backend is working:**

```bash
# In a new terminal
curl http://localhost:3000/health

# Expected response:
# {"status":"healthy","timestamp":"...","environment":"development"}
```

> **Keep this terminal open** - the backend needs to stay running.

### Step 4: Configure and Start Frontend

```bash
# Open a new terminal and navigate to frontend folder
cd materials/frontend

# Create environment file from example
cp .env.example .env
```

**Edit `.env` file** with your Entra ID values:

```bash
# materials/frontend/.env

# Frontend App Registration (for MSAL login)
VITE_ENTRA_CLIENT_ID=paste-your-frontend-client-id-here
VITE_ENTRA_TENANT_ID=paste-your-tenant-id-here
VITE_ENTRA_REDIRECT_URI=http://localhost:5173

# Backend API App Registration (for API token audience)
VITE_API_CLIENT_ID=paste-your-backend-api-client-id-here
```

**Start the frontend:**

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

**Expected output:**
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

### Step 5: Test the Application

1. **Open your browser** and go to: **http://localhost:5173**

2. **Test without login:**
   - You should see the home page with a list of posts (may be empty initially)
   - This verifies frontend → backend → MongoDB connection is working

3. **Test login:**
   - Click the **"Login"** button in the header
   - Sign in with your Microsoft account
   - Accept the permissions when prompted
   - After login, your name should appear in the header

4. **Test authenticated features:**
   - Click **"Create Post"** to write a new blog post
   - Save as draft or publish
   - View your posts in **"My Posts"**

**🎉 Congratulations!** Your local development environment is ready.

---

## 4. Quick Commands Reference

```bash
# Start everything (run in separate terminals)
cd dev-environment && docker-compose up -d      # Terminal 1: MongoDB
cd materials/backend && npm run dev              # Terminal 2: Backend
cd materials/frontend && npm run dev             # Terminal 3: Frontend

# Stop everything
docker-compose stop                              # Stop MongoDB
# Press Ctrl+C in backend/frontend terminals

# Reset database (if needed)
cd dev-environment
docker-compose down -v
docker-compose up -d
sleep 5
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js

# Add sample data (optional)
cd materials/backend && npm run seed
```

---

## 5. Troubleshooting

### MongoDB Issues

| Problem | Solution |
|---------|----------|
| Container won't start | Run `docker-compose down -v` then `docker-compose up -d` |
| Replica set not initialized | Run the init script again: `docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js` |
| Port 27017 in use | Stop other MongoDB instances or change the port in `docker-compose.yml` |

### Backend Issues

| Problem | Solution |
|---------|----------|
| MongoDB connection failed | Ensure MongoDB container is running and replica set is initialized |
| Port 3000 in use | Change `PORT` in `.env` or stop the conflicting process |
| Missing environment variables | Verify `.env` file exists and has all required values |

### Frontend Issues

| Problem | Solution |
|---------|----------|
| CORS errors | Verify `CORS_ORIGINS` in backend `.env` includes `http://localhost:5173` |
| Login fails with AADSTS9002326 | Ensure frontend app registration uses "Single-page application (SPA)" redirect type |
| API calls return 401 | Check that `VITE_API_CLIENT_ID` matches backend's `ENTRA_CLIENT_ID` |

### Authentication Issues

| Problem | Solution |
|---------|----------|
| Cannot create app registration | Check you have required permissions (see Prerequisites section) |
| Token validation fails | Verify `ENTRA_TENANT_ID` and `ENTRA_CLIENT_ID` match your app registration |
| Scope not found error | Ensure you exposed the `access_as_user` scope on the backend API app |

---

## Related Documentation

- [README.md](../../README.md) - Main project documentation and Azure deployment guide
- [dev-environment/README.md](../../dev-environment/README.md) - Docker environment details
- [Backend Application Design](../../design/BackendApplicationDesign.md) - API specifications
- [Frontend Application Design](../../design/FrontendApplicationDesign.md) - UI/UX specifications
