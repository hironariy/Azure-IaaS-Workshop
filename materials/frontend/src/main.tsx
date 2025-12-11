/**
 * Application Entry Point
 * Sets up React with MSAL provider
 * Reference: /design/FrontendApplicationDesign.md
 */

import React from 'react';
import ReactDOM from 'react-dom/client';
import { MsalProvider } from '@azure/msal-react';
import { BrowserRouter } from 'react-router-dom';
import { msalInstance, msalInitPromise } from './config/msalInstance';
import App from './App';
import './index.css';

/**
 * Wait for MSAL to initialize before rendering the app
 * This ensures the authentication state is ready before any components mount
 *
 * For AWS-experienced engineers:
 * - Similar to waiting for Amplify.configure() to complete
 * - Ensures auth state is available immediately
 */
msalInitPromise.then(() => {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <MsalProvider instance={msalInstance}>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </MsalProvider>
    </React.StrictMode>
  );
});
