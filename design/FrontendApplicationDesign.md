# Frontend Application Design Specification

## Overview

This document defines the frontend application requirements for the Azure IaaS Workshop blog application. This serves as the specification that the Frontend Engineer agent must follow when creating the React application.

## Application Overview

- **Type**: Multi-user blog application (SPA - Single Page Application)
- **Framework**: React 18+ with TypeScript
- **Styling**: TailwindCSS 3+
- **Authentication**: Microsoft Entra ID OAuth2.0 via MSAL
- **Deployment**: Static build served via NGINX on Azure VMs
- **Target Users**: Workshop students (experienced engineers learning Azure)

## Technology Stack

### Core Technologies
- **Frontend Framework**: React 18+
- **Language**: TypeScript 5+ (strict mode)
- **Styling**: TailwindCSS 3+
- **Routing**: React Router v6
- **State Management**: React Context API or Redux Toolkit
- **HTTP Client**: Axios
- **Build Tool**: Vite (recommended) or Create React App
- **Testing**: Vitest + React Testing Library
- **Code Standard**: Google TypeScript Style Guide

### Authentication & Security
- **Authentication Library**: @azure/msal-react, @azure/msal-browser
- **OAuth2.0 Flow**: Authorization Code Flow with PKCE
- **Token Storage**: Session Storage (not localStorage for security)
- **Identity Provider**: Microsoft Entra ID (formerly Azure AD)

### Development Tools
- **Linting**: ESLint with TypeScript plugin
- **Formatting**: Prettier
- **Git Hooks**: Husky + lint-staged
- **Type Checking**: TypeScript compiler

## Application Features

### 1. User Interface Pages

#### Home Page (`/`)
- **Purpose**: Display list of all blog posts
- **Components**:
  - Navigation header with login/logout
  - Blog post list (cards or table)
  - Pagination controls (if many posts)
  - Filter/search bar
- **Data Displayed per Post**:
  - Title
  - Author name
  - Publication date
  - Excerpt (first 150 characters)
  - Tags/categories
  - Read more link

#### Post Detail Page (`/posts/:id`)
- **Purpose**: Display full blog post with comments
- **Components**:
  - Full post content (rich text)
  - Author information
  - Publication/update dates
  - Comments section
  - Comment form (authenticated users only)
  - Edit/Delete buttons (if user is author)
- **Actions**:
  - Read post content
  - View comments
  - Add comment (requires authentication)
  - Edit/delete post (author only)

#### Create Post Page (`/posts/new`)
- **Purpose**: Create new blog post
- **Access**: Authenticated users only
- **Components**:
  - Rich text editor (TinyMCE, Draft.js, or similar)
  - Title input
  - Tags/category selector
  - Publish button
  - Save as draft button
  - Preview mode
- **Validation**:
  - Title: Required, 5-200 characters
  - Content: Required, minimum 50 characters
  - Tags: Optional, max 5 tags

#### Edit Post Page (`/posts/:id/edit`)
- **Purpose**: Edit existing post
- **Access**: Post author only
- **Components**: Same as Create Post Page
- **Additional Features**:
  - Last saved timestamp
  - Revision history (optional)
  - Cancel changes button

#### User Profile Page (`/profile`)
- **Purpose**: Display logged-in user information
- **Access**: Authenticated users only
- **Data Displayed**:
  - Name (from Entra ID)
  - Email (from Entra ID)
  - Profile photo (from Entra ID)
  - User's post statistics
  - List of user's posts
- **Actions**:
  - View my posts
  - Edit my posts
  - Logout

#### Error Pages
- **404 Not Found**: Page doesn't exist
- **500 Server Error**: Server error occurred
- **403 Forbidden**: Access denied
- **401 Unauthorized**: Authentication required (redirect to login)

### 2. Blog Functionality

#### Create (C)
- **Requirement**: Authenticated users can create new blog posts
- **Inputs**: Title, content (rich text), tags
- **Validation**: Client-side and server-side
- **Success**: Redirect to created post
- **Error Handling**: Display validation errors

#### Read (R)
- **Public Access**: Anyone can read published posts
- **List View**: Paginated list of all posts
- **Detail View**: Full post with comments
- **Search**: Filter by title, author, tags
- **Sort**: By date (newest/oldest), author

#### Update (U)
- **Authorization**: Post author only
- **What Can Be Updated**: Title, content, tags
- **What Cannot Be Updated**: Author, creation date
- **Validation**: Same as create
- **Success**: Show update confirmation

#### Delete (D)
- **Authorization**: Post author only
- **Confirmation**: Require confirmation dialog
- **Soft Delete**: Optional - mark as deleted vs permanent delete
- **Success**: Redirect to home page

#### Comments
- **Create Comment**: Authenticated users on any post
- **Read Comments**: Anyone can read
- **Delete Comment**: Comment author or post author
- **No Edit**: Comments cannot be edited (design choice)

### 3. Authentication Flow

#### Microsoft Entra ID OAuth2.0

