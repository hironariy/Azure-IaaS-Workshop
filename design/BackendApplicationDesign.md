# Backend Application Design Specification

## Overview

This document defines the backend API requirements for the Azure IaaS Workshop blog application. This serves as the specification that the Backend Engineer agent must follow when creating the Express/TypeScript API.

## Application Overview

- **Type**: RESTful API server for multi-user blog application
- **Framework**: Express.js 4.18+ with TypeScript 5+
- **Database**: MongoDB 7.0+ (via Mongoose ODM)
- **Authentication**: Microsoft Entra ID OAuth2.0 JWT validation
- **Deployment**: Node.js process on Azure VMs (systemd service)
- **Target Users**: Workshop students learning Azure authentication and IaaS deployment
- **Code Standard**: Google TypeScript Style Guide (mandatory)

## Technology Stack

### Core Technologies
- **Runtime**: Node.js 20.x LTS
- **Framework**: Express.js 4.18+
- **Language**: TypeScript 5+ (strict mode)
- **Database ODM**: Mongoose 8.x
- **Authentication**: jsonwebtoken, jwks-rsa (JWT validation)
- **Validation**: express-validator or Zod
- **Logging**: Winston or Pino (structured JSON logging)
- **Testing**: Jest + Supertest
- **Process Management**: PM2 or systemd (production)

### Development Tools
- **Package Manager**: npm or yarn
- **Linting**: ESLint with TypeScript plugin
- **Formatting**: Prettier
- **Type Checking**: TypeScript compiler (tsc)
- **API Documentation**: OpenAPI/Swagger (optional)
- **Environment Variables**: dotenv

### Security & Middleware
- **Helmet**: Security headers
- **CORS**: Cross-origin resource sharing
- **Rate Limiting**: express-rate-limit
- **Compression**: compression middleware
- **Body Parsing**: express built-in JSON parser

---

## API Architecture

### REST API Design Principles

**RESTful Conventions**:
- Use HTTP methods correctly (GET, POST, PUT, DELETE)
- Return appropriate status codes (200, 201, 400, 401, 403, 404, 500)
- Use plural nouns for resources (`/posts`, `/users`, `/comments`)
- Use nested routes for relationships (`/posts/:postId/comments`)
- Version API if needed (`/api/v1/`)

**Response Format**:
```typescript
// Success response
{
  "data": { /* resource or array */ },
  "message": "Success message (optional)"
}

// Error response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "title": ["Title must be between 5 and 200 characters"]
    }
  }
}

// Paginated response
{
  "data": [ /* array of resources */ ],
  "pagination": {
    "page": 1,
    "pageSize": 10,
    "totalCount": 150,
    "totalPages": 15
  }
}
```

### Project Structure

```
backend/
├── src/
│   ├── config/              # Configuration files
│   │   ├── database.ts      # MongoDB connection config
│   │   ├── auth.ts          # Entra ID auth config
│   │   └── environment.ts   # Environment variables
│   ├── middleware/          # Express middleware
│   │   ├── auth.middleware.ts       # JWT validation
│   │   ├── error.middleware.ts      # Error handling
│   │   ├── validation.middleware.ts # Input validation
│   │   └── logger.middleware.ts     # Request logging
│   ├── models/              # Mongoose models
│   │   ├── User.model.ts
│   │   ├── Post.model.ts
│   │   └── index.ts
│   ├── routes/              # API routes
│   │   ├── auth.routes.ts
│   │   ├── users.routes.ts
│   │   ├── posts.routes.ts
│   │   ├── comments.routes.ts
│   │   ├── health.routes.ts
│   │   └── index.ts
│   ├── controllers/         # Route controllers
│   │   ├── auth.controller.ts
│   │   ├── users.controller.ts
│   │   ├── posts.controller.ts
│   │   └── comments.controller.ts
│   ├── services/            # Business logic
│   │   ├── user.service.ts
│   │   ├── post.service.ts
│   │   └── auth.service.ts
│   ├── utils/               # Utility functions
│   │   ├── jwt.util.ts
│   │   ├── slug.util.ts
│   │   └── errors.util.ts
│   ├── types/               # TypeScript type definitions
│   │   ├── express.d.ts     # Express augmentation
│   │   ├── auth.types.ts
│   │   └── api.types.ts
│   ├── app.ts               # Express app setup
│   └── server.ts            # Server entry point
├── tests/                   # Test files
│   ├── unit/
│   ├── integration/
│   └── setup.ts
├── scripts/                 # Utility scripts
│   ├── seed-database.ts
│   └── check-health.sh
├── .env.example             # Example environment variables
├── .eslintrc.js
├── .prettierrc
├── tsconfig.json
├── jest.config.js
├── package.json
└── README.md
```

**Design Rationale**:
- **Separation of Concerns**: Routes → Controllers → Services → Models
- **Testability**: Business logic in services (easy to unit test)
- **Maintainability**: Clear folder structure, single responsibility
- **Educational Value**: Students see production-quality architecture

---

## API Endpoints Specification

### Base URL

- **Development**: `http://localhost:3000/api`
- **Production**: `http://<load-balancer-ip>/api`
- **Version**: `/api/v1` (optional, omit for simplicity in workshop)

### Authentication Endpoints

#### POST /api/auth/register

**Purpose**: Register or sync user from Entra ID token

**Authentication**: Required (JWT token)

**Request Body**:
```typescript
{
  // User info extracted from JWT token claims
  // No explicit body required
}
```

**Response** (201 Created):
```typescript
{
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "entraUserId": "a1b2c3d4-...",
    "email": "user@example.com",
    "displayName": "John Doe",
    "role": "user",
    "createdAt": "2025-12-01T10:00:00Z"
  }
}
```

**Process**:
1. Extract user info from validated JWT token claims
2. Check if user exists (by `entraUserId`)
3. If new: Create user in MongoDB
4. If exists: Update `lastLoginAt` timestamp
5. Return user profile

**Error Responses**:
- `401 Unauthorized`: Invalid or missing token
- `500 Internal Server Error`: Database error

---

#### GET /api/auth/me

**Purpose**: Get current authenticated user profile

**Authentication**: Required (JWT token)

**Response** (200 OK):
```typescript
{
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "entraUserId": "a1b2c3d4-...",
    "email": "user@example.com",
    "displayName": "John Doe",
    "givenName": "John",
    "surname": "Doe",
    "profilePicture": "https://...",
    "bio": "Software engineer...",
    "role": "user",
    "isActive": true,
    "createdAt": "2025-12-01T10:00:00Z",
    "updatedAt": "2025-12-01T10:00:00Z"
  }
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: User not found in database

---

### User Endpoints

#### GET /api/users/:userId

**Purpose**: Get public user profile

**Authentication**: Optional (public endpoint)

**Parameters**:
- `userId` (path): MongoDB ObjectId

**Response** (200 OK):
```typescript
{
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "displayName": "John Doe",
    "profilePicture": "https://...",
    "bio": "Software engineer...",
    "createdAt": "2025-12-01T10:00:00Z"
    // Sensitive fields (email, entraUserId) NOT included
  }
}
```

**Error Responses**:
- `404 Not Found`: User doesn't exist
- `400 Bad Request`: Invalid userId format

---

#### GET /api/users/:userId/posts

**Purpose**: Get all posts by specific user

**Authentication**: Optional

**Parameters**:
- `userId` (path): MongoDB ObjectId
- `page` (query): Page number (default: 1)
- `pageSize` (query): Items per page (default: 10, max: 50)
- `status` (query): Filter by status (`published` | `draft`) - only works if requesting own posts

**Response** (200 OK):
```typescript
{
  "data": [
    {
      "_id": "507f...",
      "title": "My First Post",
      "slug": "my-first-post",
      "excerpt": "This is my first blog post...",
      "authorName": "John Doe",
      "tags": ["azure", "beginners"],
      "publishedAt": "2025-12-01T12:00:00Z",
      "viewCount": 42
    }
  ],
  "pagination": {
    "page": 1,
    "pageSize": 10,
    "totalCount": 25,
    "totalPages": 3
  }
}
```

**Business Rules**:
- Only published posts visible to public
- Draft posts only visible to post author (requires authentication)

---

### Post Endpoints

#### GET /api/posts

**Purpose**: Get all published posts (paginated)

**Authentication**: Optional

**Query Parameters**:
- `page` (number): Page number (default: 1)
- `pageSize` (number): Items per page (default: 10, max: 50)
- `tag` (string): Filter by tag
- `search` (string): Full-text search (title, content, tags)
- `sort` (string): Sort field (`publishedAt` | `viewCount` | `title`)
- `order` (string): Sort order (`asc` | `desc`, default: `desc`)

**Response** (200 OK):
```typescript
{
  "data": [
    {
      "_id": "507f...",
      "title": "Getting Started with Azure",
      "slug": "getting-started-azure",
      "excerpt": "Learn Azure fundamentals...",
      "authorId": "507f...",
      "authorName": "Alice Workshop",
      "tags": ["azure", "beginners"],
      "publishedAt": "2025-12-01T10:00:00Z",
      "viewCount": 156,
      "metadata": {
        "readingTimeMinutes": 5,
        "wordCount": 1200,
        "featuredImage": "https://..."
      }
    }
  ],
  "pagination": {
    "page": 1,
    "pageSize": 10,
    "totalCount": 150,
    "totalPages": 15
  }
}
```

**Example Requests**:
```bash
# Get first page
GET /api/posts?page=1&pageSize=10

# Filter by tag
GET /api/posts?tag=azure

# Search
GET /api/posts?search=azure iaas

# Sort by popularity
GET /api/posts?sort=viewCount&order=desc
```

---

#### GET /api/posts/:slug

**Purpose**: Get single post by slug (with comments)

**Authentication**: Optional (required for draft posts)

**Parameters**:
- `slug` (path): URL slug (e.g., "my-first-post")

**Response** (200 OK):
```typescript
{
  "data": {
    "_id": "507f...",
    "title": "Getting Started with Azure",
    "slug": "getting-started-azure",
    "content": "# Introduction\n\nFull markdown content...",
    "excerpt": "Learn Azure fundamentals...",
    "authorId": "507f...",
    "authorName": "Alice Workshop",
    "tags": ["azure", "beginners"],
    "status": "published",
    "publishedAt": "2025-12-01T10:00:00Z",
    "createdAt": "2025-11-25T08:00:00Z",
    "updatedAt": "2025-11-25T08:00:00Z",
    "viewCount": 157,  // Incremented after fetch
    "comments": [
      {
        "_id": "507f...",
        "userId": "507f...",
        "userName": "Bob Student",
        "content": "Great post!",
        "createdAt": "2025-12-01T11:00:00Z",
        "isEdited": false
      }
    ],
    "metadata": {
      "readingTimeMinutes": 5,
      "wordCount": 1200,
      "featuredImage": "https://..."
    }
  }
}
```

**Side Effects**:
- Increments `viewCount` by 1 on each GET request

**Error Responses**:
- `404 Not Found`: Post doesn't exist
- `403 Forbidden`: Draft post, user not author

---

#### POST /api/posts

**Purpose**: Create new blog post

**Authentication**: Required

**Request Body**:
```typescript
{
  "title": "My New Post",
  "content": "# Introduction\n\nFull markdown content...",
  "tags": ["azure", "tutorial"],
  "status": "draft",  // or "published"
  "featuredImage": "https://..." // Optional
}
```

**Validation Rules**:
- `title`: Required, 5-200 characters
- `content`: Required, minimum 50 characters
- `tags`: Optional, max 5 tags, each 1-30 characters
- `status`: Required, enum (`draft` | `published`)
- `featuredImage`: Optional, valid URL

**Response** (201 Created):
```typescript
{
  "data": {
    "_id": "507f...",
    "title": "My New Post",
    "slug": "my-new-post",  // Auto-generated from title
    "content": "...",
    "excerpt": "Introduction...",  // Auto-generated (first 150 chars)
    "authorId": "507f...",
    "authorName": "John Doe",  // From JWT token
    "tags": ["azure", "tutorial"],
    "status": "draft",
    "publishedAt": null,
    "createdAt": "2025-12-01T14:00:00Z",
    "updatedAt": "2025-12-01T14:00:00Z",
    "viewCount": 0,
    "comments": [],
    "metadata": {
      "readingTimeMinutes": 8,  // Calculated: wordCount / 200 WPM
      "wordCount": 1600,
      "featuredImage": "https://..."
    }
  }
}
```

**Business Logic**:
1. Validate request body
2. Extract author info from JWT token
3. Generate slug from title (ensure uniqueness)
4. Calculate excerpt (first 150 characters, strip markdown)
5. Calculate reading time (word count / 200 WPM)
6. Set `publishedAt` if status is `published`
7. Save to MongoDB
8. Return created post

**Error Responses**:
- `400 Bad Request`: Validation errors
- `401 Unauthorized`: Missing or invalid token
- `409 Conflict`: Slug already exists

---

#### PUT /api/posts/:postId

**Purpose**: Update existing post

**Authentication**: Required (must be post author)

**Parameters**:
- `postId` (path): MongoDB ObjectId

**Request Body** (partial update supported):
```typescript
{
  "title": "Updated Title",
  "content": "Updated content...",
  "tags": ["new", "tags"],
  "status": "published",
  "featuredImage": "https://..."
}
```

**Response** (200 OK):
```typescript
{
  "data": {
    // Full updated post object
    "updatedAt": "2025-12-01T15:00:00Z"  // Updated timestamp
  }
}
```

**Business Rules**:
- Only post author can update
- If status changes from `draft` to `published`, set `publishedAt` to current time
- Recalculate slug if title changes (ensure uniqueness)
- Recalculate excerpt, wordCount, readingTime
- Update `updatedAt` timestamp

**Error Responses**:
- `400 Bad Request`: Validation errors
- `401 Unauthorized`: Not authenticated
- `403 Forbidden`: Not post author
- `404 Not Found`: Post doesn't exist
- `409 Conflict`: New slug already exists

---

#### DELETE /api/posts/:postId

**Purpose**: Delete post (hard delete)

**Authentication**: Required (must be post author)

**Parameters**:
- `postId` (path): MongoDB ObjectId

**Response** (204 No Content):
```
(Empty response body)
```

**Business Rules**:
- Only post author can delete
- Permanently removes post and all embedded comments
- Alternative: Soft delete (set `isDeleted: true`) - document this option

**Error Responses**:
- `401 Unauthorized`: Not authenticated
- `403 Forbidden`: Not post author
- `404 Not Found`: Post doesn't exist

---

### Comment Endpoints

#### POST /api/posts/:postId/comments

**Purpose**: Add comment to post

**Authentication**: Required

**Parameters**:
- `postId` (path): MongoDB ObjectId

**Request Body**:
```typescript
{
  "content": "This is a great post! Thanks for sharing."
}
```

**Validation Rules**:
- `content`: Required, 1-1000 characters

**Response** (201 Created):
```typescript
{
  "data": {
    "_id": "507f...",  // Comment ID
    "userId": "507f...",
    "userName": "John Doe",  // From JWT token
    "content": "This is a great post!...",
    "createdAt": "2025-12-01T16:00:00Z",
    "updatedAt": "2025-12-01T16:00:00Z",
    "isEdited": false
  }
}
```

**Business Logic**:
1. Verify post exists
2. Extract user info from JWT token
3. Create comment object
4. Push comment to post's `comments` array
5. Return created comment

**Error Responses**:
- `400 Bad Request`: Validation errors
- `401 Unauthorized`: Not authenticated
- `404 Not Found`: Post doesn't exist

---

#### DELETE /api/posts/:postId/comments/:commentId

**Purpose**: Delete comment

**Authentication**: Required (must be comment author or post author)

**Parameters**:
- `postId` (path): MongoDB ObjectId
- `commentId` (path): MongoDB ObjectId (comment ID)

**Response** (204 No Content):
```
(Empty response body)
```

**Business Rules**:
- Comment author can delete own comment
- Post author can delete any comment on their post
- Remove comment from post's `comments` array

**Error Responses**:
- `401 Unauthorized`: Not authenticated
- `403 Forbidden`: Not comment author or post author
- `404 Not Found`: Post or comment doesn't exist

---

### Health Check Endpoints

#### GET /api/health

**Purpose**: Health check for load balancer probe

**Authentication**: None (public)

**Response** (200 OK):
```typescript
{
  "status": "healthy",
  "timestamp": "2025-12-01T17:00:00Z",
  "database": "connected",
  "uptime": 86400  // Seconds
}
```

**Response** (503 Service Unavailable):
```typescript
{
  "status": "unhealthy",
  "timestamp": "2025-12-01T17:00:00Z",
  "database": "disconnected",
  "error": "MongoNetworkError: connect ECONNREFUSED"
}
```

**Implementation**:
- Ping MongoDB: `db.admin().command({ ping: 1 })`
- Check Node.js process uptime
- Return 200 if healthy, 503 if unhealthy
- Used by Azure Load Balancer health probe

---

#### GET /api/health/ready

**Purpose**: Readiness check (is app ready to serve traffic?)

**Response** (200 OK):
```typescript
{
  "ready": true,
  "database": "connected",
  "models": "loaded"
}
```

**Response** (503 Service Unavailable):
```typescript
{
  "ready": false,
  "database": "disconnected"
}
```

**Use Case**: Kubernetes-style readiness probe (optional for workshop)

---

## Authentication & Authorization

### Microsoft Entra ID OAuth2.0 Integration

**Authentication Flow** (already handled by frontend):
1. User authenticates with Microsoft Entra ID (handled by MSAL in frontend)
2. Frontend receives JWT access token from Entra ID
3. Frontend sends token in `Authorization: Bearer {token}` header with each API request
4. Backend validates token and extracts user claims
5. Backend grants or denies access based on validation

**Backend Responsibility**: Validate JWT tokens and extract user information

### JWT Token Structure

**Example JWT Token Claims** (decoded):
```json
{
  "aud": "api://12345678-1234-1234-1234-123456789abc",
  "iss": "https://login.microsoftonline.com/{tenantId}/v2.0",
  "iat": 1701432000,
  "exp": 1701435600,
  "sub": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "oid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "preferred_username": "user@example.com",
  "name": "John Doe",
  "given_name": "John",
  "family_name": "Doe",
  "email": "user@example.com",
  "tid": "{tenantId}",
  "ver": "2.0"
}
```

**Key Claims**:
- `aud` (audience): API identifier (must match backend's expected audience)
- `iss` (issuer): Token issuer (Microsoft Entra ID)
- `exp` (expiration): Token expiration timestamp
- `oid` (object ID): User's Entra ID object ID (unique identifier)
- `preferred_username`: User's email
- `name`: Display name
- `email`: Email address

### JWT Validation Strategy

#### Option 1: jwks-rsa + jsonwebtoken (Recommended)

**Advantages**:
- Verifies token signature using Microsoft's public keys
- Automatically fetches and caches JWKS (JSON Web Key Set)
- Industry-standard approach
- Educational value: Students learn proper JWT validation

**Implementation Pattern**:

```typescript
// src/config/auth.ts
import jwksRsa from 'jwks-rsa';
import jwt from 'jsonwebtoken';

