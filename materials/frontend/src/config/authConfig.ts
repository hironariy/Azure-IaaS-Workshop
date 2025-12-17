/**
 * MSAL Configuration
 * Microsoft Entra ID authentication setup
 * Reference: /design/FrontendApplicationDesign.md
 *
 * This module uses runtime configuration loaded from appConfig.ts
 * - Development: Vite environment variables (.env.local)
 * - Production: /config.json (created by Bicep)
 */

import { Configuration, LogLevel } from '@azure/msal-browser';
import { getConfig } from './appConfig';

/**
 * Create MSAL configuration from runtime config
 *
 * For AWS-experienced engineers:
 * - MSAL is similar to AWS Amplify Auth with Cognito
 * - Handles OAuth2.0/OIDC flows automatically
 * - Manages token refresh and caching
 *
 * Note: This function must be called AFTER loadConfig() in main.tsx
 */
export function createMsalConfig(): Configuration {
  const config = getConfig();

  return {
    auth: {
      clientId: config.entraFrontendClientId,
      authority: `https://login.microsoftonline.com/${config.entraTenantId}`,
      redirectUri: config.redirectUri,
      postLogoutRedirectUri: window.location.origin,
      navigateToLoginRequestUrl: true,
    },
    cache: {
      // Use sessionStorage instead of localStorage for security
      // Reference: /design/RepositoryWideDesignRules.md - Section 1.3
      cacheLocation: 'sessionStorage',
      storeAuthStateInCookie: false,
    },
    system: {
      loggerOptions: {
        loggerCallback: (level, message, containsPii) => {
          if (containsPii) {
            return; // Never log PII
          }
          switch (level) {
            case LogLevel.Error:
              console.error(message);
              return;
            case LogLevel.Warning:
              console.warn(message);
              return;
            case LogLevel.Info:
              console.info(message);
              return;
            case LogLevel.Verbose:
              console.debug(message);
              return;
          }
        },
        logLevel: LogLevel.Warning,
        piiLoggingEnabled: false,
      },
    },
  };
}

/**
 * Create API request scopes from runtime config
 *
 * Enterprise pattern: Frontend and Backend have separate app registrations
 * - Frontend (entraFrontendClientId): SPA that acquires tokens
 * - Backend (entraBackendClientId): API that validates tokens
 *
 * The frontend requests tokens with the backend's API scope as the audience
 */
export function createApiRequest() {
  const config = getConfig();
  return {
    scopes: [`api://${config.entraBackendClientId}/access_as_user`],
  };
}

/**
 * Create login request scopes from runtime config
 * Includes API scope to get consent upfront
 * This prevents InteractionRequiredAuthError when calling APIs later
 */
export function createLoginRequest() {
  const config = getConfig();
  return {
    scopes: [
      'openid',
      'profile',
      'email',
      `api://${config.entraBackendClientId}/access_as_user`,
    ],
  };
}

// =============================================================================
// Legacy exports for backward compatibility during migration
// These will be removed after all components are updated
// =============================================================================

/**
 * @deprecated Use createMsalConfig() instead. This is kept for backward compatibility.
 */
export const msalConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_ENTRA_CLIENT_ID || 'your-client-id',
    authority: `https://login.microsoftonline.com/${import.meta.env.VITE_ENTRA_TENANT_ID || 'common'}`,
    redirectUri: import.meta.env.VITE_ENTRA_REDIRECT_URI || window.location.origin,
    postLogoutRedirectUri: window.location.origin,
    navigateToLoginRequestUrl: true,
  },
  cache: {
    cacheLocation: 'sessionStorage',
    storeAuthStateInCookie: false,
  },
  system: {
    loggerOptions: {
      loggerCallback: (level, message, containsPii) => {
        if (containsPii) return;
        switch (level) {
          case LogLevel.Error:
            console.error(message);
            return;
          case LogLevel.Warning:
            console.warn(message);
            return;
          case LogLevel.Info:
            console.info(message);
            return;
          case LogLevel.Verbose:
            console.debug(message);
            return;
        }
      },
      logLevel: LogLevel.Warning,
      piiLoggingEnabled: false,
    },
  },
};

/**
 * @deprecated Use createApiRequest() instead
 */
export const apiRequest = {
  scopes: [`api://${import.meta.env.VITE_API_CLIENT_ID}/access_as_user`],
};

/**
 * @deprecated Use createLoginRequest() instead
 */
export const loginRequest = {
  scopes: [
    'openid',
    'profile',
    'email',
    `api://${import.meta.env.VITE_API_CLIENT_ID}/access_as_user`,
  ],
};
