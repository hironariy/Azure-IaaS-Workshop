/**
 * Login Page Component
 * Handles Microsoft Entra ID authentication
 */

import { useNavigate } from 'react-router-dom';
import { useMsal, useIsAuthenticated } from '@azure/msal-react';
import { useEffect } from 'react';
import { loginRequest } from '../config/authConfig';

function LoginPage() {
  const { instance } = useMsal();
  const isAuthenticated = useIsAuthenticated();
  const navigate = useNavigate();

  // Redirect to home if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

  const handleLogin = () => {
    instance.loginRedirect(loginRequest);
  };

  return (
    <div className="mx-auto max-w-md text-center">
      <h1 className="mb-4 text-3xl font-bold text-gray-900">Sign In</h1>
      <p className="mb-8 text-gray-600">
        Sign in with your Microsoft account to create and manage blog posts.
      </p>

      <button onClick={handleLogin} className="btn-primary w-full">
        <svg className="mr-2 h-5 w-5" viewBox="0 0 21 21" fill="currentColor">
          <rect x="1" y="1" width="9" height="9" />
          <rect x="11" y="1" width="9" height="9" />
          <rect x="1" y="11" width="9" height="9" />
          <rect x="11" y="11" width="9" height="9" />
        </svg>
        Sign in with Microsoft
      </button>

      <div className="mt-8 rounded-lg bg-gray-50 p-6 text-left">
        <h3 className="mb-2 font-semibold text-gray-800">For Workshop Participants</h3>
        <p className="text-sm text-gray-600">
          This application uses Microsoft Entra ID (formerly Azure AD) for authentication.
          If you're familiar with AWS, think of it as the Azure equivalent of Amazon Cognito.
        </p>
        <p className="mt-2 text-sm text-gray-600">
          The authentication flow uses OAuth2.0 with MSAL (Microsoft Authentication Library),
          similar to how you might use Amplify Auth with Cognito.
        </p>
      </div>
    </div>
  );
}

export default LoginPage;