export const authConfig = {
  tenantId: process.env.ENTRA_TENANT_ID!,
  clientId: process.env.ENTRA_CLIENT_ID!, // API application ID
  audience: `api://${process.env.ENTRA_CLIENT_ID}`,
  issuer: `https://login.microsoftonline.com/${process.env.ENTRA_TENANT_ID}/v2.0`,
  jwksUri: `https://login.microsoftonline.com/${process.env.ENTRA_TENANT_ID}/discovery/v2.0/keys`,
};

// JWKS client for fetching Microsoft's public keys
export const jwksClient = jwksRsa({
  jwksUri: authConfig.jwksUri,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
  rateLimit: true,
  jwksRequestsPerMinute: 10,
});

// Get signing key from JWKS
export const getKey = (header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) => {
  jwksClient.getSigningKey(header.kid!, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
};
```

```typescript
// src/middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { authConfig, getKey } from '../config/auth';
import { UnauthorizedError } from '../utils/errors.util';

/**
 * JWT Authentication Middleware
 * 
 * Validates JWT token from Authorization header and attaches user info to request.
 * 
 * Educational Note: Unlike AWS API Gateway with Cognito Authorizer (which handles
 * validation automatically), Express requires manual JWT validation. This teaches
 * the underlying OAuth2.0 mechanics.
 */
export const authenticateJWT = (req: Request, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new UnauthorizedError('No token provided');
  }

  const token = authHeader.substring(7); // Remove 'Bearer ' prefix

  // Verify token signature and claims
  jwt.verify(
    token,
    getKey,
    {
      audience: authConfig.audience,
      issuer: authConfig.issuer,
      algorithms: ['RS256'], // Entra ID uses RSA256
    },
    (err, decoded) => {
      if (err) {
        if (err.name === 'TokenExpiredError') {
          throw new UnauthorizedError('Token expired');
        }
        throw new UnauthorizedError('Invalid token');
      }

      // Type-safe decoded token
      const payload = decoded as EntraIdTokenPayload;

      // Attach user info to request object
      req.user = {
        userId: payload.oid, // Entra ID object ID (unique identifier)
        email: payload.email || payload.preferred_username,
        displayName: payload.name,
        givenName: payload.given_name,
        surname: payload.family_name,
      };

      next();
    }
  );
};

/**
 * Optional Authentication Middleware
 * 
 * Validates token if present, but doesn't require authentication.
 * Useful for endpoints that behave differently for authenticated users.
 */
export const optionalAuth = (req: Request, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    // No token provided, continue without user info
    next();
    return;
  }

  const token = authHeader.substring(7);

  jwt.verify(
    token,
    getKey,
    {
      audience: authConfig.audience,
      issuer: authConfig.issuer,
      algorithms: ['RS256'],
    },
    (err, decoded) => {
      if (!err && decoded) {
        const payload = decoded as EntraIdTokenPayload;
        req.user = {
          userId: payload.oid,
          email: payload.email || payload.preferred_username,
          displayName: payload.name,
          givenName: payload.given_name,
          surname: payload.family_name,
        };
      }
      // Continue even if validation fails (optional auth)
      next();
    }
  );
};
```

#### Option 2: passport-azure-ad (Alternative)

**Advantages**:
- Higher-level abstraction
- Less boilerplate code
- Passport.js ecosystem integration

**Trade-offs**:
- Less educational (hides JWT validation details)
- Additional dependency
- Workshop focuses on understanding JWT, not Passport.js

**Recommendation**: Use Option 1 (jwks-rsa + jsonwebtoken) for workshop educational value.

### TypeScript Type Definitions

```typescript
// src/types/auth.types.ts

/**
 * Microsoft Entra ID JWT token payload
 */
export interface EntraIdTokenPayload {
  aud: string; // Audience (API client ID)
  iss: string; // Issuer (Microsoft Entra ID)
  iat: number; // Issued at timestamp
  exp: number; // Expiration timestamp
  sub: string; // Subject (user ID)
  oid: string; // Object ID (unique user identifier)
  preferred_username: string; // Email
  name: string; // Display name
  given_name?: string; // First name
  family_name?: string; // Last name
  email?: string; // Email address
  tid: string; // Tenant ID
  ver: string; // Token version
}

/**
 * User information extracted from JWT token
 */
export interface RequestUser {
  userId: string; // Entra ID object ID
  email: string;
  displayName: string;
  givenName?: string;
  surname?: string;
}

// Extend Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: RequestUser;
    }
  }
}
```

```typescript
// src/types/express.d.ts
import { RequestUser } from './auth.types';

declare global {
  namespace Express {
    interface Request {
      user?: RequestUser;
    }
  }
}

export {};
```

### Authorization Patterns

#### Resource Ownership Check

```typescript
// src/middleware/authorization.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { Post } from '../models/Post.model';
import { ForbiddenError, NotFoundError } from '../utils/errors.util';

/**
 * Check if authenticated user is the author of the post
 */
export const isPostAuthor = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const postId = req.params.postId;
  const userId = req.user?.userId; // Set by authenticateJWT middleware

  if (!userId) {
    throw new ForbiddenError('Authentication required');
  }

  const post = await Post.findById(postId);

  if (!post) {
    throw new NotFoundError('Post not found');
  }

  // Compare authorId (ObjectId) with userId (string from JWT)
  if (post.authorId.toString() !== userId) {
    throw new ForbiddenError('Not authorized to modify this post');
  }

  next();
};

/**
 * Check if authenticated user is comment author or post author
 */
export const canDeleteComment = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const { postId, commentId } = req.params;
  const userId = req.user?.userId;

  if (!userId) {
    throw new ForbiddenError('Authentication required');
  }

  const post = await Post.findById(postId);

  if (!post) {
    throw new NotFoundError('Post not found');
  }

  const comment = post.comments.id(commentId);

  if (!comment) {
    throw new NotFoundError('Comment not found');
  }

  // Allow if user is comment author OR post author
  const isCommentAuthor = comment.userId.toString() === userId;
  const isPostAuthor = post.authorId.toString() === userId;

  if (!isCommentAuthor && !isPostAuthor) {
    throw new ForbiddenError('Not authorized to delete this comment');
  }

  next();
};
```

### Environment Variables

```bash
# .env.example

# Server Configuration
NODE_ENV=development
PORT=3000
API_BASE_URL=/api

# MongoDB Configuration
MONGODB_URI=mongodb://blogapp_api_user:password@10.0.3.4:27018,10.0.3.5:27018/blogapp?replicaSet=blogapp-rs0&readPreference=primaryPreferred&w=majority
MONGODB_DATABASE=blogapp

# Microsoft Entra ID Configuration
ENTRA_TENANT_ID=your-tenant-id-here
ENTRA_CLIENT_ID=your-api-client-id-here
# Note: Client secret NOT needed for JWT validation (public key validation only)

# CORS Configuration
CORS_ORIGIN=http://localhost:5173,http://10.0.1.4,http://10.0.1.5
# Production: Load balancer public IP

# Logging
LOG_LEVEL=debug
LOG_FORMAT=json

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

**Security Note**: 
- Store secrets in Azure Key Vault or GitHub Secrets
- Never commit `.env` file to Git
- Use managed identities where possible (Azure VMs accessing Key Vault)

---

## Database Integration

### MongoDB Connection

```typescript
// src/config/database.ts
import mongoose from 'mongoose';
import { logger } from '../utils/logger.util';

/**
 * MongoDB Connection Configuration
 * 
 * Connects to MongoDB replica set with production-ready settings.
 * 
 * Educational Note: Unlike AWS DocumentDB (managed MongoDB-compatible service),
 * this connects to self-managed MongoDB on Azure VMs. Connection string includes
 * replica set name for automatic failover.
 */
export const connectDatabase = async (): Promise<void> => {
  const mongoUri = process.env.MONGODB_URI!;

  try {
    await mongoose.connect(mongoUri, {
      // Connection pool settings
      maxPoolSize: 50, // Max connections
      minPoolSize: 10, // Min connections maintained
      
      // Timeouts
      serverSelectionTimeoutMS: 5000, // Timeout for selecting server
      socketTimeoutMS: 45000, // Socket timeout
      
      // Replica set settings
      readPreference: 'primaryPreferred', // Read from primary, fallback to secondary
      
      // Other options
      family: 4, // Use IPv4
    });

    logger.info('MongoDB connected successfully', {
      database: mongoose.connection.db.databaseName,
      host: mongoose.connection.host,
    });

    // Handle connection events
    mongoose.connection.on('error', (err) => {
      logger.error('MongoDB connection error', { error: err });
    });

    mongoose.connection.on('disconnected', () => {
      logger.warn('MongoDB disconnected');
    });

    mongoose.connection.on('reconnected', () => {
      logger.info('MongoDB reconnected');
    });

  } catch (error) {
    logger.error('Failed to connect to MongoDB', { error });
    process.exit(1); // Exit if database connection fails
  }
};

/**
 * Gracefully close MongoDB connection
 */
export const disconnectDatabase = async (): Promise<void> => {
  try {
    await mongoose.connection.close();
    logger.info('MongoDB connection closed');
  } catch (error) {
    logger.error('Error closing MongoDB connection', { error });
  }
};
```

### Mongoose Models

#### User Model

```typescript
// src/models/User.model.ts
import mongoose, { Schema, Document } from 'mongoose';

/**
 * User Document Interface
 */
export interface IUser extends Document {
  entraUserId: string;
  email: string;
  displayName: string;
  givenName?: string;
  surname?: string;
  profilePicture?: string;
  bio?: string;
  createdAt: Date;
  updatedAt: Date;
  lastLoginAt: Date;
  isActive: boolean;
  role: 'user' | 'admin';
}

/**
 * User Schema
 * 
 * Maps to 'users' collection in MongoDB.
 * Schema validation ensures data integrity.
 */
const UserSchema = new Schema<IUser>(
  {
    entraUserId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    },
    displayName: {
      type: String,
      required: true,
      trim: true,
      minlength: 1,
      maxlength: 100,
    },
    givenName: {
      type: String,
      trim: true,
      maxlength: 50,
    },
    surname: {
      type: String,
      trim: true,
      maxlength: 50,
    },
    profilePicture: {
      type: String,
      match: /^https?:\/\/.+/,
    },
    bio: {
      type: String,
      maxlength: 500,
    },
    lastLoginAt: {
      type: Date,
      required: true,
      default: Date.now,
    },
    isActive: {
      type: Boolean,
      required: true,
      default: true,
    },
    role: {
      type: String,
      enum: ['user', 'admin'],
      default: 'user',
      required: true,
    },
  },
  {
    timestamps: true, // Automatically manage createdAt and updatedAt
    collection: 'users',
  }
);

// Indexes (in addition to unique indexes)
UserSchema.index({ isActive: 1 });
UserSchema.index({ isActive: 1, createdAt: -1 });

export const User = mongoose.model<IUser>('User', UserSchema);
```

#### Post Model

```typescript
// src/models/Post.model.ts
import mongoose, { Schema, Document, Types } from 'mongoose';

/**
 * Comment subdocument interface
 */
export interface IComment {
  _id: Types.ObjectId;
  userId: Types.ObjectId;
  userName: string;
  content: string;
  createdAt: Date;
  updatedAt: Date;
  isEdited: boolean;
}

/**
 * Post Document Interface
 */
export interface IPost extends Document {
  title: string;
  slug: string;
  content: string;
  excerpt: string;
  authorId: Types.ObjectId;
  authorName: string;
  tags: string[];
  status: 'draft' | 'published';
  publishedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
  viewCount: number;
  comments: Types.DocumentArray<IComment>;
  metadata: {
    readingTimeMinutes: number;
    wordCount: number;
    featuredImage?: string;
  };
}

/**
 * Comment Schema (embedded)
 */
const CommentSchema = new Schema<IComment>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    userName: {
      type: String,
      required: true,
      trim: true,
    },
    content: {
      type: String,
      required: true,
      minlength: 1,
      maxlength: 1000,
    },
    isEdited: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

/**
 * Post Schema
 */
const PostSchema = new Schema<IPost>(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      minlength: 5,
      maxlength: 200,
    },
    slug: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      match: /^[a-z0-9-]+$/,
    },
    content: {
      type: String,
      required: true,
      minlength: 50,
    },
    excerpt: {
      type: String,
      required: true,
      maxlength: 300,
    },
    authorId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    authorName: {
      type: String,
      required: true,
      trim: true,
    },
    tags: {
      type: [String],
      default: [],
      validate: {
        validator: (v: string[]) => v.length <= 5,
        message: 'Maximum 5 tags allowed',
      },
    },
    status: {
      type: String,
      enum: ['draft', 'published'],
      default: 'draft',
      required: true,
    },
    publishedAt: {
      type: Date,
    },
    viewCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    comments: {
      type: [CommentSchema],
      default: [],
    },
    metadata: {
      readingTimeMinutes: {
        type: Number,
        required: true,
        min: 1,
      },
      wordCount: {
        type: Number,
        required: true,
        min: 0,
      },
      featuredImage: {
        type: String,
        match: /^https?:\/\/.+/,
      },
    },
  },
  {
    timestamps: true,
    collection: 'posts',
  }
);

// Indexes
PostSchema.index({ slug: 1 }, { unique: true });
PostSchema.index({ authorId: 1 });
PostSchema.index({ status: 1, publishedAt: -1 });
PostSchema.index({ tags: 1 });
PostSchema.index({ status: 1, viewCount: -1 });

// Text index for search
PostSchema.index(
  {
    title: 'text',
    content: 'text',
    tags: 'text',
  },
  {
    weights: {
      title: 3,
      tags: 2,
      content: 1,
    },
  }
);

export const Post = mongoose.model<IPost>('Post', PostSchema);
```

### Database Utility Functions

```typescript
// src/utils/slug.util.ts
import { Post } from '../models/Post.model';

/**
 * Generate URL-friendly slug from title
 * 
 * @param title - Post title
 * @returns Slug string
 */
export const generateSlug = (title: string): string => {
  return title
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, '') // Remove special characters
    .replace(/\s+/g, '-') // Replace spaces with hyphens
    .replace(/-+/g, '-') // Replace multiple hyphens with single hyphen
    .substring(0, 100); // Limit length
};

/**
 * Ensure slug is unique by appending number if needed
 * 
 * @param baseSlug - Initial slug
 * @param excludePostId - Post ID to exclude (for updates)
 * @returns Unique slug
 */
export const ensureUniqueSlug = async (
  baseSlug: string,
  excludePostId?: string
): Promise<string> => {
  let slug = baseSlug;
  let counter = 1;

  while (true) {
    const query: any = { slug };
    if (excludePostId) {
      query._id = { $ne: excludePostId };
    }

    const existing = await Post.findOne(query);

    if (!existing) {
      return slug;
    }

    // Append counter and try again
    slug = `${baseSlug}-${counter}`;
    counter++;
  }
};
```

```typescript
// src/utils/content.util.ts

/**
 * Calculate reading time in minutes
 * 
 * @param wordCount - Number of words
 * @returns Reading time in minutes
 */
export const calculateReadingTime = (wordCount: number): number => {
  const wordsPerMinute = 200; // Average reading speed
  return Math.ceil(wordCount / wordsPerMinute);
};

/**
 * Count words in text
 * 
 * @param text - Text content
 * @returns Word count
 */
export const countWords = (text: string): number => {
  return text.trim().split(/\s+/).length;
};

/**
 * Generate excerpt from content
 * 
 * @param content - Full content (may include markdown)
 * @param maxLength - Maximum excerpt length
 * @returns Excerpt string
 */
export const generateExcerpt = (content: string, maxLength: number = 150): string => {
  // Strip markdown formatting (simple approach)
  const plainText = content
    .replace(/#{1,6}\s/g, '') // Remove headers
    .replace(/\*\*(.+?)\*\*/g, '$1') // Remove bold
    .replace(/\*(.+?)\*/g, '$1') // Remove italic
    .replace(/\[(.+?)\]\(.+?\)/g, '$1') // Remove links
    .replace(/`(.+?)`/g, '$1') // Remove code
    .replace(/\n+/g, ' ') // Replace newlines with spaces
    .trim();

  if (plainText.length <= maxLength) {
    return plainText;
  }

  // Truncate at word boundary
  const truncated = plainText.substring(0, maxLength);
  const lastSpace = truncated.lastIndexOf(' ');

  return truncated.substring(0, lastSpace) + '...';
};
```

---

## Middleware Implementation

### Error Handling Middleware

```typescript
// src/utils/errors.util.ts

/**
 * Base API Error class
 */
export class ApiError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public code: string = 'API_ERROR',
    public details?: any
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class BadRequestError extends ApiError {
  constructor(message: string = 'Bad request', details?: any) {
    super(400, message, 'BAD_REQUEST', details);
  }
}

export class UnauthorizedError extends ApiError {
  constructor(message: string = 'Unauthorized') {
    super(401, message, 'UNAUTHORIZED');
  }
}

export class ForbiddenError extends ApiError {
  constructor(message: string = 'Forbidden') {
    super(403, message, 'FORBIDDEN');
  }
}

export class NotFoundError extends ApiError {
  constructor(message: string = 'Resource not found') {
    super(404, message, 'NOT_FOUND');
  }
}

export class ConflictError extends ApiError {
  constructor(message: string = 'Resource conflict', details?: any) {
    super(409, message, 'CONFLICT', details);
  }
}

export class InternalServerError extends ApiError {
  constructor(message: string = 'Internal server error') {
    super(500, message, 'INTERNAL_SERVER_ERROR');
  }
}
```

```typescript
// src/middleware/error.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { ApiError } from '../utils/errors.util';
import { logger } from '../utils/logger.util';

/**
 * Global Error Handler Middleware
 * 
 * Catches all errors and returns consistent error responses.
 * Must be registered AFTER all routes.
 */
export const errorHandler = (
  err: Error | ApiError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Log error
  logger.error('Request error', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    userId: req.user?.userId,
  });

  // Handle known API errors
  if (err instanceof ApiError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
      },
    });
    return;
  }

  // Handle Mongoose validation errors
  if (err.name === 'ValidationError') {
    res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        details: err.message,
      },
    });
    return;
  }

  // Handle Mongoose cast errors (invalid ObjectId)
  if (err.name === 'CastError') {
    res.status(400).json({
      error: {
        code: 'INVALID_ID',
        message: 'Invalid resource ID',
      },
    });
    return;
  }

  // Handle duplicate key errors (MongoDB E11000)
  if (err.name === 'MongoServerError' && (err as any).code === 11000) {
    res.status(409).json({
      error: {
        code: 'DUPLICATE_KEY',
        message: 'Resource already exists',
        details: (err as any).keyValue,
      },
    });
    return;
  }

  // Default to 500 Internal Server Error
  res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: process.env.NODE_ENV === 'production' 
        ? 'An unexpected error occurred' 
        : err.message,
    },
  });
};

/**
 * 404 Not Found Handler
 * 
 * Catches requests to undefined routes.
 */
export const notFoundHandler = (req: Request, res: Response): void => {
  res.status(404).json({
    error: {
      code: 'NOT_FOUND',
      message: `Route ${req.method} ${req.path} not found`,
    },
  });
};

/**
 * Async handler wrapper
 * 
 * Wraps async route handlers to catch promise rejections.
 * Eliminates need for try/catch in every controller.
 */
export const asyncHandler = (
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
```

