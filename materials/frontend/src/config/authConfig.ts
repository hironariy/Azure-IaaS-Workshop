/**
 * MSAL Configuration
 * Microsoft Entra ID authentication setup
 * Reference: /design/FrontendApplicationDesign.md
 */

import { Configuration, LogLevel } from '@azure/msal-browser';

/**
 * MSAL configuration for Microsoft Entra ID authentication
 *
 * For AWS-experienced engineers:
 * - MSAL is similar to AWS Amplify Auth with Cognito
 * - Handles OAuth2.0/OIDC flows automatically
 * - Manages token refresh and caching
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

/**
 * Scopes for API access
 * Add your backend API scope here after configuring app registration
 */
export const loginRequest = {
  scopes: ['openid', 'profile', 'email'],
};

/**
 * API scopes for calling the backend
 * Replace with your actual API scope after app registration
 */
export const apiRequest = {
  scopes: [`api://${import.meta.env.VITE_ENTRA_CLIENT_ID}/access_as_user`],
};
