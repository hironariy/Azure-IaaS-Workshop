# Backend Application - Azure IaaS Workshop

Multi-user blog API built with Express.js and TypeScript.

## Prerequisites

- Node.js 20.x LTS
- MongoDB 7.0 (via Docker Compose - see `/materials/db/`)
- Microsoft Entra ID app registration

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

- `MONGODB_URI`: MongoDB connection string (default works with local Docker replica set)
- `ENTRA_TENANT_ID`: Your Microsoft Entra ID tenant ID
- `ENTRA_CLIENT_ID`: Your app registration client ID

### 3. Start MongoDB

Make sure the MongoDB replica set is running:

```bash
cd ../db
docker-compose up -d
```

### 4. Run Development Server

```bash
npm run dev
```

The API will be available at `http://localhost:3000`.

## Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Build TypeScript to JavaScript |
| `npm start` | Start production server |
| `npm run lint` | Run ESLint |
| `npm run lint:fix` | Fix ESLint errors |
| `npm run format` | Format code with Prettier |
| `npm test` | Run tests |

## API Endpoints

### Health Checks

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Simple health check for load balancer |
| `/health/detailed` | GET | Detailed health with component status |
| `/ready` | GET | Kubernetes-style readiness check |
| `/live` | GET | Kubernetes-style liveness check |

### Posts API

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/posts` | GET | Optional | List published posts |
| `/api/posts/:slug` | GET | Optional | Get post by slug |
| `/api/posts` | POST | Required | Create new post |
| `/api/posts/:slug` | PUT | Required | Update post (author only) |
| `/api/posts/:slug` | DELETE | Required | Delete post (author only) |

## Authentication

This API uses Microsoft Entra ID for authentication. Include a valid JWT token in the `Authorization` header:

```
Authorization: Bearer <your-token>
```

The frontend application handles authentication via MSAL and provides tokens to the API.

## Project Structure

```
src/
├── config/           # Configuration files
│   ├── database.ts   # MongoDB connection
│   └── environment.ts # Environment variables
├── middleware/       # Express middleware
│   ├── auth.middleware.ts # JWT validation
│   └── error.middleware.ts # Error handling
├── models/           # Mongoose schemas
│   ├── User.ts
│   ├── Post.ts
│   └── Comment.ts
├── routes/           # API routes
│   ├── health.routes.ts
│   └── posts.routes.ts
├── utils/            # Utility functions
│   └── logger.ts     # Winston logger
└── app.ts            # Application entry point
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NODE_ENV` | No | development | Environment mode |
| `PORT` | No | 3000 | Server port |
| `MONGODB_URI` | Yes | localhost:27017,27018 | MongoDB connection string |
| `ENTRA_TENANT_ID` | Yes | - | Microsoft Entra ID tenant |
| `ENTRA_CLIENT_ID` | Yes | - | App registration client ID |
| `LOG_LEVEL` | No | debug | Logging level |
| `CORS_ORIGINS` | No | localhost:5173,3000 | Allowed CORS origins |

## Deployment

For Azure VM deployment, see `/design/BackendApplicationDesign.md`.

The application runs under systemd on Azure VMs:
- Service: `blogapp-api.service`
- Port: 3000
- Behind Internal Load Balancer at 10.0.2.10

## AWS Equivalent

For AWS-experienced engineers:

| This Project (Azure) | AWS Equivalent |
|---------------------|----------------|
| Microsoft Entra ID | Amazon Cognito |
| Azure Internal LB | AWS Internal ALB |
| Azure VM Scale Set | AWS Auto Scaling Group |
| Azure Monitor | Amazon CloudWatch |
