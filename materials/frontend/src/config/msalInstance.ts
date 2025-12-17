/**
 * Shared MSAL Instance
 * Singleton PublicClientApplication for Microsoft Entra ID authentication
 * Reference: /design/FrontendApplicationDesign.md
 *
 * For AWS-experienced engineers:
 * - This is like creating a singleton Amplify Auth instance
 * - MSAL requires explicit initialization before use
 * - All components and services should use this same instance
 *
 * IMPORTANT: This module now supports runtime configuration.
 * Call initializeMsal() after loadConfig() in main.tsx
 */

import { PublicClientApplication, EventType, type Configuration } from '@azure/msal-browser';
import { createMsalConfig, msalConfig as legacyMsalConfig } from './authConfig';
import { isConfigLoaded } from './appConfig';

/**
 * Singleton MSAL instance
 * Initially created with legacy config for backward compatibility
 * Will be replaced when initializeMsal() is called
 */
let msalInstance: PublicClientApplication = new PublicClientApplication(legacyMsalConfig);

/**
 * Flag to track if MSAL has been properly initialized with runtime config
 */
let msalInitialized = false;

/**
 * Promise that resolves when MSAL is fully initialized
 * This MUST be awaited before making any authenticated API calls
 */
let msalInitPromise: Promise<void>;

/**
 * Initialize MSAL with runtime configuration
 * This MUST be called after loadConfig() in main.tsx
 *
 * @returns Promise that resolves when MSAL is ready
 */
export async function initializeMsal(): Promise<void> {
  if (msalInitialized) {
    console.log('[MSAL] Already initialized');
    return msalInitPromise;
  }

  // Ensure app config is loaded first
  if (!isConfigLoaded()) {
    throw new Error(
      '[MSAL] App configuration not loaded. Call loadConfig() before initializeMsal().',
    );
  }

  console.log('[MSAL] Initializing with runtime configuration...');

  // Create new MSAL instance with runtime config
  const config: Configuration = createMsalConfig();
  msalInstance = new PublicClientApplication(config);

  // Initialize and handle redirect
  msalInitPromise = msalInstance.initialize().then(() => {
    return msalInstance
      .handleRedirectPromise()
      .then((response) => {
        if (response) {
          msalInstance.setActiveAccount(response.account);
        } else {
          const accounts = msalInstance.getAllAccounts();
          if (accounts.length > 0 && accounts[0] !== undefined) {
            msalInstance.setActiveAccount(accounts[0]);
          }
        }
        console.log('[MSAL] Initialization complete');
      })
      .catch((error) => {
        console.error('[MSAL] Redirect handling error:', error);
      });
  });

  // Set up event callbacks
  msalInstance.addEventCallback((event) => {
    if (event.eventType === EventType.LOGIN_SUCCESS && event.payload) {
      const payload = event.payload as { account: unknown };
      if (payload.account) {
        msalInstance.setActiveAccount(
          payload.account as Parameters<typeof msalInstance.setActiveAccount>[0],
        );
      }
    }
    if (event.eventType === EventType.LOGOUT_SUCCESS) {
      msalInstance.setActiveAccount(null);
    }
  });

  msalInitialized = true;
  return msalInitPromise;
}

/**
 * Get the MSAL instance
 * Throws if initializeMsal() hasn't been called
 */
export function getMsalInstance(): PublicClientApplication {
  if (!msalInitialized) {
    console.warn(
      '[MSAL] Instance accessed before initialization. Call initializeMsal() in main.tsx.',
    );
  }
  return msalInstance;
}

/**
 * Get the initialization promise
 * Use this to await MSAL readiness
 */
export function getMsalInitPromise(): Promise<void> {
  return msalInitPromise;
}

/**
 * Helper to check if MSAL is initialized
 * Useful for debugging
 */
export function isMsalInitialized(): boolean {
  return msalInitialized;
}

// =============================================================================
// Legacy exports for backward compatibility
// These will be removed after migration is complete
// =============================================================================

// Legacy initialization (for backward compatibility during migration)
// This will be overwritten when initializeMsal() is called
msalInitPromise = msalInstance.initialize().then(() => {
  return msalInstance
    .handleRedirectPromise()
    .then((response) => {
      if (response) {
        msalInstance.setActiveAccount(response.account);
      } else {
        const accounts = msalInstance.getAllAccounts();
        if (accounts.length > 0 && accounts[0] !== undefined) {
          msalInstance.setActiveAccount(accounts[0]);
        }
      }
    })
    .catch((error) => {
      console.error('[MSAL] Redirect handling error:', error);
    });
});

// Legacy event callback setup
msalInstance.addEventCallback((event) => {
  if (event.eventType === EventType.LOGIN_SUCCESS && event.payload) {
    const payload = event.payload as { account: unknown };
    if (payload.account) {
      msalInstance.setActiveAccount(
        payload.account as Parameters<typeof msalInstance.setActiveAccount>[0],
      );
    }
  }
  if (event.eventType === EventType.LOGOUT_SUCCESS) {
    msalInstance.setActiveAccount(null);
  }
});

// Re-export msalInstance for backward compatibility
export { msalInstance, msalInitPromise };