### Request Logging Middleware

```typescript
// src/middleware/logger.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger.util';

/**
 * Request Logging Middleware
 * 
 * Logs all HTTP requests with timing information.
 */
export const requestLogger = (req: Request, res: Response, next: NextFunction): void => {
  const startTime = Date.now();

  // Log request
  logger.info('Incoming request', {
    method: req.method,
    path: req.path,
    query: req.query,
    userId: req.user?.userId,
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - startTime;

    logger.info('Request completed', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userId: req.user?.userId,
    });
  });

  next();
};
```

```typescript
// src/utils/logger.util.ts
import winston from 'winston';

/**
 * Winston Logger Configuration
 * 
 * Structured JSON logging for production.
 * Human-readable format for development.
 */
export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'blogapp-api',
    environment: process.env.NODE_ENV,
  },
  transports: [
    // Write to console
    new winston.transports.Console({
      format: process.env.NODE_ENV === 'production'
        ? winston.format.json()
        : winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          ),
    }),
    // Write to file (production)
    ...(process.env.NODE_ENV === 'production'
      ? [
          new winston.transports.File({
            filename: '/var/log/blogapp/error.log',
            level: 'error',
          }),
          new winston.transports.File({
            filename: '/var/log/blogapp/combined.log',
          }),
        ]
      : []),
  ],
});
```

### Validation Middleware

```typescript
// src/middleware/validation.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { validationResult, ValidationChain } from 'express-validator';
import { BadRequestError } from '../utils/errors.util';

/**
 * Validation Error Handler
 * 
 * Checks for validation errors from express-validator.
 * Throws BadRequestError if validation fails.
 */
export const validate = (req: Request, res: Response, next: NextFunction): void => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    const details: Record<string, string[]> = {};

    errors.array().forEach((error) => {
      if (error.type === 'field') {
        const field = error.path;
        if (!details[field]) {
          details[field] = [];
        }
        details[field].push(error.msg);
      }
    });

    throw new BadRequestError('Validation failed', details);
  }

  next();
};

/**
 * Combine validation chains with error handler
 * 
 * @param validations - Array of express-validator chains
 * @returns Middleware array
 */
export const validateRequest = (validations: ValidationChain[]) => {
  return [...validations, validate];
};
```

### Security Middleware

```typescript
// src/middleware/security.middleware.ts
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';

/**
 * Security Headers (Helmet)
 */
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
});

/**
 * CORS Configuration
 */
export const corsOptions = cors({
  origin: (origin, callback) => {
    const allowedOrigins = process.env.CORS_ORIGIN?.split(',') || [];

    // Allow requests with no origin (mobile apps, Postman)
    if (!origin) {
      callback(null, true);
      return;
    }

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
});

/**
 * Rate Limiting
 */
export const rateLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'), // 100 requests per window
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests, please try again later',
    },
  },
  standardHeaders: true,
  legacyHeaders: false,
});
```

---

---

## Controllers & Services Implementation

### Controller Pattern

**Responsibility**: Handle HTTP request/response, delegate business logic to services

**Best Practices**:
- Thin controllers (minimal logic)
- Extract request data, call service, return response
- Use asyncHandler to catch errors
- Don't access database directly (use services)

### Auth Controller

```typescript
// src/controllers/auth.controller.ts
import { Request, Response } from 'express';
import { authService } from '../services/auth.service';
import { asyncHandler } from '../middleware/error.middleware';

/**
 * Register or sync user from JWT token
 * 
 * POST /api/auth/register
 */
export const register = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  // User info already validated and attached by authenticateJWT middleware
  const userInfo = req.user!;

  const user = await authService.registerOrUpdateUser(userInfo);

  res.status(201).json({
    data: {
      _id: user._id,
      entraUserId: user.entraUserId,
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      createdAt: user.createdAt,
    },
  });
});

/**
 * Get current authenticated user profile
 * 
 * GET /api/auth/me
 */
export const getCurrentUser = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const userId = req.user!.userId;

  const user = await authService.getUserByEntraId(userId);

  res.status(200).json({
    data: user,
  });
});
```

### Post Controller

```typescript
// src/controllers/posts.controller.ts
import { Request, Response } from 'express';
import { postService } from '../services/post.service';
import { asyncHandler } from '../middleware/error.middleware';

/**
 * Get all published posts (paginated)
 * 
 * GET /api/posts
 */
export const getAllPosts = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const page = parseInt(req.query.page as string) || 1;
  const pageSize = Math.min(parseInt(req.query.pageSize as string) || 10, 50);
  const tag = req.query.tag as string | undefined;
  const search = req.query.search as string | undefined;
  const sort = (req.query.sort as string) || 'publishedAt';
  const order = (req.query.order as 'asc' | 'desc') || 'desc';

  const result = await postService.getAllPosts({
    page,
    pageSize,
    tag,
    search,
    sort,
    order,
  });

  res.status(200).json(result);
});

/**
 * Get single post by slug
 * 
 * GET /api/posts/:slug
 */
export const getPostBySlug = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { slug } = req.params;
  const userId = req.user?.userId; // Optional auth

  const post = await postService.getPostBySlug(slug, userId);

  res.status(200).json({
    data: post,
  });
});

/**
 * Create new post
 * 
 * POST /api/posts
 */
export const createPost = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const userId = req.user!.userId;
  const userName = req.user!.displayName;
  const { title, content, tags, status, featuredImage } = req.body;

  const post = await postService.createPost({
    title,
    content,
    tags,
    status,
    featuredImage,
    authorEntraId: userId,
    authorName: userName,
  });

  res.status(201).json({
    data: post,
  });
});

/**
 * Update existing post
 * 
 * PUT /api/posts/:postId
 */
export const updatePost = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { postId } = req.params;
  const { title, content, tags, status, featuredImage } = req.body;

  const post = await postService.updatePost(postId, {
    title,
    content,
    tags,
    status,
    featuredImage,
  });

  res.status(200).json({
    data: post,
  });
});

/**
 * Delete post
 * 
 * DELETE /api/posts/:postId
 */
export const deletePost = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { postId } = req.params;

  await postService.deletePost(postId);

  res.status(204).send();
});
```

### Comment Controller

```typescript
// src/controllers/comments.controller.ts
import { Request, Response } from 'express';
import { commentService } from '../services/comment.service';
import { asyncHandler } from '../middleware/error.middleware';

/**
 * Add comment to post
 * 
 * POST /api/posts/:postId/comments
 */
export const addComment = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { postId } = req.params;
  const { content } = req.body;
  const userId = req.user!.userId;
  const userName = req.user!.displayName;

  const comment = await commentService.addComment({
    postId,
    content,
    userId,
    userName,
  });

  res.status(201).json({
    data: comment,
  });
});

/**
 * Delete comment
 * 
 * DELETE /api/posts/:postId/comments/:commentId
 */
export const deleteComment = asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { postId, commentId } = req.params;

  await commentService.deleteComment(postId, commentId);

  res.status(204).send();
});
```

### Service Layer Implementation

**Responsibility**: Business logic, database operations, validation

### Auth Service

```typescript
// src/services/auth.service.ts
import { User, IUser } from '../models/User.model';
import { NotFoundError } from '../utils/errors.util';
import { RequestUser } from '../types/auth.types';

class AuthService {
  /**
   * Register new user or update existing user from Entra ID token
   * 
   * @param userInfo - User info from JWT token
   * @returns User document
   */
  async registerOrUpdateUser(userInfo: RequestUser): Promise<IUser> {
    const { userId, email, displayName, givenName, surname } = userInfo;

    // Check if user exists
    let user = await User.findOne({ entraUserId: userId });

    if (user) {
      // Update last login timestamp
      user.lastLoginAt = new Date();
      
      // Update profile if changed (name might change in Entra ID)
      user.displayName = displayName;
      if (givenName) user.givenName = givenName;
      if (surname) user.surname = surname;
      
      await user.save();
    } else {
      // Create new user
      user = await User.create({
        entraUserId: userId,
        email,
        displayName,
        givenName,
        surname,
        lastLoginAt: new Date(),
        isActive: true,
        role: 'user',
      });
    }

    return user;
  }

  /**
   * Get user by Entra ID user ID
   * 
   * @param entraUserId - Entra ID user object ID
   * @returns User document
   */
  async getUserByEntraId(entraUserId: string): Promise<IUser> {
    const user = await User.findOne({ entraUserId });

    if (!user) {
      throw new NotFoundError('User not found');
    }

    return user;
  }

  /**
   * Get user by MongoDB ID
   * 
   * @param userId - MongoDB ObjectId
   * @returns User document (public fields only)
   */
  async getUserById(userId: string): Promise<Partial<IUser>> {
    const user = await User.findById(userId).select(
      '_id displayName profilePicture bio createdAt'
    );

    if (!user) {
      throw new NotFoundError('User not found');
    }

    return user;
  }
}

export const authService = new AuthService();
```

### Post Service

```typescript
// src/services/post.service.ts
import { Post, IPost } from '../models/Post.model';
import { User } from '../models/User.model';
import { NotFoundError, ForbiddenError, ConflictError } from '../utils/errors.util';
import {
  generateSlug,
  ensureUniqueSlug,
  generateExcerpt,
  countWords,
  calculateReadingTime,
} from '../utils/content.util';

interface CreatePostDTO {
  title: string;
  content: string;
  tags?: string[];
  status: 'draft' | 'published';
  featuredImage?: string;
  authorEntraId: string;
  authorName: string;
}

interface UpdatePostDTO {
  title?: string;
  content?: string;
  tags?: string[];
  status?: 'draft' | 'published';
  featuredImage?: string;
}

interface GetAllPostsOptions {
  page: number;
  pageSize: number;
  tag?: string;
  search?: string;
  sort: string;
  order: 'asc' | 'desc';
}

class PostService {
  /**
   * Get all published posts with pagination and filtering
   */
  async getAllPosts(options: GetAllPostsOptions) {
    const { page, pageSize, tag, search, sort, order } = options;

    // Build query
    const query: any = { status: 'published' };

    if (tag) {
      query.tags = tag;
    }

    if (search) {
      query.$text = { $search: search };
    }

    // Build sort
    const sortOrder = order === 'asc' ? 1 : -1;
    const sortOptions: any = {};
    
    if (search) {
      // Sort by text relevance score when searching
      sortOptions.score = { $meta: 'textScore' };
    } else {
      sortOptions[sort] = sortOrder;
    }

    // Execute query
    const skip = (page - 1) * pageSize;

    const [posts, totalCount] = await Promise.all([
      Post.find(query)
        .select('-content -comments') // Exclude full content and comments from list
        .sort(sortOptions)
        .skip(skip)
        .limit(pageSize)
        .lean(),
      Post.countDocuments(query),
    ]);

    return {
      data: posts,
      pagination: {
        page,
        pageSize,
        totalCount,
        totalPages: Math.ceil(totalCount / pageSize),
      },
    };
  }

  /**
   * Get single post by slug (with comments)
   */
  async getPostBySlug(slug: string, userEntraId?: string): Promise<IPost> {
    const post = await Post.findOne({ slug });

    if (!post) {
      throw new NotFoundError('Post not found');
    }

    // Check access permissions for draft posts
    if (post.status === 'draft') {
      if (!userEntraId) {
        throw new ForbiddenError('Authentication required to view draft posts');
      }

      // Get user to compare author
      const user = await User.findOne({ entraUserId: userEntraId });
      if (!user || post.authorId.toString() !== user._id.toString()) {
        throw new ForbiddenError('Not authorized to view this draft post');
      }
    }

    // Increment view count (only for published posts)
    if (post.status === 'published') {
      post.viewCount += 1;
      await post.save();
    }

    return post;
  }

  /**
   * Create new post
   */
  async createPost(data: CreatePostDTO): Promise<IPost> {
    const { title, content, tags, status, featuredImage, authorEntraId, authorName } = data;

    // Get author user ID
    const author = await User.findOne({ entraUserId: authorEntraId });
    if (!author) {
      throw new NotFoundError('Author user not found');
    }

    // Generate slug
    const baseSlug = generateSlug(title);
    const slug = await ensureUniqueSlug(baseSlug);

    // Calculate metadata
    const wordCount = countWords(content);
    const readingTimeMinutes = calculateReadingTime(wordCount);
    const excerpt = generateExcerpt(content);

    // Create post
    const post = await Post.create({
      title,
      slug,
      content,
      excerpt,
      authorId: author._id,
      authorName,
      tags: tags || [],
      status,
      publishedAt: status === 'published' ? new Date() : undefined,
      viewCount: 0,
      comments: [],
      metadata: {
        readingTimeMinutes,
        wordCount,
        featuredImage,
      },
    });

    return post;
  }

  /**
   * Update existing post
   */
  async updatePost(postId: string, data: UpdatePostDTO): Promise<IPost> {
    const post = await Post.findById(postId);

    if (!post) {
      throw new NotFoundError('Post not found');
    }

    // Update fields
    if (data.title !== undefined) {
      post.title = data.title;
      
      // Regenerate slug if title changed
      const baseSlug = generateSlug(data.title);
      post.slug = await ensureUniqueSlug(baseSlug, postId);
    }

    if (data.content !== undefined) {
      post.content = data.content;
      
      // Recalculate metadata
      const wordCount = countWords(data.content);
      post.metadata.wordCount = wordCount;
      post.metadata.readingTimeMinutes = calculateReadingTime(wordCount);
      post.excerpt = generateExcerpt(data.content);
    }

    if (data.tags !== undefined) {
      post.tags = data.tags;
    }

    if (data.status !== undefined) {
      const wasPublished = post.status === 'published';
      const nowPublished = data.status === 'published';

      post.status = data.status;

      // Set publishedAt when first published
      if (!wasPublished && nowPublished) {
        post.publishedAt = new Date();
      }
    }

    if (data.featuredImage !== undefined) {
      post.metadata.featuredImage = data.featuredImage;
    }

    await post.save();

    return post;
  }

  /**
   * Delete post
   */
  async deletePost(postId: string): Promise<void> {
    const result = await Post.deleteOne({ _id: postId });

    if (result.deletedCount === 0) {
      throw new NotFoundError('Post not found');
    }
  }

  /**
   * Get posts by user
   */
  async getPostsByUser(
    userId: string,
    page: number,
    pageSize: number,
    status?: 'draft' | 'published',
    requestingUserEntraId?: string
  ) {
    // Build query
    const query: any = { authorId: userId };

    // Filter by status if specified
    if (status) {
      query.status = status;

      // Draft posts only visible to author
      if (status === 'draft') {
        if (!requestingUserEntraId) {
          throw new ForbiddenError('Authentication required to view draft posts');
        }

        const user = await User.findOne({ entraUserId: requestingUserEntraId });
        if (!user || user._id.toString() !== userId) {
          throw new ForbiddenError('Not authorized to view draft posts');
        }
      }
    } else {
      // If no status specified, only show published to non-owners
      if (!requestingUserEntraId) {
        query.status = 'published';
      } else {
        const user = await User.findOne({ entraUserId: requestingUserEntraId });
        if (!user || user._id.toString() !== userId) {
          query.status = 'published';
        }
      }
    }

    // Execute query
    const skip = (page - 1) * pageSize;

    const [posts, totalCount] = await Promise.all([
      Post.find(query)
        .select('-content -comments')
        .sort({ publishedAt: -1, createdAt: -1 })
        .skip(skip)
        .limit(pageSize)
        .lean(),
      Post.countDocuments(query),
    ]);

    return {
      data: posts,
      pagination: {
        page,
        pageSize,
        totalCount,
        totalPages: Math.ceil(totalCount / pageSize),
      },
    };
  }
}

export const postService = new PostService();
```

### Comment Service

```typescript
// src/services/comment.service.ts
import { Post, IComment } from '../models/Post.model';
import { User } from '../models/User.model';
import { NotFoundError } from '../utils/errors.util';
import { Types } from 'mongoose';

interface AddCommentDTO {
  postId: string;
  content: string;
  userId: string; // Entra ID user ID
  userName: string;
}

class CommentService {
  /**
   * Add comment to post
   */
  async addComment(data: AddCommentDTO): Promise<IComment> {
    const { postId, content, userId, userName } = data;

    // Verify post exists
    const post = await Post.findById(postId);
    if (!post) {
      throw new NotFoundError('Post not found');
    }

    // Get user MongoDB ID
    const user = await User.findOne({ entraUserId: userId });
    if (!user) {
      throw new NotFoundError('User not found');
    }

    // Create comment
    const comment = {
      _id: new Types.ObjectId(),
      userId: user._id,
      userName,
      content,
      createdAt: new Date(),
      updatedAt: new Date(),
      isEdited: false,
    };

    // Add comment to post
    post.comments.push(comment as any);
    await post.save();

    return comment as IComment;
  }

  /**
   * Delete comment from post
   */
  async deleteComment(postId: string, commentId: string): Promise<void> {
    const post = await Post.findById(postId);

    if (!post) {
      throw new NotFoundError('Post not found');
    }

    const comment = post.comments.id(commentId);

    if (!comment) {
      throw new NotFoundError('Comment not found');
    }

    // Remove comment (authorization checked in middleware)
    comment.deleteOne();
    await post.save();
  }
}

export const commentService = new CommentService();
```

---

## Routes Configuration

### Route Organization

```typescript
// src/routes/auth.routes.ts
import { Router } from 'express';
import { register, getCurrentUser } from '../controllers/auth.controller';
import { authenticateJWT } from '../middleware/auth.middleware';

const router = Router();

router.post('/register', authenticateJWT, register);
router.get('/me', authenticateJWT, getCurrentUser);

export default router;
```

```typescript
// src/routes/posts.routes.ts
import { Router } from 'express';
import { body } from 'express-validator';
import {
  getAllPosts,
  getPostBySlug,
  createPost,
  updatePost,
  deletePost,
} from '../controllers/posts.controller';
import { authenticateJWT, optionalAuth } from '../middleware/auth.middleware';
import { isPostAuthor } from '../middleware/authorization.middleware';
import { validateRequest } from '../middleware/validation.middleware';

const router = Router();

// Validation rules
const createPostValidation = validateRequest([
  body('title').isString().trim().isLength({ min: 5, max: 200 }),
  body('content').isString().trim().isLength({ min: 50 }),
  body('tags').optional().isArray({ max: 5 }),
  body('tags.*').isString().trim().isLength({ min: 1, max: 30 }),
  body('status').isIn(['draft', 'published']),
  body('featuredImage').optional().isURL(),
]);

const updatePostValidation = validateRequest([
  body('title').optional().isString().trim().isLength({ min: 5, max: 200 }),
  body('content').optional().isString().trim().isLength({ min: 50 }),
  body('tags').optional().isArray({ max: 5 }),
  body('tags.*').optional().isString().trim().isLength({ min: 1, max: 30 }),
  body('status').optional().isIn(['draft', 'published']),
  body('featuredImage').optional().isURL(),
]);

// Routes
router.get('/', optionalAuth, getAllPosts);
router.get('/:slug', optionalAuth, getPostBySlug);
router.post('/', authenticateJWT, createPostValidation, createPost);
router.put('/:postId', authenticateJWT, isPostAuthor, updatePostValidation, updatePost);
router.delete('/:postId', authenticateJWT, isPostAuthor, deletePost);

export default router;
```

