/**
 * Application Entry Point
 * Sets up React with MSAL provider
 * Reference: /design/FrontendApplicationDesign.md
 */

import React from 'react';
import ReactDOM from 'react-dom/client';
import { PublicClientApplication } from '@azure/msal-browser';
import { MsalProvider } from '@azure/msal-react';
import { BrowserRouter } from 'react-router-dom';
import { msalConfig } from './config/authConfig';
import App from './App';
import './index.css';

/**
 * Initialize MSAL instance
 * This is the authentication client for Microsoft Entra ID
 *
 * For AWS-experienced engineers:
 * - Similar to Amplify.configure() for Cognito
 * - Creates a singleton auth client
 */
const msalInstance = new PublicClientApplication(msalConfig);

// Handle redirect promise (for login redirect flow)
msalInstance.initialize().then(() => {
  msalInstance.handleRedirectPromise().catch((error) => {
    console.error('Redirect error:', error);
  });
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <MsalProvider instance={msalInstance}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </MsalProvider>
  </React.StrictMode>
);
