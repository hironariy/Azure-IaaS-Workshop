# GitHub Copilot Instructions - Azure IaaS Workshop

This file contains repository-wide instructions for GitHub Copilot to ensure consistency across all code contributions.

## Project Context

This repository contains materials for a **2-day Azure IaaS Workshop** teaching resilient infrastructure patterns to AWS-experienced engineers (3-5 years experience, AZ-900 to AZ-104 certification level) transitioning to Azure.

**Application**: Multi-user blog system (3-tier: React frontend → Express backend → MongoDB)  
**Focus**: High availability with Availability Zones, disaster recovery with Azure Site Recovery, and operational excellence with Azure Monitor.

## Code Standards

### TypeScript Code Standard

**All TypeScript code in this repository MUST follow the [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html).**

Key requirements:

#### Naming Conventions
- **Files**: Use `camelCase.ts` or `kebab-case.ts` (be consistent within each tier)
- **Classes**: `PascalCase` (e.g., `BlogPostService`)
- **Interfaces/Types**: `PascalCase` (e.g., `BlogPost`, `CreatePostDTO`)
- **Functions/Variables**: `camelCase` (e.g., `createPost`, `userName`)
- **Constants**: `UPPER_SNAKE_CASE` for true constants (e.g., `MAX_POST_LENGTH`)
- **Private members**: Prefix with `#` or use `private` keyword
- **Enums**: `PascalCase` for enum name, `UPPER_SNAKE_CASE` for values

#### Type Annotations
- Always include explicit return types for functions
- Avoid `any` - use `unknown` with type guards if type is truly unknown
- Use `interface` for object shapes, `type` for unions/intersections
- Prefer `readonly` for immutable properties
- Use strict TypeScript configuration (`strict: true`)

#### Code Organization
- One class/interface per file (exceptions allowed for closely related types)
- Group imports: Node.js built-ins → external packages → internal modules
- Export interfaces and types alongside implementations
- Use barrel exports (`index.ts`) sparingly

#### Comments and Documentation
- Use JSDoc for public APIs and exported functions
- Explain **why**, not **what** (code should be self-documenting for "what")
- Include `@param`, `@returns`, `@throws` in JSDoc
- Add inline comments for complex logic or Azure-specific patterns
- Reference official documentation URLs for Azure integrations

#### Best Practices
- Use `const` by default, `let` when reassignment needed, never `var`
- Prefer arrow functions for callbacks
- Use template literals for string concatenation
- Destructure objects and arrays where it improves readability
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Avoid non-null assertion (`!`) unless absolutely necessary
- Enable and fix all ESLint warnings

### React/Frontend Specific

- **Components**: Use functional components with hooks (no class components)
- **Props**: Define explicit interface for all component props
- **State**: Use appropriate hooks (`useState`, `useReducer`, `useContext`)
- **Effects**: Include dependency arrays, cleanup functions where needed
- **Styling**: Use TailwindCSS utility classes, avoid inline styles
- **Accessibility**: Include ARIA labels, semantic HTML, keyboard navigation

### Node.js/Backend Specific

- **Async/Await**: Prefer over callbacks or raw promises
- **Error Handling**: Use try/catch, return proper HTTP status codes
- **Validation**: Validate all inputs with proper error messages
- **Security**: Sanitize inputs, use parameterized queries, validate JWTs
- **Logging**: Use structured logging (JSON format preferred)

### MongoDB/Database

- **Schema**: Use Mongoose schemas with TypeScript interfaces
- **Queries**: Use strongly-typed query builders
- **Indexes**: Document why indexes are created
- **Transactions**: Use for multi-document operations when needed

## Infrastructure as Code Standards

### Bicep

- **Modularity**: Separate resources into logical modules (network, compute, storage, etc.)
- **Parameters**: Use `@description()` decorators for all parameters
- **Validation**: Use `@allowed()`, `@minLength()`, `@maxLength()` where appropriate
- **Naming**: Follow Azure naming conventions (see `/design/AzureArchitectureDesign.md`)
- **Comments**: Explain design decisions and alternatives considered
- **Outputs**: Export values needed by other modules or scripts
- **Tags**: Apply consistent tags for cost tracking and organization

### NGINX Configuration