```typescript
// src/routes/comments.routes.ts
import { Router } from 'express';
import { body } from 'express-validator';
import { addComment, deleteComment } from '../controllers/comments.controller';
import { authenticateJWT } from '../middleware/auth.middleware';
import { canDeleteComment } from '../middleware/authorization.middleware';
import { validateRequest } from '../middleware/validation.middleware';

const router = Router();

const addCommentValidation = validateRequest([
  body('content').isString().trim().isLength({ min: 1, max: 1000 }),
]);

router.post('/:postId/comments', authenticateJWT, addCommentValidation, addComment);
router.delete('/:postId/comments/:commentId', authenticateJWT, canDeleteComment, deleteComment);

export default router;
```

```typescript
// src/routes/users.routes.ts
import { Router } from 'express';
import { authService } from '../services/auth.service';
import { postService } from '../services/post.service';
import { optionalAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../middleware/error.middleware';

const router = Router();

router.get(
  '/:userId',
  asyncHandler(async (req, res) => {
    const user = await authService.getUserById(req.params.userId);
    res.json({ data: user });
  })
);

router.get(
  '/:userId/posts',
  optionalAuth,
  asyncHandler(async (req, res) => {
    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const pageSize = Math.min(parseInt(req.query.pageSize as string) || 10, 50);
    const status = req.query.status as 'draft' | 'published' | undefined;
    const requestingUserEntraId = req.user?.userId;

    const result = await postService.getPostsByUser(
      userId,
      page,
      pageSize,
      status,
      requestingUserEntraId
    );

    res.json(result);
  })
);

export default router;
```

```typescript
// src/routes/health.routes.ts
import { Router } from 'express';
import mongoose from 'mongoose';
import { asyncHandler } from '../middleware/error.middleware';

const router = Router();

router.get(
  '/',
  asyncHandler(async (req, res) => {
    // Ping MongoDB
    try {
      await mongoose.connection.db.admin().ping();

      res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        database: 'connected',
        uptime: process.uptime(),
      });
    } catch (error) {
      res.status(503).json({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        error: (error as Error).message,
      });
    }
  })
);

router.get(
  '/ready',
  asyncHandler(async (req, res) => {
    const isReady = mongoose.connection.readyState === 1;

    if (isReady) {
      res.status(200).json({
        ready: true,
        database: 'connected',
        models: 'loaded',
      });
    } else {
      res.status(503).json({
        ready: false,
        database: 'disconnected',
      });
    }
  })
);

export default router;
```

```typescript
// src/routes/index.ts
import { Router } from 'express';
import authRoutes from './auth.routes';
import usersRoutes from './users.routes';
import postsRoutes from './posts.routes';
import commentsRoutes from './comments.routes';
import healthRoutes from './health.routes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/users', usersRoutes);
router.use('/posts', postsRoutes);
router.use('/posts', commentsRoutes); // Nested under posts
router.use('/health', healthRoutes);

export default router;
```

---

## Application Setup

### Express App Configuration

```typescript
// src/app.ts
import express, { Express } from 'express';
import compression from 'compression';
import { securityHeaders, corsOptions, rateLimiter } from './middleware/security.middleware';
import { requestLogger } from './middleware/logger.middleware';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';
import routes from './routes';

/**
 * Create and configure Express application
 */
export const createApp = (): Express => {
  const app = express();

  // Security middleware
  app.use(securityHeaders);
  app.use(corsOptions);
  app.use(rateLimiter);

  // Compression
  app.use(compression());

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging
  app.use(requestLogger);

  // API routes
  app.use('/api', routes);

  // 404 handler
  app.use(notFoundHandler);

  // Error handler (must be last)
  app.use(errorHandler);

  return app;
};
```

### Server Entry Point

```typescript
// src/server.ts
import { createApp } from './app';
import { connectDatabase, disconnectDatabase } from './config/database';
import { logger } from './utils/logger.util';

const PORT = process.env.PORT || 3000;

/**
 * Start server
 */
async function startServer() {
  try {
    // Connect to database
    await connectDatabase();

    // Create Express app
    const app = createApp();

    // Start listening
    const server = app.listen(PORT, () => {
      logger.info(`Server started on port ${PORT}`, {
        environment: process.env.NODE_ENV,
        port: PORT,
      });
    });

    // Graceful shutdown
    process.on('SIGTERM', async () => {
      logger.info('SIGTERM received, shutting down gracefully');

      server.close(async () => {
        logger.info('HTTP server closed');

        await disconnectDatabase();

        process.exit(0);
      });

      // Force shutdown after 10 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 10000);
    });

    process.on('SIGINT', async () => {
      logger.info('SIGINT received, shutting down gracefully');

      server.close(async () => {
        await disconnectDatabase();
        process.exit(0);
      });
    });

  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
}

// Start server
startServer();
```

---

## Testing Strategy

### Testing Framework Setup

```typescript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/server.ts',
    '!src/types/**',
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 80,
      statements: 80,
    },
  },
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
};
```

### Test Setup

```typescript
// tests/setup.ts
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';

let mongoServer: MongoMemoryServer;

// Connect to in-memory MongoDB before all tests
beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();

  await mongoose.connect(mongoUri);
});

// Clear database between tests
afterEach(async () => {
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key].deleteMany({});
  }
});

// Disconnect and stop MongoDB after all tests
afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});
```

### Unit Test Examples

```typescript
// tests/unit/services/post.service.test.ts
import { postService } from '../../../src/services/post.service';
import { Post } from '../../../src/models/Post.model';
import { User } from '../../../src/models/User.model';
import { NotFoundError } from '../../../src/utils/errors.util';

describe('PostService', () => {
  describe('createPost', () => {
    it('should create a new post with generated slug', async () => {
      // Arrange
      const user = await User.create({
        entraUserId: 'test-user-id',
        email: 'test@example.com',
        displayName: 'Test User',
        isActive: true,
        role: 'user',
      });

      const postData = {
        title: 'My Test Post',
        content: 'This is a test post with enough content to meet the minimum requirement.',
        tags: ['test', 'jest'],
        status: 'published' as const,
        authorEntraId: 'test-user-id',
        authorName: 'Test User',
      };

      // Act
      const post = await postService.createPost(postData);

      // Assert
      expect(post).toBeDefined();
      expect(post.title).toBe('My Test Post');
      expect(post.slug).toBe('my-test-post');
      expect(post.status).toBe('published');
      expect(post.publishedAt).toBeDefined();
      expect(post.metadata.wordCount).toBeGreaterThan(0);
      expect(post.metadata.readingTimeMinutes).toBeGreaterThan(0);
    });

    it('should throw NotFoundError if author does not exist', async () => {
      // Arrange
      const postData = {
        title: 'Test Post',
        content: 'Test content with enough words to pass validation requirements.',
        status: 'draft' as const,
        authorEntraId: 'non-existent-user',
        authorName: 'Ghost User',
      };

      // Act & Assert
      await expect(postService.createPost(postData)).rejects.toThrow(NotFoundError);
    });

    it('should generate unique slug when title already exists', async () => {
      // Arrange
      const user = await User.create({
        entraUserId: 'test-user-id',
        email: 'test@example.com',
        displayName: 'Test User',
        isActive: true,
        role: 'user',
      });

      await Post.create({
        title: 'Duplicate Title',
        slug: 'duplicate-title',
        content: 'First post content with enough words.',
        excerpt: 'First post',
        authorId: user._id,
        authorName: 'Test User',
        status: 'published',
        publishedAt: new Date(),
        viewCount: 0,
        comments: [],
        metadata: {
          readingTimeMinutes: 1,
          wordCount: 100,
        },
      });

      const postData = {
        title: 'Duplicate Title',
        content: 'Second post content with enough words to pass validation.',
        status: 'published' as const,
        authorEntraId: 'test-user-id',
        authorName: 'Test User',
      };

      // Act
      const post = await postService.createPost(postData);

      // Assert
      expect(post.slug).toBe('duplicate-title-1');
    });
  });

  describe('getPostBySlug', () => {
    it('should return post and increment view count', async () => {
      // Arrange
      const user = await User.create({
        entraUserId: 'test-user-id',
        email: 'test@example.com',
        displayName: 'Test User',
        isActive: true,
        role: 'user',
      });

      const post = await Post.create({
        title: 'Test Post',
        slug: 'test-post',
        content: 'Test content',
        excerpt: 'Test',
        authorId: user._id,
        authorName: 'Test User',
        status: 'published',
        publishedAt: new Date(),
        viewCount: 5,
        comments: [],
        metadata: {
          readingTimeMinutes: 1,
          wordCount: 100,
        },
      });

      // Act
      const result = await postService.getPostBySlug('test-post');

      // Assert
      expect(result.viewCount).toBe(6);
    });

    it('should throw NotFoundError for non-existent slug', async () => {
      // Act & Assert
      await expect(postService.getPostBySlug('non-existent')).rejects.toThrow(NotFoundError);
    });
  });
});
```

### Integration Test Examples

```typescript
// tests/integration/posts.test.ts
import request from 'supertest';
import { createApp } from '../../src/app';
import { User } from '../../src/models/User.model';
import { Post } from '../../src/models/Post.model';
import jwt from 'jsonwebtoken';

const app = createApp();

// Mock JWT validation for testing
jest.mock('../../src/middleware/auth.middleware', () => ({
  authenticateJWT: (req: any, res: any, next: any) => {
    req.user = {
      userId: 'test-user-entra-id',
      email: 'test@example.com',
      displayName: 'Test User',
    };
    next();
  },
  optionalAuth: (req: any, res: any, next: any) => {
    next();
  },
}));

describe('POST /api/posts', () => {
  it('should create a new post', async () => {
    // Arrange
    await User.create({
      entraUserId: 'test-user-entra-id',
      email: 'test@example.com',
      displayName: 'Test User',
      isActive: true,
      role: 'user',
    });

    const postData = {
      title: 'Integration Test Post',
      content: 'This is an integration test post with sufficient content length.',
      tags: ['test', 'integration'],
      status: 'published',
    };

    // Act
    const response = await request(app)
      .post('/api/posts')
      .send(postData)
      .expect(201);

    // Assert
    expect(response.body.data).toHaveProperty('_id');
    expect(response.body.data.title).toBe('Integration Test Post');
    expect(response.body.data.slug).toBe('integration-test-post');
    expect(response.body.data.status).toBe('published');
  });

  it('should return 400 for invalid post data', async () => {
    // Arrange
    const invalidData = {
      title: 'Too short',
      content: 'Short',
      status: 'published',
    };

    // Act
    const response = await request(app)
      .post('/api/posts')
      .send(invalidData)
      .expect(400);

    // Assert
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});

describe('GET /api/posts', () => {
  it('should return paginated published posts', async () => {
    // Arrange
    const user = await User.create({
      entraUserId: 'test-user-id',
      email: 'test@example.com',
      displayName: 'Test User',
      isActive: true,
      role: 'user',
    });

    // Create 15 test posts
    for (let i = 1; i <= 15; i++) {
      await Post.create({
        title: `Test Post ${i}`,
        slug: `test-post-${i}`,
        content: 'Test content with sufficient length for validation.',
        excerpt: 'Test excerpt',
        authorId: user._id,
        authorName: 'Test User',
        status: 'published',
        publishedAt: new Date(),
        viewCount: 0,
        comments: [],
        metadata: {
          readingTimeMinutes: 1,
          wordCount: 100,
        },
      });
    }

    // Act
    const response = await request(app)
      .get('/api/posts?page=1&pageSize=10')
      .expect(200);

    // Assert
    expect(response.body.data).toHaveLength(10);
    expect(response.body.pagination.totalCount).toBe(15);
    expect(response.body.pagination.totalPages).toBe(2);
  });
});
```

---

## Deployment Configuration

### Production Build

```json
// package.json
{
  "name": "blogapp-backend",
  "version": "1.0.0",
  "description": "Blog application API for Azure IaaS Workshop",
  "main": "dist/server.js",
  "scripts": {
    "dev": "ts-node-dev --respawn --transpile-only src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "format": "prettier --write \"src/**/*.ts\"",
    "type-check": "tsc --noEmit",
    "seed": "ts-node scripts/seed-database.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^8.0.0",
    "jsonwebtoken": "^9.0.2",
    "jwks-rsa": "^3.1.0",
    "express-validator": "^7.0.1",
    "helmet": "^7.1.0",
    "cors": "^2.8.5",
    "express-rate-limit": "^7.1.5",
    "compression": "^1.7.4",
    "winston": "^3.11.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^20.10.0",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/cors": "^2.8.17",
    "@types/compression": "^1.7.5",
    "@types/jest": "^29.5.11",
    "@types/supertest": "^6.0.2",
    "typescript": "^5.3.3",
    "ts-node": "^10.9.2",
    "ts-node-dev": "^2.0.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.1",
    "supertest": "^6.3.3",
    "mongodb-memory-server": "^9.1.3",
    "eslint": "^8.55.0",
    "@typescript-eslint/eslint-plugin": "^6.14.0",
    "@typescript-eslint/parser": "^6.14.0",
    "prettier": "^3.1.1"
  },
  "engines": {
    "node": ">=20.0.0",
    "npm": ">=9.0.0"
  }
}
```

### TypeScript Configuration

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "node",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

### ESLint Configuration

```javascript
// .eslintrc.js
module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
    project: './tsconfig.json',
  },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/recommended-requiring-type-checking',
  ],
  plugins: ['@typescript-eslint'],
  env: {
    node: true,
    es2022: true,
  },
  rules: {
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/no-explicit-any': 'warn',
    'no-console': ['warn', { allow: ['warn', 'error'] }],
    'prefer-const': 'error',
    'no-var': 'error',
  },
};
```

### Systemd Service Configuration

**Purpose**: Run Node.js app as a service on Azure VMs

```ini
# /etc/systemd/system/blogapp-api.service

[Unit]
Description=Blog Application API Server
Documentation=https://github.com/your-org/azure-iaas-workshop
After=network.target mongod.service
Wants=mongod.service

[Service]
Type=simple
User=blogapp
Group=blogapp
WorkingDirectory=/opt/blogapp/backend
Environment=NODE_ENV=production

# Environment variables (alternatively use EnvironmentFile)
Environment=PORT=3000
Environment=MONGODB_URI=mongodb://blogapp_api_user:PASSWORD@10.0.3.4:27018,10.0.3.5:27018/blogapp?replicaSet=blogapp-rs0&readPreference=primaryPreferred&w=majority
Environment=ENTRA_TENANT_ID=your-tenant-id
Environment=ENTRA_CLIENT_ID=your-client-id
Environment=CORS_ORIGIN=http://10.0.1.4,http://10.0.1.5

# Alternatively, use environment file
# EnvironmentFile=/opt/blogapp/backend/.env

ExecStart=/usr/bin/node /opt/blogapp/backend/dist/server.js

# Restart policy
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=blogapp-api

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

**Service Management Commands**:
```bash
# Enable service to start on boot
sudo systemctl enable blogapp-api

# Start service
sudo systemctl start blogapp-api

# Check status
sudo systemctl status blogapp-api

# View logs
sudo journalctl -u blogapp-api -f

# Restart service (after deployment)
sudo systemctl restart blogapp-api

# Stop service
sudo systemctl stop blogapp-api
```

### NGINX Reverse Proxy Configuration

**Purpose**: Proxy requests from web tier to app tier

```nginx
# /etc/nginx/sites-available/blogapp-api (on web tier VMs)

