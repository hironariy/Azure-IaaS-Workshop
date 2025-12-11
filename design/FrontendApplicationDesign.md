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
- **State Management**: 
  - **Server State**: @tanstack/react-query 5+ (React Query) - handles API data, caching, retries
  - **Client State**: React Context API - handles auth, UI preferences, theme
  - **Note**: Redux Toolkit NOT used (unnecessary complexity for this application)
- **HTTP Client**: Axios with interceptors
- **Build Tool**: Vite
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

#### My Posts Page (`/my-posts`)
- **Purpose**: Display list of current user's posts (including drafts)
- **Access**: Authenticated users only
- **Components**:
  - Status filter tabs (All / Drafts / Published)
  - Post list with title, status badge, updated date, view count
  - Edit button for each post
  - View button for each post
  - Delete button with confirmation dialog
  - Create New Post button
- **Data Source**: `GET /api/posts/my`
- **Actions**:
  - Filter posts by status
  - Navigate to edit page
  - Navigate to view page
  - Delete post (with confirmation)

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

**Enterprise Pattern (Separate App Registrations)**:

This application uses the recommended enterprise pattern with **two separate Entra ID app registrations**:

| Component | App Registration | Purpose |
|-----------|-----------------|---------|
| Frontend (SPA) | Client App | User authentication, redirect handling |
| Backend (API) | API App | Token validation, defines API permissions |

**Why Two Registrations?**
- **Security**: Backend validates tokens using its own Client ID as audience
- **Flexibility**: Can grant different apps access to the same API
- **Best Practice**: Follows Microsoft's recommended pattern for SPAs calling protected APIs

**Configuration**:
- Frontend Client ID: Used for MSAL initialization and login
- Backend API Scope: `api://{backendClientId}/access_as_user`
- Frontend must request the API scope when acquiring tokens for API calls

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

*For Login (loginRequest)*:
- `openid` (OpenID Connect)
- `profile` (basic profile)
- `User.Read` (read user profile from Microsoft Graph)
- `api://{backendClientId}/access_as_user` (backend API access - include in login to trigger consent)

*For API Calls (apiRequest)*:
- `api://{backendClientId}/access_as_user` (backend API access)

**Important**: Including the API scope in the login request triggers consent for API access during login, avoiding a separate consent popup when the user first makes an API call.

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
- **Silent Renewal**: MSAL handles automatically via `acquireTokenSilent()`

**Critical: Token Refresh Error Handling**:
- **Problem**: MSAL's `acquireTokenSilent()` can fail silently (network errors, session expired)
- **Impact**: User loses form data when API calls return 401
- **Solution**: Implement axios interceptors to:
  1. Catch 401 errors from failed token refresh
  2. Trigger auto-save before forcing re-login
  3. Show user-friendly error: "Your session expired. Please log in again."
  4. Optionally: Warn user 5 minutes before token expiry
- **Implementation**: See axios interceptor pattern in error handling section

**MSAL Redirect Loop Prevention**:
- **Common Issue**: Infinite redirect between app and login.microsoftonline.com
- **Root Cause**: Redirect URI mismatch between code and Entra ID configuration
- **Prevention**:
  1. Validate redirect URIs match exactly (including trailing slashes)
  2. Set `navigateToLoginRequestUrl: false` in MSAL config
  3. Add validation function to catch configuration errors at startup
- **Troubleshooting**: See Common Pitfalls section

**Protected Routes**:
- `/posts/new` - Create post
- `/posts/:id/edit` - Edit post
- `/profile` - User profile
- Redirect to login if not authenticated

### 4. API Integration

#### Base Configuration
- **Base URL**: `process.env.VITE_API_URL` (e.g., `http://loadbalancer-ip/api`)
- **Timeout**: 10 seconds (adjustable based on network conditions)
- **Headers**: 
  - `Content-Type: application/json`
  - `Authorization: Bearer {accessToken}` (for authenticated requests)

#### Network Resilience (CRITICAL)
- **Retry Logic**: React Query handles retries automatically with exponential backoff
- **Retry Configuration**:
  ```typescript
  // In queryClient configuration
  defaultOptions: {
    queries: {
      retry: 3,
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
    },
    mutations: {
      retry: 1, // Retry once for idempotent operations
    },
  }
  ```
- **Network Status Detection**: Monitor online/offline state, show user-friendly message
- **Error Handling**: Differentiate between network errors (retry) vs validation errors (show to user)
- **Axios Interceptors**:
  1. Request interceptor: Add auth token automatically
  2. Response interceptor: Handle 401 (token refresh failure), 403 (forbidden), 500 (server error)

