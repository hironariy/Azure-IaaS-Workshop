# Frontend Application - Azure IaaS Workshop

React-based multi-user blog application with Microsoft Entra ID authentication.

## Prerequisites

- Node.js 20.x LTS
- Microsoft Entra ID app registration

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Copy the example environment file:

```bash
cp .env.example .env.local
```

Edit `.env.local` with your configuration:

- `VITE_ENTRA_CLIENT_ID`: Your Microsoft Entra ID app registration client ID
- `VITE_ENTRA_TENANT_ID`: Your Microsoft Entra ID tenant ID
- `VITE_ENTRA_REDIRECT_URI`: Redirect URI (default: http://localhost:5173)

### 3. Start Development Server

```bash
npm run dev
```

The application will be available at `http://localhost:5173`.

## Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start Vite development server |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |
| `npm run lint:fix` | Fix ESLint errors |
| `npm run format` | Format code with Prettier |
| `npm test` | Run Vitest tests |

## Project Structure

```
src/
├── config/           # Configuration files
│   └── authConfig.ts # MSAL configuration
├── components/       # Reusable React components
│   └── Layout.tsx    # Main layout with header/footer
├── pages/            # Page components
│   ├── HomePage.tsx  # Post listing
│   ├── PostPage.tsx  # Single post view
│   ├── CreatePostPage.tsx # Create new post
│   ├── ProfilePage.tsx    # User profile
│   └── LoginPage.tsx      # Login page
├── services/         # API and external services
│   └── api.ts        # Backend API client
├── App.tsx           # Main app with routing
├── main.tsx          # Entry point
├── index.css         # TailwindCSS styles
└── vite-env.d.ts     # TypeScript environment types
```

## Authentication

This application uses Microsoft Entra ID for authentication via MSAL (Microsoft Authentication Library).

### Setting Up Entra ID App Registration

1. Go to Azure Portal → Microsoft Entra ID → App registrations
2. Create a new registration
3. Add redirect URI: `http://localhost:5173` (SPA)
4. Enable ID tokens
5. Copy the Client ID and Tenant ID to your `.env.local`

### Token Storage

Tokens are stored in `sessionStorage` (not `localStorage`) for security.
See: `/design/RepositoryWideDesignRules.md` - Section 1.3

## Styling

This project uses TailwindCSS 3+ with custom Azure-inspired colors.

Custom CSS classes defined in `index.css`:
- `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-danger` - Button styles
- `.card` - Card container
- `.input` - Form input styling
- `.link` - Link styling

## API Integration

The frontend communicates with the Express backend via the API client in `services/api.ts`.

During development, Vite proxies `/api` requests to `http://localhost:3000`.

## Deployment

For Azure VM deployment, see `/design/FrontendApplicationDesign.md`.

The application is deployed to Azure VMs with NGINX serving the static build:
- Build directory: `dist/`
- Served by NGINX on Web tier VMs
- Behind Azure External Load Balancer

## AWS Equivalent

For AWS-experienced engineers:

| This Project (Azure) | AWS Equivalent |
|---------------------|----------------|
| Microsoft Entra ID | Amazon Cognito |
| MSAL | Amplify Auth |
| Azure External LB | AWS Application Load Balancer |
| Azure CDN | Amazon CloudFront |
| Azure Blob Storage (optional) | Amazon S3 |
