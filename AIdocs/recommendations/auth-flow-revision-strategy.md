# Authentication Flow Revision Strategy

## Problem Statement

The current frontend implementation attempts to acquire an access token for **every** API request, including public endpoints. This causes:

1. **500 errors** when unauthenticated users access public endpoints (token acquisition fails)
2. **Unnecessary token requests** for public data that doesn't require authentication
3. **Poor user experience** - public content becomes inaccessible

## Current Behavior (Problematic)

```
User visits http://localhost:5173/ (homepage)
  └── Frontend calls GET /api/posts
       └── Axios interceptor calls getAccessToken()
            └── MSAL tries to acquire token silently
                 └── No active account → Token acquisition fails
                      └── Error bubbles up → 500 shown to user
```

## Desired Behavior

```
User visits http://localhost:5173/ (homepage)
  └── Frontend calls GET /api/posts (no auth header)
       └── Backend optionalAuthenticate sees no token → continues
            └── Returns public posts successfully

User logs in, then visits homepage
  └── Frontend calls GET /api/posts (with auth header)
       └── Backend optionalAuthenticate validates token
            └── Returns posts (potentially with author-specific info)
```

## Reference: Backend Authentication Requirements

See `design/BackendApplicationDesign.md` section "API Authentication Requirements" for the complete endpoint matrix.

### Quick Summary

| Auth Level | Endpoints |
|------------|-----------|
| **None** | `/health`, `/health/ready`, `GET /api/users/:username` |
| **Optional** | `GET /api/posts`, `GET /api/posts/:slug`, `GET /api/posts/:slug/comments` |
| **Required** | All `POST`, `PUT`, `DELETE` operations + `GET /api/users/me` |

## Revision Strategy

### Phase 1: Frontend API Service Refactoring

**File**: `materials/frontend/src/services/api.ts`

**Changes Required**:

1. **Modify `getAccessToken()` to accept an auth mode parameter**:
   - `required`: Throws error if no token available
   - `optional`: Returns null if no token, doesn't throw
   - `none`: Doesn't attempt token acquisition

2. **Categorize API functions by auth requirement**:
   - Public functions: Don't attempt token
   - Optional auth functions: Try token but don't fail if unavailable
   - Required auth functions: Must have token or throw

### Phase 2: Endpoint Categorization

Based on `design/BackendApplicationDesign.md`, categorize all API functions:

#### Public (No Auth Attempt)
These should work without any token:
- `getPublicUserProfile(username)` - Get user public profile

#### Optional Auth (Include Token If Available)
These work without auth but may return more data with auth:
- `getPosts()` - List published posts
- `getPost(slug)` - Get single post (draft requires auth + ownership)
- `getComments(slug)` - Get comments for a post

#### Required Auth (Must Have Token)
These MUST have a valid token:
- `getCurrentUser()` - GET /api/users/me
- `updateCurrentUser()` - PUT /api/users/me
- `createPost()` - POST /api/posts
- `updatePost()` - PUT /api/posts/:slug
- `deletePost()` - DELETE /api/posts/:slug
- `createComment()` - POST /api/posts/:slug/comments
- `updateComment()` - PUT /api/posts/:slug/comments/:id
- `deleteComment()` - DELETE /api/posts/:slug/comments/:id

### Phase 3: Implementation Approach

**Recommended: Simple Flag Approach**

Modify `getAccessToken()` to accept an optional `required` parameter:

```typescript
type AuthMode = 'required' | 'optional' | 'none';

async function getAccessToken(mode: AuthMode = 'optional'): Promise<string | null> {
  // Skip token acquisition for public endpoints
  if (mode === 'none') {
    return null;
  }

  try {
    await msalInitPromise;
    const activeAccount = msalInstance.getActiveAccount();
    
    if (!activeAccount) {
      if (mode === 'required') {
        throw new Error('Authentication required');
      }
      return null; // No token, continue without auth
    }
    
    const response = await msalInstance.acquireTokenSilent({...});
    return response.accessToken;
  } catch (error) {
    if (mode === 'required') {
      throw error; // Propagate error for required auth
    }
    console.debug('[API] Token acquisition skipped - user not authenticated');
    return null; // Graceful degradation for optional auth
  }
}
```

Then update the axios interceptor:

```typescript
// Request interceptor - only add token if available
client.interceptors.request.use(
  async (config) => {
    // Check if this request requires auth (can use custom config property)
    const authMode = config.authMode || 'optional';
    const token = await getAccessToken(authMode);
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);
```

### Phase 4: Testing Checklist

After implementation, verify:

**Unauthenticated user scenarios**:
- [ ] Homepage loads and shows posts
- [ ] Individual post page loads
- [ ] Comments load on post page
- [ ] Public user profile page loads
- [ ] Login button visible, works

**Authenticated user scenarios**:
- [ ] Homepage loads with user menu
- [ ] Create post works
- [ ] Edit own post works
- [ ] Delete own post works
- [ ] Add comment works
- [ ] Edit/delete own comment works
- [ ] Profile page shows private info
- [ ] Update profile works

**Edge cases**:
- [ ] Token expires mid-session → graceful handling
- [ ] Draft post access by author works
- [ ] Draft post access by non-author → 403
- [ ] Backend down → appropriate error messages

### Phase 5: Rollback Plan

If issues arise:

1. Revert `api.ts` to previous version
2. All requests will attempt token (original behavior)
3. Unauthenticated users will see errors on public pages (known issue)

## Files to Modify

| File | Changes |
|------|---------|
| `frontend/src/services/api.ts` | Refactor token acquisition, add auth modes |
| `frontend/src/config/authConfig.ts` | No changes needed |
| `frontend/src/config/msalInstance.ts` | No changes needed |
| `backend/src/middleware/auth.middleware.ts` | Already correct - no changes |
| `backend/src/routes/*.routes.ts` | Already correct - verify only |

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking authenticated flows | High | Test all auth flows after change |
| Token not sent when needed | High | Categorize endpoints carefully |
| Race conditions in token acquisition | Medium | Use msalInitPromise properly |
| Console errors for failed token | Low | Use console.debug, not console.error |

## Approval Checklist

Before implementing, confirm:

- [ ] Design document section "API Authentication Requirements" is reviewed
- [ ] Revision strategy is approved
- [ ] Test checklist is understood
- [ ] Rollback plan is acceptable

---

**Status**: Awaiting approval before implementation