**MSAL Configuration**:
```typescript
{
  auth: {
    clientId: string;           // From Entra ID app registration
    authority: string;          // Tenant-specific endpoint
    redirectUri: string;        // Callback URL after login
    postLogoutRedirectUri: string;
    navigateToLoginRequestUrl: true;
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
  system: {
    allowNativeBroker: false,
  }
}
```

**Scopes Required**:
- `User.Read` (read user profile)
- `openid` (OpenID Connect)
- `profile` (basic profile)
- `email` (email address)
- Custom API scope for backend (e.g., `api://{clientId}/access_as_user`)

**Authentication Flow**:
1. User clicks "Login with Microsoft"
2. Redirect to Entra ID login page
3. User authenticates with Microsoft credentials
4. Redirect back to app with authorization code
5. MSAL exchanges code for tokens
6. Store tokens in session storage
7. Fetch user profile from Microsoft Graph
8. Display user info in UI

**Token Management**:
- **Access Token**: Used for API calls (1 hour expiry)
- **Refresh Token**: Used to get new access tokens
- **ID Token**: Contains user claims
- **Silent Renewal**: Automatically renew tokens before expiry

**Protected Routes**:
- `/posts/new` - Create post
- `/posts/:id/edit` - Edit post
- `/profile` - User profile
- Redirect to login if not authenticated

### 4. API Integration

#### Base Configuration
- **Base URL**: `process.env.REACT_APP_API_BASE_URL` (e.g., `http://loadbalancer-ip/api`)
- **Timeout**: 30 seconds
- **Headers**: 
  - `Content-Type: application/json`
  - `Authorization: Bearer {accessToken}` (for authenticated requests)

#### API Endpoints

**Posts**:
- `GET /api/posts` - List all posts (with pagination)
- `GET /api/posts/:id` - Get single post
- `POST /api/posts` - Create new post (auth required)
- `PUT /api/posts/:id` - Update post (auth required, author only)
- `DELETE /api/posts/:id` - Delete post (auth required, author only)

**Comments**:
- `GET /api/posts/:postId/comments` - List comments for post
- `POST /api/posts/:postId/comments` - Add comment (auth required)
- `DELETE /api/comments/:id` - Delete comment (auth required)

**User**:
- `GET /api/users/:id` - Get user profile
- `GET /api/users/:id/posts` - Get user's posts

#### TypeScript Interfaces

```typescript
interface Post {
  id: string;
  title: string;
  content: string;
  excerpt: string;
  authorId: string;
  authorName: string;
  tags: string[];
  createdAt: string;  // ISO 8601
  updatedAt: string;  // ISO 8601
  commentCount: number;
}

interface CreatePostDTO {
  title: string;
  content: string;
  tags?: string[];
}

interface UpdatePostDTO {
  title?: string;
  content?: string;
  tags?: string[];
}

interface Comment {
  id: string;
  postId: string;
  authorId: string;
  authorName: string;
  content: string;
  createdAt: string;
}

interface CreateCommentDTO {
  content: string;
}

interface PaginatedResponse<T> {
  data: T[];
  page: number;
  pageSize: number;
  totalCount: number;
  totalPages: number;
}

interface ApiError {
  message: string;
  code: string;
  details?: Record<string, string[]>;
}
```

### 5. User Experience Requirements

#### Loading States
- Show skeleton loaders for content
- Spinner for async operations
- Progress bars for uploads
- Disable buttons during submission

#### Error Handling
- **Network Errors**: "Unable to connect. Please check your internet connection."
- **401 Unauthorized**: Redirect to login
- **403 Forbidden**: "You don't have permission to perform this action."
- **404 Not Found**: Custom 404 page
- **500 Server Error**: "Something went wrong. Please try again later."
- **Validation Errors**: Show field-level errors

#### Form Validation
- **Real-time Validation**: As user types
- **Submit Validation**: On form submission
- **Error Messages**: Below each field
- **Success Messages**: Toast notifications
- **Required Fields**: Mark with asterisk (*)

#### Toast Notifications
- **Success**: Green background, checkmark icon
- **Error**: Red background, X icon
- **Warning**: Yellow background, warning icon
- **Info**: Blue background, info icon
- **Auto-dismiss**: 3-5 seconds
- **Dismissible**: Close button

#### Accessibility (WCAG 2.1 AA)
- Semantic HTML elements
- ARIA labels for interactive elements
- Keyboard navigation support
- Focus indicators visible
- Color contrast ratio ≥ 4.5:1
- Screen reader friendly
- Alt text for images

#### Responsive Design Breakpoints
- **Mobile**: < 640px
- **Tablet**: 640px - 1024px
- **Desktop**: > 1024px
- **Mobile-first approach**

### 6. Performance Requirements