upstream backend_api {
    # App tier VMs
    server 10.0.2.4:3000 max_fails=3 fail_timeout=30s;
    server 10.0.2.5:3000 max_fails=3 fail_timeout=30s;
    
    # Keepalive connections
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    # API endpoints
    location /api/ {
        proxy_pass http://backend_api;
        
        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Keepalive
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Health check for load balancer
    location /health {
        proxy_pass http://backend_api/api/health;
        access_log off;
    }

    # Frontend static files (React app)
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        
        # Caching for static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

### Deployment Scripts

#### Build and Deploy Script

```bash
#!/bin/bash
# scripts/deploy.sh
# Deploy backend API to Azure VMs

set -e  # Exit on error

echo "Starting deployment..."

# Configuration
APP_USER="blogapp"
APP_DIR="/opt/blogapp/backend"
BACKUP_DIR="/opt/blogapp/backups"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Create backup
echo "Creating backup..."
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR
if [ -d "$APP_DIR/dist" ]; then
    tar -czf "$BACKUP_DIR/backup-$TIMESTAMP.tar.gz" -C "$APP_DIR" dist
    echo -e "${GREEN}Backup created: $BACKUP_DIR/backup-$TIMESTAMP.tar.gz${NC}"
fi

# Stop service
echo "Stopping blogapp-api service..."
systemctl stop blogapp-api || true

# Install dependencies
echo "Installing dependencies..."
cd $APP_DIR
sudo -u $APP_USER npm ci --production

# Build TypeScript
echo "Building application..."
sudo -u $APP_USER npm run build

# Verify build
if [ ! -f "$APP_DIR/dist/server.js" ]; then
    echo -e "${RED}Build failed: dist/server.js not found${NC}"
    exit 1
fi

# Start service
echo "Starting blogapp-api service..."
systemctl start blogapp-api

# Wait for service to be ready
echo "Waiting for service to be ready..."
sleep 5

# Check service status
if systemctl is-active --quiet blogapp-api; then
    echo -e "${GREEN}Deployment successful!${NC}"
    systemctl status blogapp-api --no-pager
else
    echo -e "${RED}Service failed to start${NC}"
    journalctl -u blogapp-api -n 50 --no-pager
    exit 1
fi

# Health check
echo "Running health check..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health)
if [ "$HEALTH_CHECK" -eq 200 ]; then
    echo -e "${GREEN}Health check passed${NC}"
else
    echo -e "${RED}Health check failed (HTTP $HEALTH_CHECK)${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
```

#### Rollback Script

```bash
#!/bin/bash
# scripts/rollback.sh
# Rollback to previous deployment

set -e

APP_DIR="/opt/blogapp/backend"
BACKUP_DIR="/opt/blogapp/backups"

# Get latest backup
LATEST_BACKUP=$(ls -t $BACKUP_DIR/backup-*.tar.gz | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "No backup found"
    exit 1
fi

echo "Rolling back to: $LATEST_BACKUP"

# Stop service
systemctl stop blogapp-api

# Remove current build
rm -rf $APP_DIR/dist

# Restore backup
tar -xzf $LATEST_BACKUP -C $APP_DIR

# Start service
systemctl start blogapp-api

echo "Rollback completed"
```

---

## CI/CD with GitHub Actions

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy-backend.yml
name: Deploy Backend API

on:
  push:
    branches:
      - main
    paths:
      - 'backend/**'
      - '.github/workflows/deploy-backend.yml'
  workflow_dispatch:

env:
  NODE_VERSION: '20.x'

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    
    services:
      mongodb:
        image: mongo:7.0
        ports:
          - 27017:27017
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - name: Install dependencies
        working-directory: backend
        run: npm ci
      
      - name: Run linter
        working-directory: backend
        run: npm run lint
      
      - name: Type check
        working-directory: backend
        run: npm run type-check
      
      - name: Run tests
        working-directory: backend
        run: npm run test:coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: backend/coverage/lcov.info
          flags: backend

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: test
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - name: Install dependencies
        working-directory: backend
        run: npm ci
      
      - name: Build
        working-directory: backend
        run: npm run build
      
      - name: Archive build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: backend-dist
          path: |
            backend/dist
            backend/package.json
            backend/package-lock.json
          retention-days: 7

  deploy:
    name: Deploy to Azure VMs
    runs-on: ubuntu-latest
    needs: build
    environment: production
    
    strategy:
      matrix:
        vm: [app-vm-az1, app-vm-az2]
    
    steps:
      - name: Download build artifacts
        uses: actions/download-artifact@v3
        with:
          name: backend-dist
          path: backend
      
      - name: Deploy to ${{ matrix.vm }}
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          VM_IP: ${{ secrets[format('VM_IP_{0}', matrix.vm)] }}
        run: |
          # Setup SSH
          mkdir -p ~/.ssh
          echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          ssh-keyscan -H $VM_IP >> ~/.ssh/known_hosts
          
          # Create deployment package
          cd backend
          tar -czf deploy.tar.gz dist package.json package-lock.json
          
          # Upload to VM
          scp deploy.tar.gz blogapp@$VM_IP:/tmp/
          
          # Deploy on VM
          ssh blogapp@$VM_IP << 'EOF'
            set -e
            cd /opt/blogapp/backend
            
            # Backup current version
            if [ -d dist ]; then
              tar -czf ~/backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz dist
            fi
            
            # Extract new version
            tar -xzf /tmp/deploy.tar.gz
            
            # Install dependencies
            npm ci --production
            
            # Restart service
            sudo systemctl restart blogapp-api
            
            # Wait and health check
            sleep 5
            curl -f http://localhost:3000/api/health || exit 1
            
            # Cleanup
            rm /tmp/deploy.tar.gz
          EOF
      
      - name: Verify deployment
        env:
          VM_IP: ${{ secrets[format('VM_IP_{0}', matrix.vm)] }}
        run: |
          # Wait for service to stabilize
          sleep 10
          
          # Health check via SSH tunnel
          ssh blogapp@$VM_IP 'curl -f http://localhost:3000/api/health'
```

---

## Monitoring & Operations

### Logging Strategy

**Log Levels**:
- **error**: Failures requiring immediate attention
- **warn**: Potential issues or deprecated usage
- **info**: General application flow, requests, successful operations
- **debug**: Detailed debugging information (development only)

**Log Format** (JSON for production):
```json
{
  "timestamp": "2025-12-01T10:30:45.123Z",
  "level": "info",
  "service": "blogapp-api",
  "environment": "production",
  "message": "Request completed",
  "method": "GET",
  "path": "/api/posts",
  "statusCode": 200,
  "duration": "45ms",
  "userId": "a1b2c3d4-...",
  "ip": "10.0.1.4"
}
```

**Log Destinations**:
- **Console**: All logs (captured by systemd journal)
- **File**: `/var/log/blogapp/combined.log` (all logs)
- **File**: `/var/log/blogapp/error.log` (errors only)
- **Azure Monitor**: Via Azure Monitor Agent (syslog integration)

### Application Monitoring

**Metrics to Track**:
- **Request Metrics**:
  - Requests per minute
  - Response times (p50, p95, p99)
  - Error rates (4xx, 5xx)
  - Endpoint-specific metrics

- **Database Metrics**:
  - Query response times
  - Connection pool utilization
  - MongoDB replica set status
  - Slow queries (> 100ms)

- **System Metrics**:
  - CPU usage
  - Memory usage
  - Event loop lag
  - Garbage collection metrics

**Custom Metrics Implementation**:

```typescript
// src/utils/metrics.util.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from './logger.util';

interface RequestMetrics {
  endpoint: string;
  method: string;
  statusCode: number;
  duration: number;
  timestamp: Date;
}

class MetricsCollector {
  private requestMetrics: RequestMetrics[] = [];

  recordRequest(req: Request, res: Response, duration: number) {
    const metric: RequestMetrics = {
      endpoint: req.route?.path || req.path,
      method: req.method,
      statusCode: res.statusCode,
      duration,
      timestamp: new Date(),
    };

    this.requestMetrics.push(metric);

    // Log slow requests
    if (duration > 1000) {
      logger.warn('Slow request detected', {
        endpoint: metric.endpoint,
        method: metric.method,
        duration: `${duration}ms`,
      });
    }
  }

  getMetrics() {
    // Calculate aggregates
    const totalRequests = this.requestMetrics.length;
    const avgDuration =
      this.requestMetrics.reduce((sum, m) => sum + m.duration, 0) / totalRequests;

    const errorCount = this.requestMetrics.filter((m) => m.statusCode >= 400).length;

    return {
      totalRequests,
      avgDuration,
      errorRate: (errorCount / totalRequests) * 100,
      lastMinute: this.requestMetrics.filter(
        (m) => m.timestamp > new Date(Date.now() - 60000)
      ).length,
    };
  }

  // Clear old metrics (call periodically)
  cleanup() {
    const cutoff = new Date(Date.now() - 3600000); // 1 hour
    this.requestMetrics = this.requestMetrics.filter((m) => m.timestamp > cutoff);
  }
}

export const metricsCollector = new MetricsCollector();

// Metrics middleware
export const metricsMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - startTime;
    metricsCollector.recordRequest(req, res, duration);
  });

  next();
};
```

### Health Monitoring

**Load Balancer Health Probe Configuration**:
- **Endpoint**: `GET /api/health`
- **Interval**: 15 seconds
- **Timeout**: 5 seconds
- **Unhealthy threshold**: 2 consecutive failures
- **Healthy threshold**: 2 consecutive successes

**Health Check Response Criteria**:
- HTTP 200: Healthy (MongoDB connected, app running)
- HTTP 503: Unhealthy (MongoDB disconnected or app error)

### Alert Rules

**Critical Alerts** (Immediate action required):
- API health check failures (> 2 consecutive)
- Error rate > 10% (5xx errors)
- MongoDB connection lost
- Memory usage > 90%
- Service down (systemd)

**Warning Alerts** (Monitor closely):
- Average response time > 500ms
- Error rate > 5%
- MongoDB replication lag > 60 seconds
- Memory usage > 80%
- CPU usage > 80% for 5+ minutes

**Azure Monitor Alert Configuration**:
```bash
# Example: Create alert for high error rate
az monitor metrics alert create \
  --name "blogapp-api-high-error-rate" \
  --resource-group rg-blogapp-prod-eastus \
  --scopes /subscriptions/{subscription-id}/resourceGroups/rg-blogapp-prod-eastus \
  --condition "count logName_CL > 10 where severity == 'error'" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/{subscription-id}/resourceGroups/rg-blogapp-prod-eastus/providers/microsoft.insights/actionGroups/blogapp-alerts
```

---

## Security Best Practices

### Input Validation

**Validation Strategy**:
- Validate all user inputs (body, query, params)
- Use express-validator or Zod for schema validation
- Sanitize inputs to prevent injection attacks
- Validate data types, lengths, formats

**Example Validation**:
```typescript
// Strong validation for post creation
const createPostValidation = [
  body('title')
    .isString()
    .trim()
    .isLength({ min: 5, max: 200 })
    .withMessage('Title must be 5-200 characters')
    .escape(), // Sanitize HTML entities
  
  body('content')
    .isString()
    .trim()
    .isLength({ min: 50 })
    .withMessage('Content must be at least 50 characters'),
  
  body('tags')
    .optional()
    .isArray({ max: 5 })
    .withMessage('Maximum 5 tags allowed'),
  
  body('tags.*')
    .isString()
    .trim()
    .isLength({ min: 1, max: 30 })
    .matches(/^[a-zA-Z0-9-]+$/)
    .withMessage('Tags must be alphanumeric with hyphens'),
];
```

### Authentication Security

**JWT Token Validation Checklist**:
- ✅ Verify signature using JWKS (Microsoft's public keys)
- ✅ Check token expiration (`exp` claim)
- ✅ Validate audience (`aud` claim matches API client ID)
- ✅ Validate issuer (`iss` claim is Microsoft Entra ID)
- ✅ Check token is not used before valid (`nbf` claim)
- ✅ Extract user ID from `oid` claim (not from request body)

**Security Headers** (via Helmet):
```typescript
{
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"], // Allow inline styles if needed
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      frameAncestors: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
  frameguard: { action: 'deny' },
  noSniff: true,
  xssFilter: true,
}
```

### Rate Limiting

**Rate Limit Configuration**:
```typescript
// General API rate limit
const generalRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per window
  message: 'Too many requests, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter limit for auth endpoints
const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10, // 10 requests per window
  message: 'Too many authentication attempts',
});

// Apply to routes
app.use('/api', generalRateLimit);
app.use('/api/auth', authRateLimit);
```

### Secrets Management

**Best Practices**:
- ✅ Never commit secrets to Git (use .gitignore)
- ✅ Use Azure Key Vault for production secrets
- ✅ Use environment variables for configuration
- ✅ Rotate secrets regularly (MongoDB passwords, JWT keys)
- ✅ Use managed identities for Azure resource access

**Azure Key Vault Integration** (optional):
```typescript
// src/config/keyvault.ts
import { SecretClient } from '@azure/keyvault-secrets';
import { DefaultAzureCredential } from '@azure/identity';

const credential = new DefaultAzureCredential();
const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
const client = new SecretClient(vaultUrl, credential);

export async function getSecret(secretName: string): Promise<string> {
  const secret = await client.getSecret(secretName);
  return secret.value!;
}

// Usage
const mongoPassword = await getSecret('mongodb-api-password');
```

---

## Workshop Integration

### Day 1, Step 3: Deploy Backend API

**Student Learning Objectives**:
- Understand Node.js deployment on Azure VMs
- Configure systemd service for production
- Integrate with MongoDB replica set
- Validate JWT tokens from Entra ID

**Student Tasks** (45-60 minutes):

1. **SSH to App Tier VM** (via Azure Bastion)
   ```bash
   # From Azure Portal or local machine
   az network bastion ssh --name bastion-blogapp \
     --resource-group rg-blogapp-prod-eastus \
     --target-resource-id /subscriptions/{sub-id}/resourceGroups/rg-blogapp-prod-eastus/providers/Microsoft.Compute/virtualMachines/vm-app01-prod \
     --auth-type password \
     --username azureuser
   ```

2. **Install Node.js 20.x**
   ```bash
   # Install NodeSource repository
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   
   # Install Node.js
   sudo apt-get install -y nodejs
   
   # Verify installation
   node --version  # Should be v20.x
   npm --version
   ```

3. **Create Application User and Directory**
   ```bash
   # Create dedicated user
   sudo useradd -r -s /bin/bash -d /opt/blogapp blogapp
   
   # Create directory structure
   sudo mkdir -p /opt/blogapp/backend
   sudo mkdir -p /var/log/blogapp
   sudo chown -R blogapp:blogapp /opt/blogapp
   sudo chown -R blogapp:blogapp /var/log/blogapp
   ```

4. **Deploy Backend Code** (from GitHub repository)
   ```bash
   # Clone repository
   cd /opt/blogapp
   sudo -u blogapp git clone https://github.com/{student-username}/azure-iaas-workshop.git temp
   sudo -u blogapp cp -r temp/materials/backend/* backend/
   sudo -u blogapp rm -rf temp
   ```

5. **Configure Environment Variables**
   ```bash
   cd /opt/blogapp/backend
   
   # Create .env file
   sudo -u blogapp tee .env > /dev/null <<EOF
   NODE_ENV=production
   PORT=3000
   
   MONGODB_URI=mongodb://blogapp_api_user:${MONGODB_PASSWORD}@10.0.3.4:27018,10.0.3.5:27018/blogapp?replicaSet=blogapp-rs0&readPreference=primaryPreferred&w=majority
   
   ENTRA_TENANT_ID=${AZURE_TENANT_ID}
   ENTRA_CLIENT_ID=${AZURE_CLIENT_ID}
   
   CORS_ORIGIN=http://10.0.1.4,http://10.0.1.5,http://${LOAD_BALANCER_IP}
   
   LOG_LEVEL=info
   LOG_FORMAT=json
   EOF
   
   # Secure .env file
   sudo chmod 600 /opt/blogapp/backend/.env
   ```

6. **Install Dependencies and Build**
   ```bash
   cd /opt/blogapp/backend
   
   # Install dependencies
   sudo -u blogapp npm ci --production
   
   # Build TypeScript
   sudo -u blogapp npm run build
   
   # Verify build
   ls -la dist/server.js
   ```

7. **Create Systemd Service**
   ```bash
   # Create service file (provided in workshop materials)
   sudo cp /opt/blogapp/backend/systemd/blogapp-api.service /etc/systemd/system/
   ```

8. **Start and Enable Service**
   ```bash
   # Reload systemd
   sudo systemctl daemon-reload
   
   # Enable service (start on boot)
   sudo systemctl enable blogapp-api
   
   # Start service
   sudo systemctl start blogapp-api
   
   # Check status
   sudo systemctl status blogapp-api
   
   # View logs
   sudo journalctl -u blogapp-api -f
   ```

9. **Test API Locally**
   ```bash
   # Health check
   curl http://localhost:3000/api/health
   
   # Should return:
   # {"status":"healthy","timestamp":"2025-12-01T...","database":"connected","uptime":123}
   
   # Get posts (should be empty initially)
   curl http://localhost:3000/api/posts
   ```

10. **Seed Database** (optional, for testing)
    ```bash
    cd /opt/blogapp/backend
    sudo -u blogapp npm run seed
    
    # Verify seed data
    curl http://localhost:3000/api/posts | jq '.data | length'
    # Should return 10 (seed posts)
    ```

11. **Repeat for Second App VM** (in AZ2)
    - SSH to vm-app02-prod
    - Execute steps 2-10
    - Verify both app VMs are running

**Success Criteria**:
- ✅ blogapp-api service running on both app VMs
- ✅ Health check returns HTTP 200
- ✅ Can fetch posts from API
- ✅ MongoDB connection successful (replica set)
- ✅ Service restarts on VM reboot

**Common Issues & Solutions**:

| Issue | Symptom | Solution |
|-------|---------|----------|
| MongoDB connection refused | 503 error, "database":"disconnected" | Check NSG allows port 27018 from app subnet, verify MongoDB running |
| JWT validation fails | 401 Unauthorized on authenticated endpoints | Verify ENTRA_CLIENT_ID and ENTRA_TENANT_ID are correct |
| Service won't start | systemctl status shows failed | Check journalctl logs, verify .env file exists and readable |
| CORS errors | Browser console shows CORS error | Verify CORS_ORIGIN includes frontend URLs |

### Day 2, Step 11: Test Application HA

**Student Tasks** (30 minutes):

1. **Test App Tier Failover**
   ```bash
   # Note current app VM handling requests
   for i in {1..10}; do curl -s http://${LOAD_BALANCER_IP}/api/health | jq -r '.uptime'; sleep 1; done
   
   # Stop blogapp-api on one VM
   ssh blogapp@10.0.2.4
   sudo systemctl stop blogapp-api
   
   # Observe traffic shifts to remaining VM
   # Load balancer should detect failure within 30 seconds
   
   # Restart service
   sudo systemctl start blogapp-api
   ```

2. **Monitor Application Logs**
   ```bash
   # View logs in Azure Portal
   # Log Analytics → Logs → Query:
   
   Syslog
   | where ProcessName == "blogapp-api"
   | where SeverityLevel in ("err", "warning")
   | project TimeGenerated, Computer, SyslogMessage
   | order by TimeGenerated desc
   | take 50
   ```

**Learning Outcomes**:
- Understand systemd service management
- Practice Node.js deployment workflows
- Configure application for MongoDB replica set
- Implement JWT authentication with Entra ID
- Deploy to multiple VMs for high availability

---

## Troubleshooting Guide

### Common Issues

#### Issue: npm install fails

**Symptoms**: Error during `npm ci` or `npm install`

**Diagnosis**:
```bash
# Check Node.js version
node --version  # Should be >= 20.0.0

# Check npm version
npm --version

# Check disk space
df -h /opt/blogapp
```

**Solutions**:
- Install correct Node.js version (20.x LTS)
- Clear npm cache: `npm cache clean --force`
- Delete node_modules and package-lock.json, reinstall

#### Issue: TypeScript compilation errors

**Symptoms**: `npm run build` fails with type errors

**Diagnosis**:
```bash
# Run type check
npm run type-check

# Check TypeScript version
npx tsc --version
```

**Solutions**:
- Fix type errors shown in output
- Ensure all dependencies installed
- Check tsconfig.json is correct

#### Issue: Service fails to start

**Symptoms**: `systemctl status blogapp-api` shows "failed"

**Diagnosis**:
```bash
# Check logs
sudo journalctl -u blogapp-api -n 50

# Try running manually
cd /opt/blogapp/backend
sudo -u blogapp node dist/server.js
```

**Solutions**:
- Check .env file exists and is readable
- Verify MongoDB connection string is correct
- Ensure port 3000 is not already in use: `sudo lsof -i :3000`

#### Issue: MongoDB connection fails

**Symptoms**: Health check returns 503, logs show "MongoNetworkError"

**Diagnosis**:
```bash
# Test MongoDB connection from app VM
mongosh "mongodb://10.0.3.4:27018,10.0.3.5:27018/?replicaSet=blogapp-rs0"

# Check NSG rules
az network nsg rule list --nsg-name nsg-app-prod --resource-group rg-blogapp-prod-eastus
```

**Solutions**:
- Verify MongoDB is running on DB VMs
- Check NSG allows port 27018 from app subnet
- Verify MongoDB credentials in .env
- Check replica set status: `rs.status()`

#### Issue: JWT validation fails

**Symptoms**: 401 Unauthorized on protected endpoints

**Diagnosis**:
```bash
# Test token manually (copy from browser)
curl -H "Authorization: Bearer {token}" http://localhost:3000/api/auth/me
```

**Solutions**:
- Verify ENTRA_TENANT_ID is correct
- Verify ENTRA_CLIENT_ID matches API app registration
- Check token audience claim matches API client ID
- Ensure JWKS URL is accessible: `curl https://login.microsoftonline.com/{tenant}/discovery/v2.0/keys`

---

## Performance Optimization

### Database Query Optimization

**Best Practices**:
- Use indexes for all query fields
- Use projection to limit returned fields
- Implement pagination (limit + skip)
- Use lean() for read-only queries (skip Mongoose hydration)
- Monitor slow queries with MongoDB profiler

**Example Optimized Query**:
```typescript
// Optimized post listing
const posts = await Post.find({ status: 'published' })
  .select('title slug excerpt authorName tags publishedAt viewCount') // Projection
  .sort({ publishedAt: -1 })
  .limit(pageSize)
  .skip((page - 1) * pageSize)
  .lean() // Return plain JavaScript objects
  .exec();
```

### Caching Strategy

**Candidates for Caching** (optional enhancement):
- Published posts list (5-minute TTL)
- Individual post content (10-minute TTL)
- User profiles (15-minute TTL)

**Implementation Options**:
- In-memory cache (node-cache, lru-cache)
- Redis (for multi-VM consistency)
- HTTP caching headers (browser caching)

**Example In-Memory Cache**:
```typescript
import NodeCache from 'node-cache';

const cache = new NodeCache({ stdTTL: 300 }); // 5 minutes

// Cache wrapper
async function getCachedPosts(page: number, pageSize: number) {
  const cacheKey = `posts:${page}:${pageSize}`;
  
  // Check cache
  const cached = cache.get(cacheKey);
  if (cached) {
    return cached;
  }
  
  // Fetch from database
  const result = await postService.getAllPosts({ page, pageSize });
  
  // Store in cache
  cache.set(cacheKey, result);
  
  return result;
}
```

### Connection Pooling

**Mongoose Connection Pool** (already configured):
```typescript
mongoose.connect(mongoUri, {
  maxPoolSize: 50, // Maximum connections
  minPoolSize: 10, // Minimum maintained connections
  maxIdleTimeMS: 60000, // Close idle connections after 1 minute
});
```

**Monitoring Connection Pool**:
```typescript
// Log connection pool stats
setInterval(() => {
  const poolStats = mongoose.connection.db?.serverConfig?.s?.coreTopology?.s?.pool;
  logger.debug('Connection pool stats', poolStats);
}, 60000);
```

---

## Educational Context: AWS Comparison

### Backend Deployment Comparison

| Aspect | Azure (This Workshop) | AWS Equivalent |
|--------|----------------------|----------------|
| **Compute** | Azure VMs (Ubuntu) with systemd | EC2 instances with systemd/PM2 |
| **Load Balancing** | Azure Standard Load Balancer → NGINX → Express | ALB → EC2/ECS → Express |
| **Database** | Self-managed MongoDB on VMs | Self-managed MongoDB on EC2 or Amazon DocumentDB |
| **Authentication** | Microsoft Entra ID + JWT validation | Amazon Cognito + JWT validation |
| **Secrets** | Azure Key Vault | AWS Secrets Manager |
| **Monitoring** | Azure Monitor + Log Analytics | CloudWatch Logs + CloudWatch Metrics |
| **CI/CD** | GitHub Actions → Azure VMs | GitHub Actions → EC2/CodeDeploy |
| **Service Management** | systemd | systemd or PM2 or ECS |

### Key Learning Differences

**Authentication**:
- Azure: Microsoft Entra ID (OAuth2.0, OIDC)
- AWS: Amazon Cognito (OAuth2.0, OIDC)
- **Similarity**: Both use JWT tokens, similar validation process
- **Difference**: Token issuer URL format, claim names

**Deployment**:
- Azure: Manual VM management, systemd services
- AWS: EC2 with similar manual management, or ECS/Fargate for containers
- **Workshop Choice**: IaaS approach teaches fundamentals (systemd, NGINX, process management)
- **Production Alternative**: Azure App Service (PaaS) vs AWS Elastic Beanstalk/App Runner

**Database**:
- Azure: MongoDB on VMs with manual replica set
- AWS: MongoDB on EC2 or managed DocumentDB
- **Similarity**: Both support MongoDB protocol
- **Difference**: DocumentDB is managed (less operational overhead)

---

## Operations & Deployment

### Process Management

#### systemd (Recommended for Production)

**Why systemd**:
- Native Linux service management (Ubuntu 24.04 LTS default)
- Automatic restart on failure
- System boot integration
- Centralized logging with journald
- Resource limits and security controls

**systemd Service Configuration**:

```ini
# /etc/systemd/system/blogapp-api.service
[Unit]
Description=Blog Application API Server
Documentation=https://github.com/your-org/blogapp
After=network.target mongod.service
Wants=mongod.service

[Service]
Type=simple
User=blogapp
Group=blogapp
WorkingDirectory=/opt/blogapp/backend

# Environment file (contains secrets)
EnvironmentFile=/opt/blogapp/backend/.env

# Start command
ExecStart=/usr/bin/node /opt/blogapp/backend/dist/server.js

# Restart policy
Restart=on-failure
RestartSec=10
StartLimitInterval=200
StartLimitBurst=5

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=blogapp-api

# Resource limits
LimitNOFILE=65536
MemoryLimit=512M
CPUQuota=150%

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/blogapp/backend/logs

[Install]
WantedBy=multi-user.target
```

**Service Management Commands**:

```bash
# Enable service (start on boot)
sudo systemctl enable blogapp-api

# Start service
sudo systemctl start blogapp-api

# Check status
sudo systemctl status blogapp-api

# View logs (last 100 lines)
sudo journalctl -u blogapp-api -n 100

# Follow logs in real-time
sudo journalctl -u blogapp-api -f

# Restart service (after code update)
sudo systemctl restart blogapp-api

# Stop service
sudo systemctl stop blogapp-api
```

**Deployment Workflow**:

```bash
#!/bin/bash
# scripts/deploy.sh - Simple deployment script

set -e  # Exit on error

echo "Starting deployment..."

# 1. Pull latest code
cd /opt/blogapp/backend
git pull origin main

# 2. Install dependencies
npm ci --production

# 3. Run TypeScript build
npm run build

# 4. Run database migrations (if any)
# npm run migrate

# 5. Restart service
sudo systemctl restart blogapp-api

# 6. Wait for service to be healthy
echo "Waiting for health check..."
sleep 5

# 7. Verify health
if curl -f http://localhost:3000/api/health; then
  echo "✅ Deployment successful!"
  exit 0
else
  echo "❌ Deployment failed - health check failed"
  exit 1
fi
```

**Comparison with PM2**:

| Feature | systemd | PM2 |
|---------|---------|-----|
| **Auto-restart** | ✅ Yes | ✅ Yes |
| **Clustering** | ❌ No (use load balancer) | ✅ Yes (built-in) |
| **Log management** | ✅ journald | ✅ Built-in rotation |
| **Boot integration** | ✅ Native | ⚠️ Requires systemd service |
| **Resource limits** | ✅ Native cgroups | ⚠️ Via systemd |
| **Ecosystem** | ✅ System-wide | ✅ Node.js-specific |
| **Learning value** | ✅ Linux fundamentals | ⚠️ Tool-specific |

**Workshop Recommendation**: Use systemd for educational value (teaches Linux service management).

---

### Azure Monitor Integration

**Application Insights SDK Setup**:

```typescript
// src/config/monitoring.ts
import * as appInsights from 'applicationinsights';
import { logger } from '../utils/logger.util';

/**
 * Initialize Application Insights
 * 
 * Sends telemetry to Azure Monitor for:
 * - Request/response tracking
 * - Exception logging
 * - Custom metrics
 * - Dependency tracking (MongoDB, HTTP calls)
 */
