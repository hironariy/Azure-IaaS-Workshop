/**
 * Application Entry Point
 * Sets up React with MSAL provider using runtime configuration
 * Reference: /design/FrontendApplicationDesign.md
 *
 * Configuration Loading Order:
 * 1. Load app config (from .env in dev, /config.json in production)
 * 2. Initialize MSAL with loaded config
 * 3. Render React app with MsalProvider
 *
 * For AWS-experienced engineers:
 * - Similar to loading config from Parameter Store then calling Amplify.configure()
 * - Ensures configuration is available before any auth operations
 */

import React from 'react';
import ReactDOM from 'react-dom/client';
import { MsalProvider } from '@azure/msal-react';
import { BrowserRouter } from 'react-router-dom';
import { loadConfig } from './config/appConfig';
import { initializeMsal, getMsalInstance } from './config/msalInstance';
import App from './App';
import './index.css';

/**
 * Bootstrap the application
 *
 * Order is critical:
 * 1. Load configuration (dev: .env, prod: /config.json)
 * 2. Initialize MSAL with that configuration
 * 3. Render React app
 */
async function bootstrap(): Promise<void> {
  try {
    // Step 1: Load application configuration
    console.log('[Bootstrap] Loading configuration...');
    await loadConfig();

    // Step 2: Initialize MSAL with runtime config
    console.log('[Bootstrap] Initializing MSAL...');
    await initializeMsal();

    // Step 3: Render the application
    console.log('[Bootstrap] Rendering application...');
    const msalInstance = getMsalInstance();

    ReactDOM.createRoot(document.getElementById('root')!).render(
      <React.StrictMode>
        <MsalProvider instance={msalInstance}>
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </MsalProvider>
      </React.StrictMode>,
    );
  } catch (error) {
    console.error('[Bootstrap] Failed to initialize application:', error);

    // Show error message to user
    const root = document.getElementById('root');
    if (root) {
      root.innerHTML = `
        <div style="padding: 20px; font-family: system-ui, sans-serif;">
          <h1 style="color: #dc2626;">Application Initialization Failed</h1>
          <p>Failed to load application configuration.</p>
          <pre style="background: #f3f4f6; padding: 12px; border-radius: 4px; overflow: auto;">${
            error instanceof Error ? error.message : String(error)
          }</pre>
          <p style="margin-top: 16px;">
            <strong>For developers:</strong> Check the browser console for details.
          </p>
        </div>
      `;
    }
  }
}

// Start the application
bootstrap();
