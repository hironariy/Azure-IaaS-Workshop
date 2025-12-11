# Frontend Development - Strategy and Steps

## Current Status

- ✅ Frontend scaffolding created (`materials/frontend/`)
- ✅ Dependencies installed (`npm install`)
- ✅ Environment file created (`.env` from `.env.example`)
- ✅ Backend running with seed data on `http://localhost:3000`
- ⏳ Entra ID app registration exists (credentials need to be configured)

---

## Strategy Overview

### Phase 1: Basic UI Without Authentication
Get the frontend running and displaying posts from the backend API.

### Phase 2: Entra ID Authentication
Configure MSAL and enable login/logout functionality.

### Phase 3: Protected Features
Enable authenticated features (create post, comments, profile).

### Phase 4: Polish and Testing
Error handling, loading states, responsive design, accessibility.

---

## Phase 1: Basic UI Without Authentication

### Step 1.1: Configure Environment Variables

Edit `materials/frontend/.env`:

```env
# Microsoft Entra ID Configuration
# Get these from Azure Portal > Entra ID > App registrations > Your app
VITE_ENTRA_CLIENT_ID=your-client-id-here
VITE_ENTRA_TENANT_ID=your-tenant-id-here
VITE_ENTRA_REDIRECT_URI=http://localhost:5173

# API URL (Vite dev server proxies to backend)
VITE_API_BASE_URL=
```

> **Note**: Leave `VITE_API_BASE_URL` empty - Vite's proxy handles `/api` requests.

### Step 1.2: Start the Development Server

```bash
cd materials/frontend
npm run dev
```

Expected output:
```
VITE v5.x.x  ready in xxx ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
➜  press h + enter to show help
```

### Step 1.3: Verify the Application

1. Open `http://localhost:5173` in your browser
2. You should see:
   - Header with "BlogApp" logo
   - Navigation (Home, Sign In button)
   - List of blog posts from seed data
   - Footer

### Step 1.4: Test Post Detail Page

1. Click on any post title
2. Should navigate to `/posts/{slug}`
3. Full post content should display

### Troubleshooting Phase 1

| Issue | Solution |
|-------|----------|
| Posts not loading | Check backend is running: `curl http://localhost:3000/api/posts` |
| CORS errors | Verify Vite proxy in `vite.config.ts` |
| Blank page | Check browser console for errors |
| TypeScript errors | Run `npm run type-check` |

---

## Phase 2: Entra ID Authentication

### Step 2.1: Configure Entra ID App Registration

In Azure Portal → Microsoft Entra ID → App registrations → Your app:

1. **Authentication** tab:
   - Add platform: **Single-page application**
   - Redirect URI: `http://localhost:5173`
   - ✅ Enable: "Access tokens" and "ID tokens"

2. **API permissions** tab:
   - Add permission: `Microsoft Graph > User.Read` (delegated)
   - Grant admin consent (if required)

3. **Expose an API** tab (for backend integration):
   - Set Application ID URI: `api://{client-id}`
   - Add scope: `access_as_user`

### Step 2.2: Update Frontend Environment

Edit `materials/frontend/.env` with your actual values:

```env
VITE_ENTRA_CLIENT_ID=77a3d3ab-d67f-46f8-8e29-8300cfc67f76
VITE_ENTRA_TENANT_ID=b3bbbafb-e820-42af-a675-c6d8fece5011
VITE_ENTRA_REDIRECT_URI=http://localhost:5173
```

### Step 2.3: Test Login Flow

1. Restart the dev server: `npm run dev`
2. Click "Sign In" button
3. Should redirect to Microsoft login page
4. After login, should redirect back to app
5. Header should show user name and "Sign Out" button

### Step 2.4: Verify Token Acquisition

Open browser DevTools → Application → Session Storage:
- Should see MSAL cache entries
- Tokens stored in `sessionStorage` (not `localStorage` - per security requirements)