- **Security**: Include security headers (CSP, X-Frame-Options, etc.)
- **Compression**: Enable gzip for text-based resources
- **Caching**: Set appropriate cache headers for static assets
- **Health Checks**: Include health check endpoints for load balancers
- **Logging**: Configure access and error logs appropriately

## Documentation Standards

### README Files
- Include purpose, prerequisites, setup steps, and usage
- Provide troubleshooting section for common issues
- Link to relevant Azure documentation
- Include AWS comparison for equivalent services (target audience knows AWS)

### Code Comments
- Explain Azure-specific integrations (MSAL, Managed Identity, etc.)
- Document OAuth2.0 flow steps in authentication code
- Include troubleshooting hints for common errors
- Reference official Microsoft documentation
- Compare with AWS equivalents where educational

### Architecture Documentation
- Use diagrams for complex architectures
- Document decision rationale (ADRs - Architecture Decision Records)
- List alternatives considered and why not chosen
- Explain cost implications of choices
- Note security and compliance considerations

## Educational Requirements

This is a **teaching repository** - code should be instructive:

- **Clarity over Cleverness**: Prefer readable code over clever tricks
- **Comments as Teaching Tools**: Explain Azure patterns, OAuth2.0 flows, HA/DR concepts
- **Error Messages**: Make them helpful and actionable for students
- **Examples**: Include working examples, not just interfaces
- **Comparisons**: Note differences from AWS (e.g., "Unlike AWS Cognito, Entra ID...")
- **Troubleshooting**: Include common errors and solutions in comments/docs

## Testing Standards

### Unit Tests
- Write tests for business logic and utilities
- Use descriptive test names: `should [expected behavior] when [condition]`
- Arrange-Act-Assert pattern
- Mock external dependencies (APIs, databases)
- Aim for >80% code coverage

### Integration Tests
- Test authentication flows (MSAL integration)
- Test API endpoints with database
- Test error handling paths
- Use test databases, not production

### Frontend Tests
- Test component rendering
- Test user interactions (clicks, form submissions)
- Test accessibility (keyboard navigation, ARIA)
- Use React Testing Library patterns

## Security Guidelines

**CRITICAL**: All code must comply with `/design/RepositoryWideDesignRules.md` - read this document before implementing security-related features.

### Secret Management (MANDATORY)

**NEVER**:
- ❌ Hardcode credentials or API keys in source code
- ❌ Commit `.env` files or secrets to version control
- ❌ Log passwords, connection strings, or tokens
- ❌ Store secrets in localStorage (frontend)
- ❌ Pass secrets via URL parameters

**ALWAYS**:
- ✅ Use Azure Key Vault for production secrets
- ✅ Use Managed Identities for Azure resource authentication
- ✅ Use GitHub Secrets for CI/CD workflows
- ✅ Sanitize logs to redact sensitive information (see RepositoryWideDesignRules.md §1.4)
- ✅ Use sessionStorage for tokens (frontend, never localStorage)
- ✅ Add `.env*` and `*.key` files to `.gitignore`

**Implementation**:
- See `/design/RepositoryWideDesignRules.md` Section 1 for complete patterns
- Backend: Use `@azure/keyvault-secrets` with `DefaultAzureCredential`
- Frontend: Store auth tokens in sessionStorage, clear on logout
- Bicep: Use `@secure()` parameters and Azure RBAC for Key Vault access

### Authentication & Authorization
- Implement proper JWT validation (backend)
- Use Microsoft Entra ID OAuth2.0 with MSAL (frontend)
- Use Managed Identities for Azure resource access (no passwords)
- Clear tokens completely on logout

### Input Validation
- Validate and sanitize all user inputs
- Use parameterized queries (prevent SQL/NoSQL injection)
- Implement rate limiting on APIs
- Validate file uploads (type, size)

### Security Headers
- Content Security Policy (CSP)
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block

### Logging Security
**CRITICAL**: Never log sensitive information
- Sanitize connection strings: `mongodb://user:***@host` (not real password)
- Redact tokens: `Bearer ***` (not actual token)
- Sanitize user emails in logs: `u***@example.com`
- Use structured logging with correlation IDs (see RepositoryWideDesignRules.md §2)

## Git Commit Standards

- **Format**: `<type>(<scope>): <subject>`
- **Types**: feat, fix, docs, style, refactor, test, chore
- **Examples**: 
  - `feat(frontend): add MSAL authentication flow`
  - `fix(backend): correct MongoDB connection string`
  - `docs(infrastructure): update Bicep deployment guide`