#### API Service Layer Pattern (REQUIRED)
- **Architecture**: Create service layer to abstract API calls
- **Structure**:
  ```
  src/services/api/
  ├── client.ts         # Axios instance with interceptors
  ├── posts.service.ts  # Post-related API calls
  ├── comments.service.ts
  └── users.service.ts
  ```
- **Benefits**:
  1. Centralized API logic (easier to test, mock, update)
  2. Type-safe API calls with TypeScript generics
  3. Consistent error handling
  4. Components never call axios directly
- **Usage**: React Query hooks wrap service functions

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

#### Auto-Save Draft Pattern (CRITICAL)
- **Problem**: Users lose work on browser crashes, network errors, token expiration
- **Solution**: Auto-save form data to localStorage every 3 seconds
- **Implementation**:
  1. Create `useAutosave` custom hook
  2. Save draft to localStorage with debouncing (3 second interval)
  3. On page load, check for existing draft
  4. Show restore prompt: "You have unsaved changes. Restore?"
  5. Clear draft after successful submission
  6. Handle edge cases: empty forms, localStorage quota exceeded
- **Forms Requiring Auto-Save**:
  - Create Post form (HIGH priority - long-form content)
  - Edit Post form (HIGH priority)
  - Comment form (LOW priority - short content)
- **Educational Value**: Prevents student frustration, demonstrates production UX patterns

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
4. Test: `npm run test` (optional for workshop)
5. Build: `npm run build`
6. Output: `/dist` directory

#### Environment-Specific Builds

**Development**:
```bash
npm run dev  # Uses .env.development
```

**Production**:
```bash
npm run build  # Uses .env.production
```

**Vite Configuration**:
```typescript
// vite.config.ts
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  
  return {
    build: {
      sourcemap: mode === 'development',
      minify: mode === 'production' ? 'esbuild' : false,
      rollupOptions: {
        output: {
          manualChunks: {
            'react-vendor': ['react', 'react-dom', 'react-router-dom'],
            'msal-vendor': ['@azure/msal-browser', '@azure/msal-react'],
            'query-vendor': ['@tanstack/react-query'],
          },
        },
      },
    },
  };
});
```

**Environment Files**:
```bash
# .env.example (committed - template)
VITE_API_URL=http://localhost:3001
VITE_ENTRA_CLIENT_ID=your-client-id
VITE_ENTRA_TENANT_ID=your-tenant-id
VITE_ENTRA_REDIRECT_URI=http://localhost:3000

# .env.development (NOT committed)
VITE_API_URL=http://localhost:3001
VITE_ENTRA_CLIENT_ID=dev-client-id
# ... development values

# .env.production (NOT committed)
# Note: Frontend accesses API via NGINX reverse proxy, not direct App tier
# NGINX uses Internal LB (10.0.2.10) to reach App tier
VITE_API_URL=http://20.10.5.100  # External LB public IP (goes through NGINX)
VITE_ENTRA_CLIENT_ID=prod-client-id
VITE_ENTRA_REDIRECT_URI=http://20.10.5.100
# ... production values
```

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
    root /var/www/blogapp;  # Updated path
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

    # SPA routing (CRITICAL: must come last)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

#### Deployment Verification Checklist

**Pre-Deployment**:
- [ ] TypeScript compilation passes: `npm run type-check`
- [ ] ESLint passes: `npm run lint`
- [ ] Production build succeeds: `npm run build`
- [ ] Bundle size < 1MB: `du -sh dist/`
- [ ] Preview build locally: `npm run preview`
- [ ] `.env.production` file configured
- [ ] Entra ID redirect URI updated to VM IP