### Troubleshooting Phase 2

| Issue | Solution |
|-------|----------|
| Redirect URI mismatch | Ensure Azure portal URI exactly matches `.env` |
| AADSTS error codes | Check [Microsoft error codes](https://learn.microsoft.com/en-us/entra/identity-platform/reference-error-codes) |
| Silent token failure | User may need to re-authenticate |
| Popup blocked | Try redirect flow instead |

---

## Phase 3: Protected Features

### Step 3.1: Test Create Post Page

1. Sign in
2. Navigate to `/create` (or click "Write Post" in nav)
3. Fill in post details
4. Submit

Expected: Post created and redirected to post detail page.

### Step 3.2: Test Profile Page

1. Sign in
2. Navigate to `/profile`
3. Should display user info from Entra ID token

### Step 3.3: Test Comments

1. Navigate to a post
2. Sign in
3. Add a comment
4. Comment should appear in the list

### Step 3.4: Verify Backend Authentication

Check backend logs - should see:
- JWT token validation
- User creation on first login
- Authorized requests succeeding

---

## Phase 4: Polish and Testing

### Step 4.1: Error Handling

Verify error states display correctly:
- Network errors
- 404 pages
- Authentication failures
- Form validation errors

### Step 4.2: Loading States

Verify loading indicators appear:
- Page transitions
- API calls
- Form submissions

### Step 4.3: Responsive Design

Test on different screen sizes:
- Desktop (1920px+)
- Tablet (768px)
- Mobile (375px)

### Step 4.4: Accessibility

Run accessibility checks:
```bash
# In browser DevTools
# Lighthouse > Accessibility audit
```

Key checks:
- Keyboard navigation
- Screen reader compatibility
- Color contrast
- Focus indicators

### Step 4.5: Build for Production

```bash
npm run build
npm run preview
```

Verify production build works correctly.

---

## API Endpoints Used by Frontend

| Page | Endpoint | Auth Required |
|------|----------|---------------|
| Home | `GET /api/posts` | No |
| Post Detail | `GET /api/posts/:slug` | No |
| Post Comments | `GET /api/posts/:slug/comments` | No |
| Create Post | `POST /api/posts` | Yes |
| Add Comment | `POST /api/posts/:slug/comments` | Yes |
| Profile | `GET /api/users/me` | Yes |
| Update Profile | `PUT /api/users/me` | Yes |

---

## File Structure Reference

```
materials/frontend/
├── src/
│   ├── config/
│   │   └── authConfig.ts     # MSAL configuration
│   ├── components/
│   │   └── Layout.tsx        # Header, nav, footer
│   ├── pages/
│   │   ├── HomePage.tsx      # Post listing
│   │   ├── PostPage.tsx      # Single post view
│   │   ├── CreatePostPage.tsx # Create new post
│   │   ├── ProfilePage.tsx   # User profile
│   │   └── LoginPage.tsx     # Login page
│   ├── services/
│   │   └── api.ts            # API client with MSAL token
│   ├── App.tsx               # Routing
│   ├── main.tsx              # Entry point with MSAL provider
│   └── index.css             # TailwindCSS styles
├── .env                      # Environment variables
├── vite.config.ts            # Vite + proxy config
└── package.json
```

---

## Next Steps After Frontend

1. **End-to-end testing** - Full user flows
2. **Production build** - Verify dist output
3. **NGINX configuration** - For Azure VM deployment
4. **CI/CD pipeline** - GitHub Actions workflow

---

## Related Documentation

- `/design/FrontendApplicationDesign.md` - Architecture specifications
- `/design/RepositoryWideDesignRules.md` - Security patterns
- `/materials/frontend/README.md` - Setup instructions
- [MSAL React Documentation](https://github.com/AzureAD/microsoft-authentication-library-for-js/tree/dev/lib/msal-react)
- [Vite Documentation](https://vitejs.dev/)
