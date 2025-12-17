/**
 * Application Configuration
 * Runtime configuration that supports both local development and Azure production
 *
 * Reference: /design/FrontendApplicationDesign.md - Workshop Configuration: Runtime Config Pattern
 *
 * For AWS-experienced engineers:
 * - Similar to fetching config from S3 or Parameter Store at runtime
 * - Allows infrastructure (Bicep) to inject configuration without rebuilding the app
 *
 * Pattern:
 * - Development: Uses Vite environment variables (import.meta.env.VITE_*)
 * - Production: Fetches /config.json created by Bicep CustomScript on Web VMs
 */

/**
 * Application configuration interface
 */
export interface AppConfig {
  entraTenantId: string;
  entraFrontendClientId: string;
  entraBackendClientId: string;
  apiBaseUrl: string;
  redirectUri: string;
}

/**
 * Cached configuration - loaded once at app startup
 */
let cachedConfig: AppConfig | null = null;

/**
 * Load configuration from appropriate source based on environment
 *
 * Must be called before MSAL initialization (in main.tsx before React renders)
 */
export async function loadConfig(): Promise<AppConfig> {
  if (cachedConfig) {
    return cachedConfig;
  }

  // Development: use Vite environment variables
  if (import.meta.env.DEV) {
    console.log('[Config] Loading from Vite environment variables (development)');
    cachedConfig = {
      entraTenantId: import.meta.env.VITE_ENTRA_TENANT_ID || '',
      entraFrontendClientId: import.meta.env.VITE_ENTRA_CLIENT_ID || '',
      entraBackendClientId: import.meta.env.VITE_API_CLIENT_ID || '',
      apiBaseUrl: import.meta.env.VITE_API_BASE_URL || '/api',
      redirectUri: import.meta.env.VITE_ENTRA_REDIRECT_URI || window.location.origin,
    };

    // Validate required values
    if (!cachedConfig.entraTenantId || !cachedConfig.entraFrontendClientId) {
      console.warn(
        '[Config] Missing required Entra ID configuration in .env file.\n' +
          'Copy .env.example to .env.local and fill in your values.',
      );
    }

    return cachedConfig;
  }

  // Production: fetch /config.json (created by Bicep CustomScript on Web VMs)
  console.log('[Config] Loading from /config.json (production)');
  try {
    const response = await fetch('/config.json');
    if (!response.ok) {
      throw new Error(`Failed to load /config.json: ${response.status} ${response.statusText}`);
    }

    const json = await response.json();

    cachedConfig = {
      entraTenantId: json.ENTRA_TENANT_ID || '',
      entraFrontendClientId: json.ENTRA_FRONTEND_CLIENT_ID || '',
      entraBackendClientId: json.ENTRA_BACKEND_CLIENT_ID || '',
      apiBaseUrl: json.API_BASE_URL || '/api',
      redirectUri: window.location.origin,
    };

    console.log('[Config] Configuration loaded successfully');
    return cachedConfig;
  } catch (error) {
    console.error('[Config] Failed to load configuration:', error);
    throw new Error(
      'Failed to load application configuration. ' +
        'Ensure /config.json exists on the server (created by Bicep deployment).',
    );
  }
}

/**
 * Get the current configuration
 * Throws if loadConfig() hasn't been called yet
 */
export function getConfig(): AppConfig {
  if (!cachedConfig) {
    throw new Error(
      'Configuration not loaded. Call loadConfig() in main.tsx before using getConfig().',
    );
  }
  return cachedConfig;
}

/**
 * Check if configuration is loaded
 */
export function isConfigLoaded(): boolean {
  return cachedConfig !== null;
}