- **Body**: Explain **why** the change was made, not what changed
- **References**: Link to issues or documentation

## Performance Guidelines

### Frontend
- Lighthouse score > 90 (all categories)
- Bundle size < 500KB gzipped
- Implement code splitting (route-based)
- Lazy load images and non-critical components
- Minimize re-renders (React.memo, useMemo, useCallback)

### Backend
- Response time < 500ms for API calls
- Implement database query optimization (proper indexes)
- Use caching where appropriate (Redis if needed)
- Implement connection pooling
- Monitor and log slow queries

## Azure-Specific Guidelines

### Resource Naming
Follow Azure naming conventions defined in `/design/AzureArchitectureDesign.md`:
- Use lowercase for resource names where required
- Include resource type prefix (e.g., `vm-`, `vnet-`, `nsg-`)
- Include environment suffix (e.g., `-prod`, `-dev`)
- Keep names under Azure length limits

### Tagging Strategy
Apply these tags to all Azure resources:
- `Environment`: prod | dev | test
- `Workload`: blogapp
- `Owner`: Workshop | Student name
- `CostCenter`: Training
- `Tier`: web | app | db | shared
- `ManagedBy`: Bicep | Portal | CLI

### High Availability Patterns
- Distribute VMs across Availability Zones (minimum 2 zones)
- Use Standard Load Balancer (not Basic)
- Implement health probes on all load-balanced services
- Design stateless application tiers where possible
- Use managed services with built-in HA (Azure SQL, Cosmos DB) when appropriate

### Monitoring & Observability
- Enable diagnostic settings on all resources
- Send logs to centralized Log Analytics workspace
- Implement structured logging (JSON format)
- Create meaningful alert rules (CPU, memory, errors)
- Use Azure Monitor Agent for VM metrics

## Workshop-Specific Considerations

### Time Constraints
- Infrastructure deployment via Bicep: 15-30 minutes
- Application deployment via GitHub Actions: Keep under 10 minutes
- Manual steps should be clearly documented and quick to execute

### Cost Optimization
- Use appropriate VM sizes (not over-provisioned)
- Implement auto-shutdown for non-production resources
- Document per-student cost estimates
- Provide clear resource cleanup procedures

### Student Experience
- Assume students know AWS well but are new to Azure
- Compare Azure services with AWS equivalents throughout
- Provide troubleshooting guides for common issues
- Make error messages helpful and actionable
- Support 20-30 concurrent student deployments

## File Organization

```
/
├── .github/
│   ├── agents/              # AI agent instructions
│   ├── workflows/           # GitHub Actions workflows
│   └── copilot-instructions.md
├── design/                  # Architecture and design specifications
├── bicep/                   # Infrastructure as Code (Bicep templates)
├── frontend/                # React application
├── backend/                 # Express API
├── docs/                    # Workshop materials and guides
└── scripts/                 # Deployment and utility scripts
```

## When to Ask for Clarification

Ask the user for clarification when:
- Architecture decisions that affect cost, security, or performance
- Changes to authentication/authorization flows
- Modifications to database schema
- Changes to API contracts between frontend/backend
- Deviations from specified technology stack
- Ambiguous requirements that could be interpreted multiple ways

## Reference Documentation

Always reference and follow:
- `/design/RepositoryWideDesignRules.md` - **CRITICAL**: Cross-cutting security, logging, error handling, and operational patterns
- `/design/AzureArchitectureDesign.md` - Infrastructure specifications
- `/design/FrontendApplicationDesign.md` - Frontend specifications
- `/design/DatabaseDesign.md` - Database specifications
- `/design/BackendApplicationDesign.md` - Backend specifications
- `WorkshopPlan.md` - Workshop goals and requirements
- Agent-specific instructions in `/.github/agents/`
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Azure naming conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)

**Priority Order**:
1. **RepositoryWideDesignRules.md** - Mandatory for all tiers (security, logging, error handling)
2. Tier-specific design documents (architecture, frontend, backend, database)
3. Workshop plan and educational requirements
4. External style guides and best practices

---

**Remember**: This is an educational workshop repository. Code quality, clarity, and teaching value are paramount. Every line of code should help AWS-experienced engineers understand Azure patterns and best practices.
