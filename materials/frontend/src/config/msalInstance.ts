/**
 * Shared MSAL Instance
 * Singleton PublicClientApplication for Microsoft Entra ID authentication
 * Reference: /design/FrontendApplicationDesign.md
 *
 * For AWS-experienced engineers:
 * - This is like creating a singleton Amplify Auth instance
 * - MSAL requires explicit initialization before use
 * - All components and services should use this same instance
 */

import { PublicClientApplication, EventType } from '@azure/msal-browser';
import { msalConfig } from './authConfig';

/**
 * Singleton MSAL instance
 * Created once, shared across the application
 */
export const msalInstance = new PublicClientApplication(msalConfig);

/**
 * Promise that resolves when MSAL is fully initialized
 * This MUST be awaited before making any authenticated API calls
 */
export const msalInitPromise: Promise<void> = msalInstance.initialize().then(() => {
  // Handle redirect response after initialization
  // This is needed for login redirect flow
  return msalInstance.handleRedirectPromise().then((response) => {
    if (response) {
      // If we got a response, set the active account
      msalInstance.setActiveAccount(response.account);
    } else {
      // Check if there's already an active account
      const accounts = msalInstance.getAllAccounts();
      if (accounts.length > 0 && accounts[0] !== undefined) {
        // Set the first account as active if none is set
        msalInstance.setActiveAccount(accounts[0]);
      }
    }
  }).catch((error) => {
    console.error('[MSAL] Redirect handling error:', error);
    // Don't rethrow - allow app to continue even if redirect handling fails
  });
});

// Set up event callbacks for account changes
msalInstance.addEventCallback((event) => {
  if (event.eventType === EventType.LOGIN_SUCCESS && event.payload) {
    const payload = event.payload as { account: unknown };
    if (payload.account) {
      msalInstance.setActiveAccount(payload.account as Parameters<typeof msalInstance.setActiveAccount>[0]);
    }
  }
  if (event.eventType === EventType.LOGOUT_SUCCESS) {
    msalInstance.setActiveAccount(null);
  }
});

/**
 * Helper to check if MSAL is initialized
 * Useful for debugging
 */
export function isMsalInitialized(): boolean {
  try {
    // If we can get accounts without error, MSAL is initialized
    msalInstance.getAllAccounts();
    return true;
  } catch {
    return false;
  }
}