**Post-Deployment (Smoke Tests)**:
- [ ] Homepage loads: `http://<VM_IP>`
- [ ] Login redirects to Microsoft login
- [ ] After login, user sees name in navbar
- [ ] Posts display on homepage
- [ ] Post detail page loads
- [ ] Create post form loads (authenticated)
- [ ] 404 page shows for invalid routes
- [ ] SPA routing works (refresh on `/posts/123` doesn't 404)

**Automated Health Checks**:
```bash
#!/bin/bash
VM_IP="20.10.5.100"

echo "Running health checks..."
curl -f http://${VM_IP}/health || echo "❌ Health check failed"
curl -f http://${VM_IP}/ || echo "❌ Homepage failed"
curl -f http://${VM_IP}/assets/index*.js || echo "❌ Static assets failed"

# Check security headers
curl -sI http://${VM_IP}/ | grep -q "X-Frame-Options" || echo "❌ Missing security headers"

echo "✅ Health checks complete"
```

**Performance Checks**:
- [ ] Lighthouse score > 90 (run in Chrome DevTools)
- [ ] First Contentful Paint < 1.5s
- [ ] Largest Contentful Paint < 2.5s

**Security Checks**:
- [ ] No secrets in bundle: `grep -r "secret" dist/`
- [ ] Security headers present
- [ ] No console errors in browser

**Rollback Plan**:
If deployment fails:
```bash
ssh azureuser@<VM_IP>
sudo mv /var/www/blogapp /var/www/blogapp.failed
sudo mv /var/www/blogapp.backup.YYYYMMDD_HHMMSS /var/www/blogapp
sudo systemctl reload nginx
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

### 9. Workshop Feature Prioritization

**CRITICAL**: 2-day workshop timeline requires clear prioritization to ensure student success.

#### Day 1: Core Features (MUST COMPLETE - 80% target)

**Morning Session (9:00 AM - 12:00 PM)**:
1. **Authentication** (90 minutes)
   - Configure MSAL
   - Implement login/logout
   - Test authentication flow
   - **Checkpoint**: Students can log in successfully

2. **Display Posts** (90 minutes)
   - Set up React Query
   - Create `usePosts` hook
   - Build PostCard component
   - Display post list
   - **Checkpoint**: Students see posts on homepage

**Afternoon Session (1:00 PM - 5:00 PM)**:
3. **Post Detail Page** (60 minutes)
   - Create `usePost(id)` hook
   - Build PostDetailPage
   - Display comments
   - **Checkpoint**: Students can view individual posts

4. **Protected Routes** (60 minutes)
   - Create ProtectedRoute wrapper
   - Implement route protection
   - Test redirect to login
   - **Checkpoint**: Unauthenticated users redirected

5. **Deployment** (90 minutes)
   - Build production bundle
   - Deploy to Azure VM via NGINX
   - Update Entra ID redirect URI
   - **Checkpoint**: App accessible via VM IP

**Day 1 Success Criteria**: Working read-only blog app with authentication, deployed to Azure

---

#### Day 2: Full CRUD (SHOULD COMPLETE - 60% target)

**Morning Session (9:00 AM - 12:00 PM)**:
6. **Create Post** (90 minutes)
   - Build CreatePostPage with form
   - Implement `useCreatePost` mutation
   - Add form validation
   - **Implement auto-save draft** (CRITICAL)
   - **Checkpoint**: Students can create posts

7. **Edit/Delete Posts** (90 minutes)
   - Build EditPostPage
   - Implement `useUpdatePost`, `useDeletePost`
   - Add authorization checks (author only)
   - **Checkpoint**: Authors can edit/delete own posts

**Afternoon Session (1:00 PM - 5:00 PM)**:
8. **Add Comments** (60 minutes)
   - Build CommentForm component
   - Implement `useCreateComment` mutation
   - Display new comments
   - **Checkpoint**: Users can comment on posts

9. **User Profile** (60 minutes)
   - Build UserProfilePage
   - Display user's posts
   - **Checkpoint**: Users can view their profile

10. **Final Deployment** (60 minutes)
    - Deploy complete app
    - Run verification checklist
    - **Final Checkpoint**: All features working on Azure VM

**Day 2 Success Criteria**: Full CRUD blog app with comments, user profiles, deployed to Azure

---

#### Stretch Goals (IF TIME ALLOWS)

For advanced students who finish early:
- Search/filter posts by tag
- Pagination component
- Rich text editor (TinyMCE)
- Image upload to Azure Blob Storage
- Skeleton loaders
- ARIA accessibility enhancements

---

#### Instructor Checkpoints

**Critical Pause Points** (don't proceed until 75%+ students complete):
- After Milestone 1 (Authentication)
- After Milestone 2 (Display Posts)
- After Milestone 5 (Day 1 Deployment)

**Success Metrics**:
- Day 1 completion: 80% of students
- Day 2 completion: 60% of students
- Students who attempt stretch goals: 20%

---

### 10. Common Pitfalls & Troubleshooting

**This section helps students self-resolve issues, reducing instructor support burden.**

#### 🔴 CRITICAL: MSAL Redirect Loop

**Symptom**: Browser continuously redirects between app and `login.microsoftonline.com`

**Root Causes**:
1. Redirect URI mismatch (90% of cases)
   - Code: `http://localhost:3000`
   - Entra ID: `http://localhost:3000/` (extra slash)
   - **Fix**: Make them EXACTLY identical

2. `navigateToLoginRequestUrl` set to `true`
   - **Fix**: Set to `false` in MSAL config

**Debug Steps**:
1. Open DevTools → Network tab
2. Look for repeated requests to `login.microsoftonline.com`
3. Check `redirect_uri` parameter in URL
4. Compare with Entra ID app registration

**AWS Comparison**: Similar to Cognito callback URL mismatch

---

#### 🟠 HIGH: CORS Errors with Backend

**Symptom**: `Access to fetch at 'http://10.0.2.4:3000/api/posts' blocked by CORS policy`

**Root Cause**: Backend not configured to accept requests from frontend origin

**Fix**:
```typescript
// Backend (Express.js)
import cors from 'cors';
app.use(cors({
  origin: process.env.FRONTEND_URL, // http://localhost:3000
  credentials: true
}));
```

**Production**: Set `FRONTEND_URL` to VM IP or domain

**AWS Comparison**: Similar to API Gateway CORS configuration

---

#### 🟡 MEDIUM: Token Not Attached to API Requests

**Symptom**: Login succeeds, but API returns 401

**Root Cause**: Forgot to add token to axios requests

**Debug Steps**:
1. Check Network tab → Request headers
2. Verify `Authorization: Bearer eyJ...` exists
3. Copy token to jwt.io to decode
4. Verify `aud` (audience) matches backend

**Fix**: Ensure axios interceptor is configured correctly

---

#### 🟢 LOW: Port Already in Use

**Symptom**: `Error: listen EADDRINUSE: address already in use :::3000`

**Fix**:
```bash
# Option 1: Kill existing process
kill -9 $(lsof -ti:3000)

# Option 2: Use different port
PORT=3001 npm run dev
```

---

#### 🟣 Environment Variables Not Loading

**Symptom**: `import.meta.env.VITE_API_URL` is `undefined`

**Root Causes**:
1. Forgot `VITE_` prefix (Vite requirement)
   - ❌ Wrong: `API_URL=...`
   - ✅ Correct: `VITE_API_URL=...`

2. Didn't restart dev server
   - **Fix**: Restart `npm run dev`

3. `.env` file in wrong location
   - Must be in project root (same level as `package.json`)

**Debug**:
```typescript
console.log('API URL:', import.meta.env.VITE_API_URL);
console.log('All env vars:', import.meta.env);
```

---

### 11. Testing Requirements

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
| External LB | Azure Standard Load Balancer (public) | AWS ALB (internet-facing) |
| Internal LB | Azure Internal Load Balancer (App tier) | AWS ALB (internal) |
| Reverse Proxy | NGINX on Web VMs | NGINX or built into ALB |
| Static Hosting | NGINX on VM | S3 + CloudFront |
| Media Storage | Azure Blob Storage | S3 |
| Identity Claims | Microsoft Graph | Cognito User Pools |

**Traffic Flow**: Browser → External LB → NGINX (Web VM) → Internal LB (10.0.2.10) → Express (App VM) → MongoDB (DB VM)

#### Learning Objectives
1. Understand OAuth2.0 with Microsoft Entra ID
2. Configure MSAL in React application
3. Handle token acquisition and renewal
4. Secure API calls with bearer tokens
5. Deploy SPA to NGINX on Azure VM
6. Integrate with Azure Blob Storage
7. Compare Azure vs AWS authentication approaches

---

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-12-01 | Initial specification | Workshop Team |
| 2.0 | 2025-12-03 | Critical updates based on consultant review:<br>- React Query adopted for state management<br>- Token refresh error handling added<br>- MSAL redirect loop prevention added<br>- Workshop feature prioritization added<br>- Auto-save draft requirement added<br>- Network resilience patterns added<br>- Common pitfalls troubleshooting added<br>- Deployment verification checklist added | Frontend Engineer |
| 2.1 | 2025-12-10 | Authentication and feature updates:<br>- Added enterprise auth pattern documentation (separate app registrations)<br>- Added My Posts page (`/my-posts`) specification<br>- Added API scope consent flow documentation<br>- Added delete post functionality on Post and My Posts pages | Implementation Update |

**Document Status**: Living document - update as requirements evolve  
**Current Version**: 2.1  
**Last Updated**: 2025-12-10