#### Performance Budgets
- **First Contentful Paint (FCP)**: < 1.5s
- **Time to Interactive (TTI)**: < 3.0s
- **Largest Contentful Paint (LCP)**: < 2.5s
- **Cumulative Layout Shift (CLS)**: < 0.1
- **First Input Delay (FID)**: < 100ms
- **Lighthouse Score**: > 90 (all categories)

#### Bundle Size Targets
- **Initial Bundle**: < 200 KB (gzipped)
- **Total Bundle**: < 500 KB (gzipped)
- **Vendor Chunks**: Separated and cached
- **Code Splitting**: Route-based splitting
- **Lazy Loading**: Images and non-critical components

#### Optimization Strategies
- Tree shaking (remove unused code)
- Minification and compression
- Image optimization (WebP format, lazy loading)
- CDN for static assets (Azure Blob Storage)
- HTTP/2 server push
- Browser caching headers
- Service worker (optional PWA)

### 7. Build and Deployment

#### Environment Variables

Required environment variables:
```bash
# Microsoft Entra ID Configuration
REACT_APP_CLIENT_ID=              # Entra ID application (client) ID
REACT_APP_TENANT_ID=              # Entra ID tenant ID
REACT_APP_AUTHORITY=              # https://login.microsoftonline.com/{tenantId}
REACT_APP_REDIRECT_URI=           # https://your-app.com or http://localhost:3000
REACT_APP_POST_LOGOUT_REDIRECT_URI=  # Where to redirect after logout

# API Configuration
REACT_APP_API_BASE_URL=           # Backend API URL (http://loadbalancer-ip/api)

# Optional
REACT_APP_BLOB_STORAGE_URL=       # Azure Blob Storage for media
REACT_APP_ENVIRONMENT=            # development | staging | production
```

#### Build Process
1. Install dependencies: `npm install`
2. Type check: `npm run type-check`
3. Lint: `npm run lint`
4. Test: `npm run test`
5. Build: `npm run build`
6. Output: `/dist` or `/build` directory

#### Build Output Structure
```
dist/
├── index.html
├── assets/
│   ├── index-[hash].js
│   ├── vendor-[hash].js
│   ├── styles-[hash].css
│   └── images/
├── favicon.ico
└── robots.txt
```

#### NGINX Configuration

File: `nginx.conf`

Requirements:
- Serve static files from `/usr/share/nginx/html`
- All routes → `index.html` (SPA routing)
- Gzip compression enabled
- Cache static assets (30 days)
- Security headers (CSP, X-Frame-Options, X-Content-Type-Options)
- Health check endpoint: `/health` returns 200 OK
- Listen on port 80 (HTTPS termination at Load Balancer)

Example:
```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Health check
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }

    # Static assets caching
    location /assets/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 8. Static Assets with Azure Blob Storage

#### Use Cases
- User-uploaded images (avatars, post images)
- Large media files (videos)
- Generated PDFs or documents

#### Configuration
- **Storage Account**: Created via Bicep by Infrastructure Architect
- **Container**: `blog-media` (private or blob-level public access)
- **CORS**: Allow from frontend domain
- **CDN**: Optional Azure CDN for better performance

#### Upload Flow
1. User selects file in frontend
2. Frontend uploads to Blob Storage (SAS token or managed identity)
3. Get blob URL
4. Send URL to backend API with post data
5. Backend stores URL in MongoDB

#### Access
- Public blobs: Direct URL access
- Private blobs: Generate SAS token via backend API

### 9. Testing Requirements

#### Unit Tests
- Component rendering tests
- Utility function tests
- Custom hooks tests
- API client tests (mocked)
- Coverage target: > 80%

#### Integration Tests
- Authentication flow (MSAL mocked)
- Form submission with API
- Route protection
- Error boundary testing

#### E2E Tests (Optional)
- Complete user flows
- Tools: Playwright or Cypress
- Critical paths:
  - Login → Create Post → View Post
  - Login → Edit Post → Save
  - Login → Delete Post

### 10. Educational Context

#### AWS Comparison Points

Students are familiar with AWS, so document differences:

| Feature | Azure (This App) | AWS Equivalent |
|---------|------------------|----------------|
| Authentication | Microsoft Entra ID + MSAL | Amazon Cognito |
| OAuth2.0 Flow | Authorization Code with PKCE | Same, but different SDK |
| Token Storage | Session Storage | Same |
| API Gateway | Azure Load Balancer + NGINX | AWS ALB + API Gateway |
| Static Hosting | NGINX on VM | S3 + CloudFront |
| Media Storage | Azure Blob Storage | S3 |
| Identity Claims | Microsoft Graph | Cognito User Pools |

#### Learning Objectives
1. Understand OAuth2.0 with Microsoft Entra ID
2. Configure MSAL in React application
3. Handle token acquisition and renewal
4. Secure API calls with bearer tokens
5. Deploy SPA to NGINX on Azure VM
6. Integrate with Azure Blob Storage
7. Compare Azure vs AWS authentication approaches

---

**Document Status**: Living document - update as requirements evolve
**Last Updated**: 2025-12-01
**Version**: 1.0