export const initializeMonitoring = (): void => {
  const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;

  if (!connectionString) {
    logger.warn('Application Insights not configured (APPLICATIONINSIGHTS_CONNECTION_STRING missing)');
    return;
  }

  appInsights
    .setup(connectionString)
    .setAutoDependencyCorrelation(true)  // Track MongoDB calls
    .setAutoCollectRequests(true)         // Track HTTP requests
    .setAutoCollectPerformance(true)      // Track performance counters
    .setAutoCollectExceptions(true)       // Track exceptions
    .setAutoCollectDependencies(true)     // Track external dependencies
    .setAutoCollectConsole(false)         // Don't duplicate console logs
    .setUseDiskRetryCaching(true)        // Retry on network failures
    .setSendLiveMetrics(true)            // Enable live metrics stream
    .start();

  logger.info('Application Insights initialized', {
    instrumentationKey: appInsights.defaultClient.config.instrumentationKey?.substring(0, 8) + '...'
  });
};

// Get telemetry client for custom tracking
export const getTelemetryClient = () => appInsights.defaultClient;
```

```typescript
// src/server.ts
import { initializeMonitoring } from './config/monitoring';

// Initialize monitoring BEFORE other imports
initializeMonitoring();

import app from './app';
import { connectDatabase } from './config/database';
import { logger } from './utils/logger.util';

const PORT = process.env.PORT || 3000;

// ... rest of server setup
```

**Custom Metrics Example**:

```typescript
// src/controllers/posts.controller.ts
import { getTelemetryClient } from '../config/monitoring';

export const createPost = asyncHandler(async (req: Request, res: Response) => {
  const startTime = Date.now();
  
  try {
    const post = await postService.create(req.body, req.user!.userId);
    
    // Track custom metric
    getTelemetryClient()?.trackMetric({
      name: 'PostCreated',
      value: 1,
      properties: {
        authorId: req.user!.userId,
        status: post.status,
        wordCount: post.metadata.wordCount
      }
    });
    
    res.status(201).json({ data: post });
  } catch (error) {
    // Track custom event for failures
    getTelemetryClient()?.trackEvent({
      name: 'PostCreationFailed',
      properties: {
        error: error.message,
        authorId: req.user!.userId
      }
    });
    throw error;
  }
});
```

**Correlation IDs for Distributed Tracing**:

```typescript
// src/middleware/correlation.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';

/**
 * Correlation ID Middleware
 * 
 * Adds X-Correlation-ID header to track requests across services.
 * Uses existing correlation ID from client or generates new one.
 */
export const correlationMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  // Use existing correlation ID or generate new one
  const correlationId = (req.headers['x-correlation-id'] as string) || uuidv4();
  
  // Attach to request for logging
  req.correlationId = correlationId;
  
  // Add to response headers
  res.setHeader('X-Correlation-ID', correlationId);
  
  next();
};

// Add to Express augmentation
declare global {
  namespace Express {
    interface Request {
      correlationId?: string;
    }
  }
}
```

```typescript
// src/utils/logger.util.ts
// Update logger to include correlation ID
export const requestLogger = (req: Request, res: Response, next: NextFunction): void => {
  const startTime = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    logger.info('HTTP Request', {
      correlationId: req.correlationId,  // ← Include correlation ID
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('user-agent'),
      ip: req.ip,
      userId: req.user?.userId
    });
  });

  next();
};
```

**Monitoring Dashboard Queries** (Azure Monitor Logs):

```kusto
// Average response time by endpoint
requests
| where timestamp > ago(1h)
| summarize 
    avgDuration = avg(duration),
    p95Duration = percentile(duration, 95),
    count = count()
  by name
| order by avgDuration desc

// Error rate by endpoint
requests
| where timestamp > ago(24h)
| summarize 
    total = count(),
    errors = countif(success == false),
    errorRate = 100.0 * countif(success == false) / count()
  by name
| where errorRate > 0
| order by errorRate desc

// Custom metric: Posts created per hour
customMetrics
| where name == "PostCreated"
| where timestamp > ago(24h)
| summarize count() by bin(timestamp, 1h)
| render timechart

// Trace requests by correlation ID
union requests, dependencies, traces, exceptions
| where timestamp > ago(1h)
| where customDimensions.correlationId == "your-correlation-id-here"
| project timestamp, itemType, operation_Name, message, resultCode
| order by timestamp asc
```

**Alert Rules** (configure in Azure Portal):

1. **High Error Rate Alert**:
   - Metric: `requests/count` where `success == false`
   - Threshold: > 5% error rate over 5 minutes
   - Action: Send email to on-call engineer

2. **High Response Time Alert**:
   - Metric: `requests/duration` (95th percentile)
   - Threshold: > 1000ms over 10 minutes
   - Action: Send notification to Slack/Teams

3. **Service Availability Alert**:
   - Metric: Health probe failures
   - Threshold: 3 consecutive failures
   - Action: Critical alert + auto-restart attempt

**Workshop Exercise**: Create custom dashboard in Azure Portal with:
- Request rate timeline
- Error rate percentage
- Response time histogram (p50, p95, p99)
- Custom metrics (posts created, user registrations)

---

### Deployment Strategy

**Simple Deployment Approach** (Workshop):

```bash
#!/bin/bash
# scripts/deploy-simple.sh

set -e

API_SERVER="10.0.2.4"  # App VM in AZ1
SSH_USER="azureuser"

echo "Deploying to $API_SERVER..."

# 1. Copy code to server
rsync -avz --exclude node_modules --exclude dist \
  ./ $SSH_USER@$API_SERVER:/opt/blogapp/backend/

# 2. Build and restart on server
ssh $SSH_USER@$API_SERVER << 'EOF'
  cd /opt/blogapp/backend
  npm ci --production
  npm run build
  sudo systemctl restart blogapp-api
EOF

# 3. Health check
echo "Waiting for service to be ready..."
sleep 5

if curl -f http://$API_SERVER:3000/api/health; then
  echo "✅ Deployment successful!"
else
  echo "❌ Deployment failed!"
  exit 1
fi
```

**Multi-VM Deployment** (2 API servers):

```bash
#!/bin/bash
# scripts/deploy-multi-vm.sh - Deploy to both VMs

set -e

API_SERVERS=("10.0.2.4" "10.0.2.5")
SSH_USER="azureuser"

for SERVER in "${API_SERVERS[@]}"; do
  echo "Deploying to $SERVER..."
  
  # Copy and build
  rsync -avz --exclude node_modules --exclude dist ./ $SSH_USER@$SERVER:/opt/blogapp/backend/
  
  ssh $SSH_USER@$SERVER << 'EOF'
    cd /opt/blogapp/backend
    npm ci --production
    npm run build
    sudo systemctl restart blogapp-api
EOF

  # Health check
  sleep 5
  if curl -f http://$SERVER:3000/api/health; then
    echo "✅ $SERVER deployed successfully"
  else
    echo "❌ $SERVER deployment failed"
    exit 1
  fi
done

echo "✅ All servers deployed successfully!"
```

**Rollback Procedure**:

```bash
#!/bin/bash
# scripts/rollback.sh

set -e

API_SERVER="10.0.2.4"
SSH_USER="azureuser"

echo "Rolling back to previous version..."

ssh $SSH_USER@$API_SERVER << 'EOF'
  cd /opt/blogapp/backend
  
  # Git rollback to previous commit
  git reset --hard HEAD~1
  
  # Rebuild
  npm ci --production
  npm run build
  
  # Restart
  sudo systemctl restart blogapp-api
EOF

echo "✅ Rollback complete"
```

**Future Enhancement**: Blue-Green Deployment

For production environments, consider blue-green deployment pattern:

- **Blue environment**: Current production (e.g., VM 10.0.2.4)
- **Green environment**: New version (e.g., VM 10.0.2.5)
- **Process**:
  1. Deploy new version to green environment
  2. Test green environment (health checks, smoke tests)
  3. Switch load balancer to green environment
  4. Monitor for issues
  5. Keep blue environment for quick rollback if needed

**Note**: Blue-green requires additional infrastructure (duplicate VMs) and load balancer reconfiguration. Out of scope for 2-day workshop but recommended for production.

**Reference**: [Azure DevOps deployment strategies](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/deployment-patterns/)

---

### Capacity Planning

**VM Resource Requirements**:

| Component | Specification | Rationale |
|-----------|--------------|-----------|
| **CPU** | 2 vCPU (Standard_B2ms) | Node.js single-threaded, 50% baseline + burst to 200% |
| **Memory** | 8 GB RAM | ~512 MB per Node process + OS overhead + headroom |
| **Storage** | 30 GB Premium SSD | Fast npm install, TypeScript compilation, logs |
| **Network** | 1 Gbps | Sufficient for API responses (JSON payloads) |

**Performance Baselines** (workshop scale):

```
Expected Load (20-30 students):
- Concurrent users: 20-30
- Peak RPS: 5-10 requests/second
- Average response time: < 100ms
- P95 response time: < 500ms
- Memory usage: 300-500 MB per process
- CPU usage: 10-20% average, 50% peak
```

**Horizontal Scaling Triggers**:

When to add more API VMs:
- ✅ CPU sustained > 70% for 10+ minutes
- ✅ Memory usage > 80% consistently
- ✅ Response time P95 > 1000ms
- ✅ Request queue depth > 100

**Workshop Scale**: 2 VMs sufficient (1 per AZ for HA)

**Production Scale Estimate**:

```
10,000 daily active users:
- Peak RPS: ~100 requests/second
- Recommended: 4-6 VMs (Standard_B2ms)
- Or migrate to Azure Container Apps (auto-scaling)
```

**Cost Estimate** (East US, pay-as-you-go):

```
Workshop Configuration (2 VMs):
- 2x Standard_B2ms: $60/month each = $120/month
- 2x Premium SSD 30GB: $5/month each = $10/month
- Load Balancer: $18/month
- Bandwidth: ~$5/month
Total: ~$155/month

Scale-up Configuration (6 VMs):
- 6x Standard_B2ms: $360/month
- Other resources: $30/month
Total: ~$390/month
```

**Monitoring Resource Usage**:

```bash
# CPU usage
top -b -n 1 | grep node

# Memory usage
ps aux | grep node

# Disk usage
df -h /opt/blogapp

# Network connections
netstat -an | grep :3000 | wc -l

# systemd resource usage
systemctl status blogapp-api
```

---

## API Tier High Availability & Disaster Recovery

### Stateless Architecture Principles

**Design Principle**: API servers are **completely stateless** and **disposable**.

**What "Stateless" Means**:

| State Type | Storage Location | Recovery Behavior |
|------------|-----------------|-------------------|
| **Authentication** | JWT tokens (client-side) | No server-side sessions |
| **User data** | MongoDB (database tier) | Persisted across API restarts |
| **Posts/Comments** | MongoDB (database tier) | Persisted across API restarts |
| **Application code** | Git repository | Re-deploy from source |
| **Dependencies** | npm (package.json) | Reinstall on demand |
| **Configuration** | Environment variables / Key Vault | Retrieved on startup |

**Benefits of Stateless Design**:
- ✅ **Any API server can handle any request** (no sticky sessions)
- ✅ **Easy horizontal scaling** (add/remove VMs without coordination)
- ✅ **Fast recovery** (spin up new VM, deploy code, start serving)
- ✅ **Simplified load balancing** (round-robin, no session affinity)
- ✅ **Zero data loss risk** (no state stored on VMs)

**Common Mistake - Session State on VMs**:

```typescript
// ❌ ANTI-PATTERN: Storing sessions in Express memory
import session from 'express-session';

app.use(session({
  secret: 'secret-key',
  resave: false,
  saveUninitialized: false
  // Problem: Session lost when VM restarts
  // Problem: Load balancer needs sticky sessions (complex)
  // Problem: Horizontal scaling breaks sessions (session on VM1, user routed to VM2)
}));
```

**Workshop Pattern - JWT Tokens (Stateless)**:

```typescript
// ✅ CORRECT: JWT tokens contain all user info
export const authenticateJWT = (req: Request, res: Response, next: NextFunction): void => {
  const token = req.headers.authorization?.substring(7);
  
  jwt.verify(token, getKey, (err, decoded) => {
    if (!err && decoded) {
      // User info from token (no server-side session)
      req.user = {
        userId: decoded.oid,
        email: decoded.email,
        displayName: decoded.name
      };
    }
    next();
  });
};

// Benefits:
// ✅ Token contains all user info (oid, email, name)
// ✅ Any VM can validate any token (no server state)
// ✅ No session affinity required in load balancer
```

**AWS Comparison**:

| Pattern | Azure Workshop | AWS Equivalent |
|---------|---------------|----------------|
| **Authentication** | Entra ID JWT tokens | Cognito JWT tokens |
| **State storage** | MongoDB on VMs | DynamoDB or RDS |
| **Session management** | Stateless (JWT) | Stateless (JWT) or ElastiCache (stateful) |
| **Load balancing** | Azure Load Balancer (Layer 4) | Application Load Balancer (Layer 7) |

Unlike AWS Lambda (inherently stateless), VMs **could** store state but **shouldn't** for HA/DR.

---

### VM Failure Scenarios & Recovery

**Scenario Matrix**:

| Failure Scenario | Impact | Automatic Recovery | Manual Steps Required |
|------------------|--------|-------------------|----------------------|
| **Single VM fails** (e.g., VM1 crashes) | Reduced capacity (50% if 2 VMs) | Load balancer detects unhealthy probe → Routes to VM2 | Replace failed VM, deploy code |
| **All VMs in AZ1 fail** (zone outage) | Reduced capacity | Load balancer routes to AZ2 VMs | Azure auto-replaces VMs (if configured) |
| **All API VMs fail** (code bug, config error) | **Service unavailable** | ❌ No automatic recovery | Deploy fix or rollback code |
| **Load balancer fails** | Service unavailable | Azure auto-replaces LB (managed service) | None (wait ~5 minutes) |
| **MongoDB fails** | Degraded (health check fails) | Replica set failover (DB tier) | Verify DB health, restart API VMs if needed |

**Health Probe Behavior**:

```
Azure Load Balancer Health Probe:
- Endpoint: http://<vm-ip>:3000/api/health
- Interval: 30 seconds
- Timeout: 5 seconds
- Unhealthy threshold: 2 consecutive failures

When VM marked unhealthy:
1. Load balancer stops sending new requests to VM
2. Existing connections drained (graceful shutdown)
3. All traffic routed to healthy VMs
4. VM automatically restarted (if systemd configured)
5. When health probe succeeds again, VM added back to pool
```

**Recovery Time Objectives (RTO/RPO)**:

| Metric | Target | Explanation |
|--------|--------|-------------|
| **RTO** (Recovery Time Objective) | < 5 minutes | Time to restore service (automatic failover to healthy VM) |
| **RTO** (Manual recovery) | < 30 minutes | Time to deploy new VM + code if all VMs lost |
| **RPO** (Recovery Point Objective) | 0 seconds | No data stored on API tier (all data in MongoDB) |

**Comparison with Database Tier**:

| Tier | State | RTO | RPO | Recovery Method |
|------|-------|-----|-----|-----------------|
| **API Tier** | Stateless | 5 min (auto) | 0 sec | Load balancer failover |
| **Database Tier** | Stateful | 10 sec - 5 min | 0 sec (replica) | Replica set failover |

---

### Backup & Recovery Requirements

**What to Backup**:

| Component | Backup Method | Frequency | Restore Time |
|-----------|---------------|-----------|--------------|
| **Source code** | Git repository | Every commit | 1 minute (git clone) |
| **Dependencies** | package.json | N/A (defined in code) | 5 minutes (npm install) |
| **Configuration** | Environment variables in Key Vault | On change | 1 minute (retrieve from vault) |
| **Secrets** | Azure Key Vault (auto-backed up) | Continuous | 1 minute |
| **VM disks** | ❌ Not needed (stateless) | N/A | N/A |

**Disaster Recovery Procedure** (Total API Tier Loss):

```bash
# Scenario: All API VMs destroyed (e.g., catastrophic Azure region failure)

# Step 1: Provision new VMs (via Bicep)
az deployment group create \
  --resource-group rg-blogapp-prod \
  --template-file bicep/main.bicep

# Step 2: Deploy application code
git clone https://github.com/your-org/blogapp.git
cd blogapp/backend
npm ci --production
npm run build

# Step 3: Retrieve secrets from Key Vault
az keyvault secret show --vault-name kv-blogapp --name MONGODB-URI
# Configure environment variables

# Step 4: Start service
sudo systemctl start blogapp-api

# Step 5: Verify health
curl http://localhost:3000/api/health

# RTO: ~20-30 minutes (mostly Azure VM provisioning time)
```

**No Data Loss**: Because API tier is stateless, all user data (posts, comments, profiles) remains safe in MongoDB replica set.

---

### Load Balancer Integration

**Health Probe Configuration** (reference for infrastructure team):

```bicep
// Bicep configuration for Azure Load Balancer health probe
resource healthProbe 'Microsoft.Network/loadBalancers/probes@2023-05-01' = {
  name: 'api-health-probe'
  properties: {
    protocol: 'Http'
    port: 3000
    requestPath: '/api/health'
    intervalInSeconds: 30
    numberOfProbes: 2  // Unhealthy after 2 consecutive failures
  }
}
```

**Backend Response Requirements**:

```typescript
// Health check must return:
// - Status 200 if healthy
// - Status 503 if unhealthy
// - Response within 5 seconds (probe timeout)

GET /api/health
→ 200 OK: { "status": "healthy", "database": "connected", "uptime": 86400 }
→ 503 Service Unavailable: { "status": "unhealthy", "database": "disconnected" }
```

**Educational Note**: 
Unlike AWS ALB (supports Layer 7 path-based routing), Azure Standard Load Balancer operates at Layer 4 (transport). Health probe uses HTTP/TCP, but routing is based on IP/port, not HTTP path.

---

## Authentication Troubleshooting Guide

### Common JWT Validation Errors

This section helps students debug the most common authentication issues when integrating with Microsoft Entra ID.

---

#### Error: "No token provided"

**Cause**: Frontend not sending `Authorization` header with request.

**Debugging Steps**:

1. **Check browser DevTools**:
   - Open Network tab
   - Find failing request
   - Check Request Headers
   - Verify `Authorization: Bearer <token>` header exists

2. **Test with curl**:
```bash
# Missing token (will fail with 401)
curl http://localhost:3000/api/auth/me

# With token (should succeed)
curl -H "Authorization: Bearer <your-jwt-token>" \
  http://localhost:3000/api/auth/me
```

3. **Frontend code check**:
```typescript
// ✅ CORRECT: Include Authorization header
const response = await fetch('/api/auth/me', {
  headers: {
    'Authorization': `Bearer ${accessToken}`
  }
});

// ❌ WRONG: Missing header
const response = await fetch('/api/auth/me');  // No auth header!
```

**Solution**: Ensure MSAL integration in frontend passes token correctly.

---

#### Error: "Invalid token"

**Causes** (multiple):

1. **Wrong audience** (most common)
2. **Expired token**
3. **Signing key mismatch**
4. **Malformed token**

**Debugging Workflow**:

**Step 1**: Decode token at [https://jwt.io](https://jwt.io)

Paste your JWT token into jwt.io and check claims:

```json
{
  "aud": "api://12345678-1234-1234-1234-123456789abc",  // ← Check this!
  "iss": "https://login.microsoftonline.com/{tenantId}/v2.0",
  "exp": 1701435600,  // ← Unix timestamp (check if expired)
  "oid": "a1b2c3d4-...",
  "email": "user@example.com"
}
```

**Step 2**: Verify `aud` (audience) claim

```typescript
// Backend expects:
audience: `api://${process.env.ENTRA_CLIENT_ID}`

// Token must have matching `aud` claim
// Example: "aud": "api://12345678-1234-1234-1234-123456789abc"
```

**Common Mistake**: Token has wrong audience (e.g., frontend client ID instead of API client ID)

**Solution**: 
1. Verify `ENTRA_CLIENT_ID` in backend `.env` matches API app registration
2. Frontend MSAL config must request token with correct scope:
```typescript
// Frontend MSAL configuration
const tokenRequest = {
  scopes: [`api://${apiClientId}/user_impersonation`]  // ← Correct scope
};
```

**Step 3**: Check token expiration

```bash
# Decode `exp` claim (Unix timestamp)
# Example: exp = 1701435600

# Convert to human-readable date
date -r 1701435600
# Output: Sat Dec  2 10:00:00 PST 2023

# If current time > exp, token is expired
```

**Solution**: Frontend must refresh token when expired (MSAL handles automatically).

**Step 4**: Verify issuer

```typescript
// Backend expects:
issuer: `https://login.microsoftonline.com/${process.env.ENTRA_TENANT_ID}/v2.0`

// Token must have matching `iss` claim
```

**Common Mistake**: Tenant ID mismatch (dev vs prod tenant)

---

#### Error: "Unable to find a signing key"

**Cause**: Backend cannot fetch JWKS (JSON Web Key Set) from Microsoft Entra ID.

**JWKS Endpoint**:
```
https://login.microsoftonline.com/{tenantId}/discovery/v2.0/keys
```

**Debugging**:

```bash
# Test JWKS endpoint manually
TENANT_ID="your-tenant-id"
curl https://login.microsoftonline.com/$TENANT_ID/discovery/v2.0/keys

# Should return JSON with keys:
{
  "keys": [
    {
      "kid": "...",
      "kty": "RSA",
      "use": "sig",
      "n": "...",
      "e": "AQAB"
    }
  ]
}
```

**Common Causes**:

1. **No internet connectivity from VM**
   - Solution: Check NSG rules allow outbound HTTPS
   - Test: `curl https://login.microsoftonline.com`

2. **Wrong tenant ID in JWKS URL**
   - Solution: Verify `ENTRA_TENANT_ID` in `.env`

3. **JWKS cache stale** (rare)
   - Solution: Restart API server (clears cache)

**Library Behavior** (jwks-rsa):
- Caches keys for 24 hours
- Retries on transient failures
- Falls back to cache if endpoint unreachable

---

### Authentication Flow Debugging Checklist

**Visual Flow**:

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Frontend  │  Token  │  Backend API     │  Verify │ Microsoft Entra │
│    (MSAL)   │────────>│  (Express)       │────────>│  ID (JWKS)      │
└─────────────┘         └──────────────────┘         └─────────────────┘
     │                           │                            │
     │ 1. User logs in           │                            │
     │ 2. MSAL gets token        │                            │
     │ 3. Send Authorization     │                            │
     │    header                 │                            │
     │                           │ 4. Extract token           │
     │                           │ 5. Fetch signing key       │───> (cached)
     │                           │ 6. Verify signature        │
     │                           │ 7. Check expiration        │
     │                           │ 8. Validate audience       │
     │                           │ 9. Extract claims (oid)    │
     │                           │ 10. Set req.user           │
     │                           │                            │
     │<───── 200 OK ─────────────│                            │
```

**Debugging Checklist**:

- [ ] Frontend: User successfully logged in with MSAL?
- [ ] Frontend: Access token acquired with correct scope (`api://.../user_impersonation`)?
- [ ] Network: Authorization header sent with request?
- [ ] Network: Header format correct (`Authorization: Bearer <token>`)?
- [ ] Backend: Token extracted from header (substring(7))?
- [ ] Backend: JWKS endpoint reachable from VM?
- [ ] Backend: Tenant ID correct in JWKS URL?
- [ ] Token: `aud` claim matches backend's `ENTRA_CLIENT_ID`?
- [ ] Token: `iss` claim matches backend's expected issuer?
- [ ] Token: `exp` claim not expired (current time < exp)?
- [ ] Token: Contains required claims (`oid`, `email`, `name`)?

**Enable Debug Logging** (development only):

```typescript
// src/middleware/auth.middleware.ts
if (process.env.NODE_ENV === 'development') {
  logger.debug('JWT validation attempt', {
    hasToken: !!token,
    tokenPreview: token?.substring(0, 20) + '...',
    expectedAudience: authConfig.audience,
    expectedIssuer: authConfig.issuer
  });
}
```

---

### Learning Resources

**For Students New to OAuth 2.0**:
- [OAuth 2.0 Simplified](https://aaronparecki.com/oauth-2-simplified/) - Beginner-friendly explanation
- [JWT.io Introduction](https://jwt.io/introduction) - Understanding JSON Web Tokens
- [Microsoft Identity Platform Overview](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-overview) - Official Azure docs

**Workshop Exercise**: 
1. Decode a sample JWT at jwt.io
2. Inspect claims (`aud`, `iss`, `exp`, `oid`)
3. Understand how backend validates each claim
4. Simulate expired token error (manually change `exp` claim)

**AWS Comparison**:
- **Azure Entra ID** ≈ **AWS Cognito** (identity provider)
- **JWT validation with jwks-rsa** ≈ **API Gateway Cognito Authorizer** (but manual in Express)
- **MSAL library** ≈ **Amplify Auth** (frontend SDK)

Key difference: AWS API Gateway can validate JWT automatically (managed authorizer), while Express requires manual implementation. This teaches underlying OAuth 2.0 mechanics.

---

## Technology Evolution & Deployment Patterns

### Why VMs for This Workshop?

**Educational Rationale**:

1. **Foundational Understanding**
   - Learn OS-level concerns (systemd, networking, security)
   - Understand infrastructure as code (Bicep for VM provisioning)
   - Debug at system level (logs, processes, resource limits)

2. **Cost Predictability**
   - Fixed monthly cost (~$60/VM) regardless of traffic
   - No surprise bills from serverless cold starts or container scaling
   - Easier budgeting for workshop with 20-30 students

3. **Debugging Skills**
   - Full control over environment and logs (SSH access)
   - Can inspect process state, network connections, file system
   - Learn production troubleshooting (systemctl, journalctl, top)

4. **IaaS Focus**
   - Workshop specifically teaches **Infrastructure as a Service** patterns
   - High availability with Availability Zones (VM placement)
   - Disaster recovery with Azure Site Recovery (VM replication)

**Quote from Azure Well-Architected Framework**:
> "Choose IaaS when you need full control over the operating system and application stack, or when migrating existing on-premises applications."

---

### Architectural Trade-offs: VMs vs Containers vs Serverless

| Pattern | Best For | Pros | Cons | Azure Service |
|---------|----------|------|------|---------------|
| **VMs (IaaS)** | Long-running apps, full control, predictable costs | Complete control, easy lift-and-shift, fixed costs | Manual scaling, OS patching, configuration drift | Azure VMs |
| **Containers** | Microservices, auto-scaling, portability | Fast deployment, efficient resources, orchestration | Orchestration complexity, learning curve | Azure Container Apps, AKS |
| **Serverless (FaaS)** | Event-driven, sporadic workload, rapid development | No server management, auto-scale to zero, pay-per-execution | Cold start latency, stateless required, vendor lock-in | Azure Functions |

**When to Use Each**:

```
Use VMs when:
- ✅ Long-running processes (web servers, APIs)
- ✅ Need full OS control (custom kernel modules, system packages)
- ✅ Predictable workload (cost-effective vs serverless)
- ✅ Lift-and-shift from on-premises
- ✅ Learning infrastructure fundamentals

Use Containers when:
- ✅ Microservices architecture (many small services)
- ✅ Need horizontal auto-scaling (traffic spikes)
- ✅ Multi-cloud or hybrid deployments (portability)
- ✅ CI/CD with consistent dev/prod environments

Use Serverless when:
- ✅ Event-driven tasks (file uploads, queue processing)
- ✅ Sporadic or unpredictable traffic (scale to zero)
- ✅ Rapid prototyping (no infrastructure management)
- ✅ Pay only for actual compute time
```

---

### Migration Path from VMs

**Evolution Strategy** (how to modernize over time):

```
Phase 0: Current Workshop State
┌─────────────────────────────────────┐
│  VMs (Ubuntu 24.04 LTS)             │
│  ├─ Node.js + Express (manual)      │
│  ├─ systemd service                 │
│  └─ Azure Load Balancer             │
└─────────────────────────────────────┘

↓ Containerization (no architecture change)

Phase 1: Containerize App (Lift-and-shift)
┌─────────────────────────────────────┐
│  Same VMs                            │
│  ├─ Docker container                │
│  ├─ Dockerfile + docker-compose     │
│  └─ Still manual deployment         │
└─────────────────────────────────────┘
Benefits: Consistent environments, easier rollback

↓ Managed Container Platform

Phase 2: Azure Container Apps
┌─────────────────────────────────────┐
│  Azure Container Apps (managed)     │
│  ├─ Same container image            │
│  ├─ Auto-scaling (CPU/memory/HTTP)  │
│  ├─ Zero-downtime deployments       │
│  └─ Built-in load balancer          │
└─────────────────────────────────────┘
Benefits: No VM management, auto-scale, lower ops burden

↓ Microservices Decomposition

Phase 3: Serverless Microservices
┌─────────────────────────────────────┐
│  Hybrid Architecture                │
│  ├─ Azure Functions (image uploads) │
│  ├─ Container Apps (API)            │
│  ├─ Azure Service Bus (messaging)   │
│  └─ Azure API Management (gateway)  │
└─────────────────────────────────────┘
Benefits: Optimal scaling, polyglot microservices
```

**Cost Comparison** (Workshop scale: 2 instances, 20 students):

| Pattern | Monthly Cost | Auto-scale? | Management Effort |
|---------|--------------|-------------|-------------------|
| **VMs** (Standard_B2ms) | ~$120 (2 VMs always on) | ❌ Manual | High (OS patching, systemd) |
| **Container Apps** (consumption) | ~$60 (scale to zero) | ✅ Yes | Low (managed platform) |
| **Azure Functions** (consumption) | ~$10 (pay per execution) | ✅ Yes | Very low (fully serverless) |

**Workshop Scale**: VMs are cost-competitive at small scale.  
**Production Scale** (10,000+ users): Container Apps or Functions become more cost-effective.

---

### Real-World Production Recommendations

**After Workshop, Consider**:

1. **Keep VMs if**:
   - Team already experienced with Linux system administration
   - Predictable traffic (cost-effective)
   - Compliance requires OS-level control

2. **Migrate to Container Apps if**:
   - Traffic varies significantly (save costs with scale-to-zero)
   - Want managed platform (no OS patching)
   - Planning microservices eventually

3. **Adopt Serverless Functions if**:
   - Event-driven workload (file processing, queue workers)
   - Unpredictable or sporadic traffic
   - Want to focus purely on code (no infrastructure)

**Hybrid Approach** (Best of both worlds):
```
- Core API: Container Apps (consistent load, stateful-friendly)
- Image processing: Azure Functions (event-driven, scales to zero)
- Background jobs: Azure Functions (queue-triggered)
- Static frontend: Azure Static Web Apps
```

**Workshop Takeaway**: 
- Start with VMs to understand fundamentals
- Understand trade-offs before jumping to "latest tech"
- Migrate when **business needs justify complexity**, not for resume-driven development

**AWS Comparison**:
| Azure | AWS Equivalent |
|-------|----------------|
| Azure VMs | EC2 |
| Azure Container Apps | AWS App Runner or Fargate |
| Azure Functions | AWS Lambda |
| Azure Kubernetes Service (AKS) | Amazon EKS |

---

## MongoDB Connection Resilience

### Built-in Mongoose Retry Behavior

**Mongoose v8 Automatic Retry Features**:

```typescript
// src/config/database.ts
import mongoose from 'mongoose';

mongoose.connect(mongoUri, {
  // Automatic reconnection on connection loss
  // (Mongoose 6+ automatically retries, no config needed)
  
  // Server selection timeout (how long to wait for replica set)
  serverSelectionTimeoutMS: 5000,  // 5 seconds
  
  // Socket timeout (prevent hung connections)
  socketTimeoutMS: 45000,  // 45 seconds
  
  // Connection timeout
  connectTimeoutMS: 10000,  // 10 seconds
  
  // Connection pool (reuse connections)
  maxPoolSize: 10,  // Max 10 concurrent connections
  minPoolSize: 2,   // Keep 2 connections always open
  
  // Write concern (durability)
  w: 'majority',  // Wait for majority of replica set
  wtimeoutMS: 5000  // Timeout if write takes > 5 seconds
});
```

**What Mongoose Automatically Handles**:

1. **Reconnection on Connection Loss**
   - Automatically reconnects if connection drops
   - Queues operations during reconnection
   - No application code changes needed

2. **Replica Set Failover**
   - Detects primary node failure
   - Automatically connects to new primary
   - Retries failed operations

3. **Transient Error Retry**
   - Network blips: Retries automatically
   - Replica set elections: Waits and retries
   - Write conflicts: Returns error (application handles)

**Workshop Configuration** (recommended):

```typescript
// Production-ready connection with proper error handling
export const connectDatabase = async (): Promise<void> => {
  const mongoUri = process.env.MONGODB_URI!;

  try {
    await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      maxPoolSize: 10,
      minPoolSize: 2
    });

    logger.info('MongoDB connected successfully', {
      host: mongoose.connection.host,
      name: mongoose.connection.name,
      readyState: mongoose.connection.readyState
    });

    // Handle connection events
    mongoose.connection.on('connected', () => {
      logger.info('Mongoose connected to MongoDB');
    });

    mongoose.connection.on('error', (err) => {
      logger.error('Mongoose connection error', { error: err });
    });

    mongoose.connection.on('disconnected', () => {
      logger.warn('Mongoose disconnected from MongoDB');
    });

    // Graceful shutdown
    process.on('SIGINT', async () => {
      await mongoose.connection.close();
      logger.info('Mongoose connection closed through app termination');
      process.exit(0);
    });

  } catch (error) {
    logger.error('MongoDB connection failed', { error });
    throw error;
  }
};
```

**Educational Note**:

Unlike manual retry logic (recommended by some sources), Mongoose **already handles retries** for transient failures. Adding manual retry wrappers would be **redundant** and **increase complexity** without benefit.

**AWS Comparison**:
- **Mongoose on MongoDB** ≈ **AWS SDK for DynamoDB** (built-in retry logic)
- **Connection pooling** ≈ **DynamoDB connection reuse** (automatically managed)

---

### JWKS Caching Behavior

**jwks-rsa Library Automatic Caching**:

```typescript
// src/config/auth.ts
import jwksRsa from 'jwks-rsa';

export const jwksClient = jwksRsa({
  jwksUri: `https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`,
  
  // Automatic caching
  cache: true,             // Enable caching
  cacheMaxAge: 86400000,   // Cache for 24 hours (86400 seconds * 1000)
  
  // Rate limiting (prevent DoS)
  rateLimit: true,
  jwksRequestsPerMinute: 10,  // Max 10 requests/minute
  
  // Timeout
  timeout: 30000  // 30 second timeout for JWKS fetch
});
```

**What jwks-rsa Automatically Handles**:

1. **Key Caching**
   - Caches signing keys for 24 hours
   - Reduces network calls to Microsoft Entra ID
   - Improves performance (no JWKS fetch on every request)

2. **Automatic Refresh**
   - Refetches keys when cache expires
   - Handles key rotation transparently
   - No application code changes needed

3. **Failure Fallback**
   - If JWKS endpoint unreachable, uses cached keys
   - Retries on transient network failures
   - Returns error only if cache expired AND fetch fails

4. **Rate Limiting**
   - Prevents DoS attacks (malicious rapid token validation)
   - Protects both application and Microsoft's JWKS endpoint

**Workshop Configuration** (already optimal):

The design specification already includes proper jwks-rsa configuration. **No additional caching logic needed**.

**Troubleshooting JWKS Issues**:

```bash
# Test JWKS endpoint manually
curl https://login.microsoftonline.com/<tenant-id>/discovery/v2.0/keys

# Check if VM can reach endpoint
curl -I https://login.microsoftonline.com

# If cache stale, restart API server (clears cache)
sudo systemctl restart blogapp-api
```

**Educational Note**:

Adding manual cache fallback (as suggested by some sources) would be **redundant** because jwks-rsa **already implements cache fallback**. The library is production-tested and battle-hardened.

---

## Advanced Topics (Optional Reading)

The following topics are **out of scope** for the 2-day workshop but provided as references for self-directed learning and production deployments.

---

### Database Transactions (Advanced)

**When Transactions Are Needed**:

MongoDB replica sets support multi-document ACID transactions. Use when:
- Multiple collections updated together (atomicity required)
- Cross-collection consistency critical (all-or-nothing)
- Race conditions possible (concurrent updates)

**Workshop Note**: Current schema uses **embedded documents** (comments inside posts), which are **already atomic** (single document updates). Transactions **not needed** for workshop scope.

**Transaction Pattern Example** (for reference):

```typescript
// src/services/post.service.ts
import mongoose from 'mongoose';

/**
 * Create post with transaction (if updating multiple collections)
 * 
 * Example: Create post + increment user's post count
 */
export const createPostWithTransaction = async (
  postData: CreatePostDTO,
  userId: string
): Promise<IPost> => {
  const session = await mongoose.startSession();
  session.startTransaction();
  
  try {
    // Create post
    const [post] = await Post.create([postData], { session });
    
    // Update user stats (hypothetical - not in current schema)
    await User.findByIdAndUpdate(
      userId,
      { $inc: { postsCount: 1 } },
      { session }
    );
    
    await session.commitTransaction();
    return post;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
};
```

**Best Practices**:
- Keep transactions short (minimize time between start and commit)
- Always abort on failure, end session in `finally` block
- Retry once on write conflicts (`TransientTransactionError`)

**Operations NOT Requiring Transactions**:
- ✅ Single document updates (already atomic)
- ✅ Embedded document updates (atomic within parent)
- ✅ Idempotent operations (safe to retry)

**Reference**: [MongoDB Transactions Documentation](https://www.mongodb.com/docs/manual/core/transactions/)

---

### Performance Optimization (Production)

**Workshop Note**: Premature optimization is avoided. Optimize **after** measuring actual performance bottlenecks.

#### Query Optimization

**N+1 Query Anti-Pattern**:

```typescript
// ❌ BAD: N+1 queries (1 for posts, N for authors)
const posts = await Post.find({ status: 'published' });
for (const post of posts) {
  post.author = await User.findById(post.authorId);  // N additional queries!
}

// ✅ GOOD: Use Mongoose populate (single $lookup query)
const posts = await Post.find({ status: 'published' })
  .populate('authorId', 'displayName email profilePicture');
// Single aggregation query with $lookup
```

**Index Utilization**:

```bash
# Verify query uses indexes
db.posts.find({ status: 'published' }).explain('executionStats')

# Check for COLLSCAN (full collection scan - bad)
{
  "executionStats": {
    "executionStages": {
      "stage": "COLLSCAN"  // ← Means no index used!
    }
  }
}

# Good query uses index
{
  "executionStats": {
    "executionStages": {
      "stage": "IXSCAN",  // ← Index scan
      "indexName": "status_1_publishedAt_-1"
    }
  }
}
```

**Pagination Best Practices**:

```typescript
// Simple pagination (works for small datasets)
const posts = await Post.find({ status: 'published' })
  .skip((page - 1) * pageSize)
  .limit(pageSize);

// Cursor-based pagination (better for large datasets)
const posts = await Post.find({
  status: 'published',
  _id: { $gt: lastSeenId }  // Continue from last ID
})
.limit(pageSize);
```

#### Caching Strategies (Production Enhancement)

**When to Cache**:
- Popular posts (high view count)
- User profiles (change infrequently)
- Static content (tags list, site metadata)

**In-Memory Cache** (simple, single VM only):

```typescript
// src/utils/cache.util.ts
const cache = new Map<string, { data: any; expiry: number }>();

export const cacheGet = (key: string): any | null => {
  const item = cache.get(key);
  if (!item || Date.now() > item.expiry) {
    cache.delete(key);
    return null;
  }
  return item.data;
};

export const cacheSet = (key: string, data: any, ttlSeconds: number): void => {
  cache.set(key, {
    data,
    expiry: Date.now() + (ttlSeconds * 1000)
  });
};

// Usage example
export const getPopularPosts = asyncHandler(async (req, res) => {
  const cacheKey = 'popular-posts';
  let posts = cacheGet(cacheKey);
  
  if (!posts) {
    posts = await Post.find({ status: 'published' })
      .sort({ viewCount: -1 })
      .limit(10);
    cacheSet(cacheKey, posts, 300);  // Cache 5 minutes
  }
  
  res.json({ data: posts });
});
```

**Redis Cache** (production, shared across VMs):

Requires additional infrastructure (Azure Cache for Redis). Out of scope for workshop.

**Reference**: [Azure Cache for Redis](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/)

---

### Circuit Breaker Pattern (Production)

**When Needed**:
- High request volumes (> 1000 RPS)
- Unstable external dependencies
- Prevent cascading failures in microservices

**Workshop Note**: Workshop has 2 stable dependencies (MongoDB, Entra ID JWKS). Circuit breaker adds complexity without benefit at workshop scale.

**Example Pattern** (for reference):

```typescript
import CircuitBreaker from 'opossum';

// Wrap external dependency
const breaker = new CircuitBreaker(fetchUserFromExternalAPI, {
  timeout: 3000,        // Timeout after 3 seconds
  errorThresholdPercentage: 50,  // Open circuit if 50% fail
  resetTimeout: 30000   // Try again after 30 seconds
});

breaker.fallback(() => ({ error: 'Service temporarily unavailable' }));

breaker.on('open', () => logger.warn('Circuit breaker opened'));
breaker.on('halfOpen', () => logger.info('Circuit breaker half-open'));
breaker.on('close', () => logger.info('Circuit breaker closed'));
```

**Reference**: [opossum circuit breaker library](https://github.com/nodeshift/opossum)

---

### Full Observability Stack (Production)

**Three Pillars of Observability**:

1. **Logs** (structured events) - ✅ Already implemented (Winston)
2. **Metrics** (aggregated measurements) - ⚠️ Basic (Application Insights)
3. **Traces** (request flow) - ❌ Not implemented (workshop is monolithic)

**Distributed Tracing with OpenTelemetry** (microservices only):

```typescript
import { trace } from '@opentelemetry/api';
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';

// Initialize OpenTelemetry
const provider = new NodeTracerProvider();
provider.register();

// Create span for operation
const span = trace.getTracer('blogapp-api').startSpan('createPost');
try {
  const post = await postService.create(postData);
  span.setStatus({ code: SpanStatusCode.OK });
  return post;
} catch (error) {
  span.setStatus({ code: SpanStatusCode.ERROR });
  throw error;
} finally {
  span.end();
}
```

**Workshop Note**: Distributed tracing has **limited value** in monolithic applications (single-tier architecture). More valuable when multiple services call each other (microservices).

**Reference**: [OpenTelemetry JavaScript](https://opentelemetry.io/docs/languages/js/)

---

### Microservices Evolution (Future Architecture)

**Current Workshop Architecture**: Monolithic API (all endpoints in one Express app)

**When to Consider Microservices**:
- Team size > 10 engineers (independent deployments)
- Different scaling needs (posts service vs user service)
- Technology diversity (e.g., Python for ML recommendations)

**Potential Service Boundaries**:

```
1. User Service
   - Authentication, profiles, authorization
   - POST /api/auth/*, GET /api/users/*

2. Content Service
   - Posts, comments, tags
   - POST /api/posts/*, GET /api/posts/*

3. Media Service
   - Image uploads, processing, CDN
   - POST /api/media/*, GET /api/media/*

4. Notification Service
   - Email, push notifications
   - POST /api/notifications/* (internal only)

5. Analytics Service
   - View tracking, recommendations
   - GET /api/analytics/*
```

**Azure Services for Microservices**:
- **Azure API Management**: Gateway, routing, rate limiting
- **Azure Service Bus**: Async messaging between services
- **Azure Container Apps**: Managed container orchestration
- **Azure Functions**: Event-driven serverless components

**Trade-offs**:
- ✅ **Pros**: Independent scaling, polyglot persistence, team autonomy
- ❌ **Cons**: Complexity, distributed transactions, monitoring overhead

**Workshop Recommendation**: Start with monolith, evolve when scale demands it.

**Reference**: [Microservices architecture on Azure](https://learn.microsoft.com/en-us/azure/architecture/microservices/)

---

## Appendix

### A. API Endpoint Summary

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | /api/auth/register | Required | Register/sync user from JWT |
| GET | /api/auth/me | Required | Get current user profile |
| GET | /api/users/:userId | Optional | Get public user profile |
| GET | /api/users/:userId/posts | Optional | Get user's posts |
| GET | /api/posts | Optional | List published posts (paginated) |
| GET | /api/posts/:slug | Optional | Get single post by slug |
| POST | /api/posts | Required | Create new post |
| PUT | /api/posts/:postId | Required | Update post (author only) |
| DELETE | /api/posts/:postId | Required | Delete post (author only) |
| POST | /api/posts/:postId/comments | Required | Add comment to post |
| DELETE | /api/posts/:postId/comments/:commentId | Required | Delete comment |
| GET | /api/health | None | Health check for load balancer |
| GET | /api/health/ready | None | Readiness check |

### B. Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| NODE_ENV | Yes | development | Environment (development, production) |
| PORT | No | 3000 | API server port |
| MONGODB_URI | Yes | - | MongoDB connection string (replica set) |
| ENTRA_TENANT_ID | Yes | - | Microsoft Entra ID tenant ID |
| ENTRA_CLIENT_ID | Yes | - | API application client ID |
| CORS_ORIGIN | Yes | - | Allowed CORS origins (comma-separated) |
| LOG_LEVEL | No | info | Logging level (error, warn, info, debug) |
| LOG_FORMAT | No | json | Log format (json, simple) |
| RATE_LIMIT_WINDOW_MS | No | 900000 | Rate limit window (15 min) |
| RATE_LIMIT_MAX_REQUESTS | No | 100 | Max requests per window |

### C. File Structure Summary

```
backend/
├── src/
│   ├── config/
│   │   ├── auth.ts                 # JWT validation config
│   │   ├── database.ts             # MongoDB connection
│   │   └── environment.ts          # Environment variables
│   ├── controllers/
│   │   ├── auth.controller.ts      # Auth endpoints
│   │   ├── posts.controller.ts     # Post CRUD endpoints
│   │   ├── comments.controller.ts  # Comment endpoints
│   │   └── users.controller.ts     # User endpoints
│   ├── middleware/
│   │   ├── auth.middleware.ts      # JWT validation
│   │   ├── authorization.middleware.ts  # Resource ownership
│   │   ├── error.middleware.ts     # Error handling
│   │   ├── logger.middleware.ts    # Request logging
│   │   ├── security.middleware.ts  # Helmet, CORS, rate limit
│   │   └── validation.middleware.ts # Input validation
│   ├── models/
│   │   ├── User.model.ts           # User Mongoose model
│   │   └── Post.model.ts           # Post Mongoose model
│   ├── routes/
│   │   ├── auth.routes.ts          # Auth routes
│   │   ├── posts.routes.ts         # Post routes
│   │   ├── comments.routes.ts      # Comment routes
│   │   ├── users.routes.ts         # User routes
│   │   ├── health.routes.ts        # Health check routes
│   │   └── index.ts                # Route aggregator
│   ├── services/
│   │   ├── auth.service.ts         # Auth business logic
│   │   ├── post.service.ts         # Post business logic
│   │   └── comment.service.ts      # Comment business logic
│   ├── types/
│   │   ├── auth.types.ts           # Auth TypeScript types
│   │   ├── api.types.ts            # API TypeScript types
│   │   └── express.d.ts            # Express augmentation
│   ├── utils/
│   │   ├── errors.util.ts          # Custom error classes
│   │   ├── logger.util.ts          # Winston logger
│   │   ├── content.util.ts         # Content processing utils
│   │   └── slug.util.ts            # Slug generation
│   ├── app.ts                      # Express app setup
│   └── server.ts                   # Server entry point
├── tests/
│   ├── unit/
│   │   └── services/
│   ├── integration/
│   │   └── posts.test.ts
│   └── setup.ts                    # Test setup
├── scripts/
│   ├── seed-database.ts            # Database seeding
│   ├── deploy.sh                   # Deployment script
│   └── rollback.sh                 # Rollback script
├── systemd/
│   └── blogapp-api.service         # Systemd service file
├── .env.example                    # Environment variables template
├── .gitignore
├── .eslintrc.js                    # ESLint configuration
├── .prettierrc                     # Prettier configuration
├── tsconfig.json                   # TypeScript configuration
├── jest.config.js                  # Jest configuration
├── package.json
└── README.md
```

### D. Useful Commands

```bash
# Development
npm run dev              # Start dev server with hot reload
npm run build            # Build TypeScript
npm start                # Start production server
npm run type-check       # Type check without build
npm run lint             # Run ESLint
npm run lint:fix         # Fix ESLint errors
npm run format           # Format with Prettier
npm test                 # Run tests
npm run test:watch       # Run tests in watch mode
npm run test:coverage    # Run tests with coverage
npm run seed             # Seed database

# Production
sudo systemctl start blogapp-api     # Start service
sudo systemctl stop blogapp-api      # Stop service
sudo systemctl restart blogapp-api   # Restart service
sudo systemctl status blogapp-api    # Check status
sudo systemctl enable blogapp-api    # Enable on boot
sudo systemctl disable blogapp-api   # Disable on boot
sudo journalctl -u blogapp-api -f    # View logs (follow)
sudo journalctl -u blogapp-api -n 100  # View last 100 log lines

# Health checks
curl http://localhost:3000/api/health  # Local health check
curl http://10.0.2.4:3000/api/health   # Remote health check

# MongoDB checks
mongosh "mongodb://10.0.3.4:27018,10.0.3.5:27018/?replicaSet=blogapp-rs0"
```

### E. Reference Documentation

**Node.js & Express**:
- [Node.js Documentation](https://nodejs.org/docs/latest-v20.x/api/)
- [Express.js Guide](https://expressjs.com/en/guide/routing.html)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)

**Database**:
- [Mongoose Documentation](https://mongoosejs.com/docs/guide.html)
- [MongoDB Node.js Driver](https://www.mongodb.com/docs/drivers/node/current/)
- [MongoDB Replica Sets](https://www.mongodb.com/docs/manual/replication/)

**Authentication**:
- [Microsoft Identity Platform](https://learn.microsoft.com/en-us/azure/active-directory/develop/)
- [JWT.io](https://jwt.io/) - JWT decoder and documentation
- [jwks-rsa Documentation](https://github.com/auth0/node-jwks-rsa)

**Azure**:
- [Azure VMs Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/)
- [Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/)
- [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/)

**Testing**:
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Supertest Documentation](https://github.com/visionmedia/supertest)

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-01 | Backend Engineer Agent | Complete backend application design specification |

---

**End of Backend Application Design Specification**